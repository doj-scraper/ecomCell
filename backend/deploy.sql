-- ==============================================================================
-- CELLTECH DISTRIBUTOR — POSTGRESQL MASTER DEPLOYMENT SCRIPT
-- Target: Neon PostgreSQL
-- Schema: Brand → ModelType → Generation → Variant (4-tier hierarchy)
-- ==============================================================================
-- USAGE:
--   Run this against your Neon database via the Neon SQL editor,
--   psql, or your preferred PG client.
--
--   For local dev with Prisma:
--     npx prisma migrate dev --name "init"
--     npx ts-node prisma/seed.ts
--
--   This raw script is for emergency resets, staging provisioning,
--   or environments where Prisma migrations are not available.
-- ==============================================================================


-- ==============================================================================
-- 1. CLEANUP
--    Drop in strict reverse-dependency order. CASCADE handles FK references.
-- ==============================================================================

DROP TABLE IF EXISTS order_items        CASCADE;
DROP TABLE IF EXISTS orders             CASCADE;
DROP TABLE IF EXISTS cart_items         CASCADE;
DROP TABLE IF EXISTS carts              CASCADE;
DROP TABLE IF EXISTS compatibility_map  CASCADE;
DROP TABLE IF EXISTS specifications     CASCADE;
DROP TABLE IF EXISTS inventory          CASCADE;
DROP TABLE IF EXISTS categories         CASCADE;
DROP TABLE IF EXISTS variants           CASCADE;
DROP TABLE IF EXISTS generations        CASCADE;
DROP TABLE IF EXISTS model_types        CASCADE;
DROP TABLE IF EXISTS brands             CASCADE;
DROP TABLE IF EXISTS verification_tokens CASCADE;
DROP TABLE IF EXISTS sessions           CASCADE;
DROP TABLE IF EXISTS accounts           CASCADE;
DROP TABLE IF EXISTS users              CASCADE;

-- Drop custom enum types after tables that use them
DROP TYPE IF EXISTS quality_grade;
DROP TYPE IF EXISTS user_role;
DROP TYPE IF EXISTS order_status;


-- ==============================================================================
-- 2. ENUM TYPES
--    PostgreSQL requires enums to be created as named types before use.
-- ==============================================================================

CREATE TYPE quality_grade AS ENUM (
    'OEM',
    'Premium',
    'Aftermarket',
    'U',   -- Unknown: legacy/unverified stock
    'NA'   -- Not Applicable: tools, adhesives, consumables
);

CREATE TYPE user_role AS ENUM (
    'CUSTOMER',
    'ADMIN'
);

CREATE TYPE order_status AS ENUM (
    'PENDING',
    'CONFIRMED',
    'SHIPPED',
    'DELIVERED',
    'CANCELLED'
);


-- ==============================================================================
-- 3. AUTH TABLES (NextAuth Prisma Adapter)
-- ==============================================================================

CREATE TABLE users (
    id              TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    email           TEXT        NOT NULL UNIQUE,
    password        TEXT,                           -- bcrypt hash; NULL for OAuth users
    email_verified  TIMESTAMPTZ,
    name            TEXT,
    image           TEXT,
    -- B2B fields
    company         TEXT,
    tax_id          TEXT,
    net_terms       BOOLEAN     NOT NULL DEFAULT FALSE,
    role            user_role   NOT NULL DEFAULT 'CUSTOMER',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE accounts (
    id                  TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    user_id             TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type                TEXT NOT NULL,
    provider            TEXT NOT NULL,
    provider_account_id TEXT NOT NULL,
    refresh_token       TEXT,
    access_token        TEXT,
    expires_at          INT,
    token_type          TEXT,
    scope               TEXT,
    id_token            TEXT,
    session_state       TEXT,
    UNIQUE (provider, provider_account_id)
);

CREATE TABLE sessions (
    id            TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    session_token TEXT        NOT NULL UNIQUE,
    user_id       TEXT        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires       TIMESTAMPTZ NOT NULL
);

-- Used by NextAuth for email verification and password reset tokens
CREATE TABLE verification_tokens (
    identifier TEXT        NOT NULL,
    token      TEXT        NOT NULL UNIQUE,
    expires    TIMESTAMPTZ NOT NULL,
    UNIQUE (identifier, token)
);


-- ==============================================================================
-- 4. DEVICE HIERARCHY
--    Brand → ModelType → Generation → Variant (4-tier)
--
--    Example path:
--      Apple → iPhone → 17 → Pro Max  (modelNumber: A3257)
--      Samsung → Galaxy S → 25 → Ultra (modelNumber: SM-S928U)
-- ==============================================================================

CREATE TABLE brands (
    id         SERIAL      PRIMARY KEY,
    name       TEXT        NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- e.g. "iPhone", "Galaxy S", "Galaxy Z Fold", "Galaxy Z Flip"
CREATE TABLE model_types (
    id         SERIAL      PRIMARY KEY,
    brand_id   INT         NOT NULL REFERENCES brands(id),
    name       TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (brand_id, name)
);

-- e.g. "17", "16", "S25", "Z Fold 6"
CREATE TABLE generations (
    id            SERIAL      PRIMARY KEY,
    model_type_id INT         NOT NULL REFERENCES model_types(id),
    name          TEXT        NOT NULL,
    release_year  INT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (model_type_id, name)
);

-- The leaf node. Assumes 5G as baseline. e.g. "Pro Max", "Ultra", "Base", "FE"
-- model_number is the physical identifier stamped on the device (A-series, SM-series)
CREATE TABLE variants (
    id            SERIAL      PRIMARY KEY,
    generation_id INT         NOT NULL REFERENCES generations(id),
    name          TEXT        NOT NULL,
    model_number  TEXT        NOT NULL UNIQUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (generation_id, name)
);


-- ==============================================================================
-- 5. CATALOG & INVENTORY
--
--    Smart SKU format: [Bucket]-[PartType]-[Grade]-[Device]
--    Buckets:
--      1 = Visual Interface  (A=Display, B=OLED, C=LCD)
--      2 = Chassis/Enclosure (A=Housing/Frame, B=Back Glass, C=SIM Tray)
--      3 = Functional Modules(A=Charging Port, B=Camera, C=Battery, D=NFC)
--      4 = Interconnects     (A=Flex Cables, B=Antennas)
--
--    Example: 3-C-O-IP13 = Functional Module / Battery / OEM / iPhone 13
-- ==============================================================================

-- The 4 top-level buckets
CREATE TABLE categories (
    id         SERIAL      PRIMARY KEY,
    name       TEXT        NOT NULL UNIQUE,
    prefix     TEXT        NOT NULL UNIQUE,  -- "1", "2", "3", "4"
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE inventory (
    sku_id          TEXT          PRIMARY KEY,
    category_id     INT           NOT NULL REFERENCES categories(id),
    part_name       TEXT          NOT NULL,
    quality_grade   quality_grade NOT NULL,
    wholesale_price INT           NOT NULL DEFAULT 0,  -- cents; 0 = "Contact for Price"
    stock_level     INT           NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- One row per spec per part. Replaces the old pipe-delimited string column.
-- Filterable: SELECT * FROM specifications WHERE label = 'Capacity'
CREATE TABLE specifications (
    id         SERIAL      PRIMARY KEY,
    sku_id     TEXT        NOT NULL REFERENCES inventory(sku_id) ON DELETE CASCADE,
    label      TEXT        NOT NULL,
    value      TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (sku_id, label)  -- one value per label per part
);

-- Many-to-many glue: one part → many variants, one variant → many parts
-- Composite PK eliminates the redundant auto-increment id
CREATE TABLE compatibility_map (
    sku_id     TEXT NOT NULL REFERENCES inventory(sku_id) ON DELETE CASCADE,
    variant_id INT  NOT NULL REFERENCES variants(id)     ON DELETE CASCADE,
    PRIMARY KEY (sku_id, variant_id)
);


-- ==============================================================================
-- 6. CART (Server-side persistence for multi-session B2B quotes)
-- ==============================================================================

CREATE TABLE carts (
    id         TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    user_id    TEXT        NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE cart_items (
    id         TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    cart_id    TEXT        NOT NULL REFERENCES carts(id)     ON DELETE CASCADE,
    sku_id     TEXT        NOT NULL REFERENCES inventory(sku_id),
    quantity   INT         NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (cart_id, sku_id)  -- adding existing SKU updates qty, no duplicate rows
);


-- ==============================================================================
-- 7. ORDERS (B2B ledger — prices snapshotted at purchase time)
-- ==============================================================================

CREATE TABLE orders (
    id                       TEXT         PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    user_id                  TEXT         NOT NULL REFERENCES users(id),
    status                   order_status NOT NULL DEFAULT 'PENDING',
    shipping_address         JSONB        NOT NULL,  -- snapshot, never join back to users
    stripe_payment_intent_id TEXT         UNIQUE,
    notes                    TEXT,
    created_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE TABLE order_items (
    id                    TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    order_id              TEXT        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    sku_id                TEXT        NOT NULL REFERENCES inventory(sku_id),
    quantity              INT         NOT NULL,
    unit_price_at_purchase INT        NOT NULL,  -- cents — never join back to inventory for history
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ==============================================================================
-- 8. INDEXES
--    Targets the most common query patterns in server.ts
-- ==============================================================================

-- Hierarchy traversal (GET /api/hierarchy/:brandId)
CREATE INDEX idx_model_types_brand_id    ON model_types(brand_id);
CREATE INDEX idx_generations_model_type  ON generations(model_type_id);
CREATE INDEX idx_variants_generation     ON variants(generation_id);

-- Inventory lookups
CREATE INDEX idx_inventory_category      ON inventory(category_id);
CREATE INDEX idx_inventory_quality       ON inventory(quality_grade);
CREATE INDEX idx_compatibility_variant   ON compatibility_map(variant_id);
CREATE INDEX idx_compatibility_sku       ON compatibility_map(sku_id);
CREATE INDEX idx_specifications_sku      ON specifications(sku_id);

-- Order and cart queries
CREATE INDEX idx_orders_user_id          ON orders(user_id);
CREATE INDEX idx_cart_items_cart_id      ON cart_items(cart_id);
CREATE INDEX idx_order_items_order_id    ON order_items(order_id);

-- Auth
CREATE INDEX idx_accounts_user_id        ON accounts(user_id);
CREATE INDEX idx_sessions_user_id        ON sessions(user_id);


-- ==============================================================================
-- 9. SEED — CATEGORIES (The 4 Buckets)
-- ==============================================================================

INSERT INTO categories (name, prefix) VALUES
    ('Visual Interface',    '1'),
    ('Chassis & Enclosure', '2'),
    ('Functional Modules',  '3'),
    ('Interconnects',       '4');


-- ==============================================================================
-- 10. SEED — BRANDS
-- ==============================================================================

INSERT INTO brands (name) VALUES
    ('Apple'),
    ('Samsung');


-- ==============================================================================
-- 11. SEED — MODEL TYPES
-- ==============================================================================

INSERT INTO model_types (brand_id, name) VALUES
    ((SELECT id FROM brands WHERE name = 'Apple'),   'iPhone'),
    ((SELECT id FROM brands WHERE name = 'Samsung'), 'Galaxy S'),
    ((SELECT id FROM brands WHERE name = 'Samsung'), 'Galaxy Z Fold'),
    ((SELECT id FROM brands WHERE name = 'Samsung'), 'Galaxy Z Flip'),
    ((SELECT id FROM brands WHERE name = 'Samsung'), 'Galaxy A');


-- ==============================================================================
-- 12. SEED — GENERATIONS
-- ==============================================================================

-- iPhone generations (modern era baseline: iPhone 12+)
INSERT INTO generations (model_type_id, name, release_year) VALUES
    ((SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple')), '12',   2020),
    ((SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple')), '13',   2021),
    ((SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple')), '14',   2022),
    ((SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple')), '15',   2023),
    ((SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple')), '16',   2024),
    ((SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple')), '17',   2025),
    ((SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple')), 'SE',   2022);

-- Galaxy S generations
INSERT INTO generations (model_type_id, name, release_year) VALUES
    ((SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'S22', 2022),
    ((SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'S23', 2023),
    ((SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'S24', 2024),
    ((SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'S25', 2025),
    ((SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'S26', 2026);

-- Galaxy Z Fold generations
INSERT INTO generations (model_type_id, name, release_year) VALUES
    ((SELECT id FROM model_types WHERE name = 'Galaxy Z Fold' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'Fold 3', 2021),
    ((SELECT id FROM model_types WHERE name = 'Galaxy Z Fold' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'Fold 4', 2022),
    ((SELECT id FROM model_types WHERE name = 'Galaxy Z Fold' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'Fold 5', 2023),
    ((SELECT id FROM model_types WHERE name = 'Galaxy Z Fold' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'Fold 6', 2024),
    ((SELECT id FROM model_types WHERE name = 'Galaxy Z Fold' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'Fold 7', 2025);

-- Galaxy Z Flip generations
INSERT INTO generations (model_type_id, name, release_year) VALUES
    ((SELECT id FROM model_types WHERE name = 'Galaxy Z Flip' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'Flip 3', 2021),
    ((SELECT id FROM model_types WHERE name = 'Galaxy Z Flip' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'Flip 4', 2022),
    ((SELECT id FROM model_types WHERE name = 'Galaxy Z Flip' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'Flip 5', 2023),
    ((SELECT id FROM model_types WHERE name = 'Galaxy Z Flip' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'Flip 6', 2024),
    ((SELECT id FROM model_types WHERE name = 'Galaxy Z Flip' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'Flip 7', 2025);

-- Galaxy A generations
INSERT INTO generations (model_type_id, name, release_year) VALUES
    ((SELECT id FROM model_types WHERE name = 'Galaxy A' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'A53', 2022),
    ((SELECT id FROM model_types WHERE name = 'Galaxy A' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'A54', 2023),
    ((SELECT id FROM model_types WHERE name = 'Galaxy A' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung')), 'A55', 2024);


-- ==============================================================================
-- 13. SEED — VARIANTS
--     model_number = physical identifier stamped on device
--     name         = variant within the generation (assume 5G baseline)
-- ==============================================================================

-- ── iPhone 12 family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = '12' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'mini',    'A2399'),
    ((SELECT id FROM generations WHERE name = '12' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Base',    'A2403'),
    ((SELECT id FROM generations WHERE name = '12' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro',     'A2341'),
    ((SELECT id FROM generations WHERE name = '12' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro Max', 'A2342');

-- ── iPhone 13 family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = '13' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'mini',    'A2481'),
    ((SELECT id FROM generations WHERE name = '13' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Base',    'A2482'),
    ((SELECT id FROM generations WHERE name = '13' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro',     'A2483'),
    ((SELECT id FROM generations WHERE name = '13' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro Max', 'A2484');

-- ── iPhone 14 family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = '14' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Base',    'A2649'),
    ((SELECT id FROM generations WHERE name = '14' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Plus',    'A2632'),
    ((SELECT id FROM generations WHERE name = '14' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro',     'A2650'),
    ((SELECT id FROM generations WHERE name = '14' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro Max', 'A2651');

-- ── iPhone 15 family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = '15' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Base',    'A2846'),
    ((SELECT id FROM generations WHERE name = '15' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Plus',    'A2847'),
    ((SELECT id FROM generations WHERE name = '15' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro',     'A2848'),
    ((SELECT id FROM generations WHERE name = '15' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro Max', 'A2849');

-- ── iPhone 16 family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = '16' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Base',    'A3081'),
    ((SELECT id FROM generations WHERE name = '16' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Plus',    'A3082'),
    ((SELECT id FROM generations WHERE name = '16' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro',     'A3083'),
    ((SELECT id FROM generations WHERE name = '16' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro Max', 'A3084'),
    ((SELECT id FROM generations WHERE name = '16' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'e',       'A3212');

-- ── iPhone 17 family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = '17' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Air',     'A3260'),
    ((SELECT id FROM generations WHERE name = '17' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Base',    'A3258'),
    ((SELECT id FROM generations WHERE name = '17' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro',     'A3256'),
    ((SELECT id FROM generations WHERE name = '17' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'Pro Max', 'A3257'),
    ((SELECT id FROM generations WHERE name = '17' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), 'e',       'A3575');

-- ── iPhone SE ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = 'SE' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), '2020', 'A2275'),
    ((SELECT id FROM generations WHERE name = 'SE' AND model_type_id = (SELECT id FROM model_types WHERE name = 'iPhone' AND brand_id = (SELECT id FROM brands WHERE name = 'Apple'))), '2022', 'A2595');

-- ── Galaxy S22 family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = 'S22' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base',  'SM-S901'),
    ((SELECT id FROM generations WHERE name = 'S22' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Plus',  'SM-S906'),
    ((SELECT id FROM generations WHERE name = 'S22' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Ultra', 'SM-S908');

-- ── Galaxy S23 family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = 'S23' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base',  'SM-S911'),
    ((SELECT id FROM generations WHERE name = 'S23' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Plus',  'SM-S916'),
    ((SELECT id FROM generations WHERE name = 'S23' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Ultra', 'SM-S918');

-- ── Galaxy S24 family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = 'S24' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base',  'SM-S921-24'),
    ((SELECT id FROM generations WHERE name = 'S24' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Plus',  'SM-S926-24'),
    ((SELECT id FROM generations WHERE name = 'S24' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Ultra', 'SM-S928-24');

-- ── Galaxy S25 family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = 'S25' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base',  'SM-S921'),
    ((SELECT id FROM generations WHERE name = 'S25' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Plus',  'SM-S926'),
    ((SELECT id FROM generations WHERE name = 'S25' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Ultra', 'SM-S928');

-- ── Galaxy S26 family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = 'S26' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base',  'SM-S931'),
    ((SELECT id FROM generations WHERE name = 'S26' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Plus',  'SM-S936'),
    ((SELECT id FROM generations WHERE name = 'S26' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy S' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Ultra', 'SM-S938');

-- ── Galaxy Z Fold family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = 'Fold 3' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy Z Fold' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'SM-F926'),
    ((SELECT id FROM generations WHERE name = 'Fold 4' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy Z Fold' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'SM-F936'),
    ((SELECT id FROM generations WHERE name = 'Fold 5' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy Z Fold' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'SM-F946'),
    ((SELECT id FROM generations WHERE name = 'Fold 6' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy Z Fold' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'SM-F956'),
    ((SELECT id FROM generations WHERE name = 'Fold 7' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy Z Fold' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'SM-F958');

-- ── Galaxy Z Flip family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = 'Flip 3' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy Z Flip' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'SM-F711'),
    ((SELECT id FROM generations WHERE name = 'Flip 4' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy Z Flip' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'SM-F721'),
    ((SELECT id FROM generations WHERE name = 'Flip 5' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy Z Flip' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'SM-F731'),
    ((SELECT id FROM generations WHERE name = 'Flip 6' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy Z Flip' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'SM-F741'),
    ((SELECT id FROM generations WHERE name = 'Flip 7' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy Z Flip' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'SM-F751');

-- ── Galaxy A family ──
INSERT INTO variants (generation_id, name, model_number) VALUES
    ((SELECT id FROM generations WHERE name = 'A53' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy A' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'A536'),
    ((SELECT id FROM generations WHERE name = 'A54' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy A' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'A546'),
    ((SELECT id FROM generations WHERE name = 'A55' AND model_type_id = (SELECT id FROM model_types WHERE name = 'Galaxy A' AND brand_id = (SELECT id FROM brands WHERE name = 'Samsung'))), 'Base', 'A556');


-- ==============================================================================
-- 14. SEED — INVENTORY PARTS (Smart SKUs)
-- ==============================================================================

-- ── Apple Batteries ──
INSERT INTO inventory (sku_id, category_id, part_name, quality_grade, wholesale_price, stock_level) VALUES
    ('3-C-P-IF16PrM', (SELECT id FROM categories WHERE prefix = '3'), 'iPhone 16 Pro Max Replacement Battery', 'Premium',     2200, 50),
    ('3-C-P-IF15PrM', (SELECT id FROM categories WHERE prefix = '3'), 'iPhone 15 Pro Max Replacement Battery', 'Premium',     2000, 75),
    ('3-C-P-IF14',    (SELECT id FROM categories WHERE prefix = '3'), 'iPhone 14 Replacement Battery',         'Premium',     1500, 120),
    ('3-C-O-IP13',    (SELECT id FROM categories WHERE prefix = '3'), 'iPhone 13 Replacement Battery',         'OEM',         1450, 100);

-- ── Apple Charge Ports ──
INSERT INTO inventory (sku_id, category_id, part_name, quality_grade, wholesale_price, stock_level) VALUES
    ('3-A-O-IF16PrM-CHG', (SELECT id FROM categories WHERE prefix = '3'), 'iPhone 16 Pro Max Charge Port Assembly', 'OEM', 1700, 40),
    ('3-A-O-IF14-CHG',    (SELECT id FROM categories WHERE prefix = '3'), 'iPhone 14 Charge Port Assembly',         'OEM', 1100, 85);

-- ── Samsung Batteries ──
INSERT INTO inventory (sku_id, category_id, part_name, quality_grade, wholesale_price, stock_level) VALUES
    ('3-C-P-SGP24U', (SELECT id FROM categories WHERE prefix = '3'), 'Galaxy S24 Ultra Replacement Battery',    'Premium', 2200, 60),
    ('3-C-P-SZF6',   (SELECT id FROM categories WHERE prefix = '3'), 'Galaxy Z Fold 6 Replacement Battery',     'Premium', 2800, 25);

-- ── Samsung Camera ──
INSERT INTO inventory (sku_id, category_id, part_name, quality_grade, wholesale_price, stock_level) VALUES
    ('3-B-O-SGP24U-CAM', (SELECT id FROM categories WHERE prefix = '3'), 'Galaxy S24 Ultra Rear Camera Array', 'OEM', 12500, 15);

-- ── Cross-Compatible OLED Display (iPhone 13 + iPhone 14) ──
INSERT INTO inventory (sku_id, category_id, part_name, quality_grade, wholesale_price, stock_level) VALUES
    ('1-B-A-IF13-14-OLED', (SELECT id FROM categories WHERE prefix = '1'), 'OLED Display Assembly — iPhone 13/14 Series', 'Aftermarket', 4500, 100);

-- ── Cross-Compatible Flex Cable (iPhone 13 all variants + iPhone 14 Base/Pro) ──
INSERT INTO inventory (sku_id, category_id, part_name, quality_grade, wholesale_price, stock_level) VALUES
    ('4-A-O-IF13-14-FLX', (SELECT id FROM categories WHERE prefix = '4'), 'Lightning Dock Flex Cable — iPhone 13/14 Series', 'OEM', 850, 420);


-- ==============================================================================
-- 15. SEED — SPECIFICATIONS
-- ==============================================================================

INSERT INTO specifications (sku_id, label, value) VALUES
    -- iPhone 16 Pro Max Battery
    ('3-C-P-IF16PrM', 'Capacity',         '4685 mAh'),
    ('3-C-P-IF16PrM', 'Chemistry',        'Lithium-Ion'),
    ('3-C-P-IF16PrM', 'Adhesive',         'Included'),
    ('3-C-P-IF16PrM', 'Playback',         '33 hours'),
    -- iPhone 15 Pro Max Battery
    ('3-C-P-IF15PrM', 'Capacity',         '4441 mAh'),
    ('3-C-P-IF15PrM', 'Chemistry',        'Lithium-Ion'),
    ('3-C-P-IF15PrM', 'Adhesive',         'Included'),
    ('3-C-P-IF15PrM', 'Playback',         '29 hours'),
    -- iPhone 14 Battery
    ('3-C-P-IF14',    'Capacity',         '3279 mAh'),
    ('3-C-P-IF14',    'Chemistry',        'Lithium-Ion'),
    ('3-C-P-IF14',    'Adhesive',         'Included'),
    -- iPhone 13 Battery
    ('3-C-O-IP13',    'Capacity',         '3227 mAh'),
    ('3-C-O-IP13',    'Chemistry',        'Lithium-Ion'),
    ('3-C-O-IP13',    'Adhesive',         'Included'),
    ('3-C-O-IP13',    'Cycle Life',       '500+ cycles'),
    -- iPhone 16 Pro Max Charge Port
    ('3-A-O-IF16PrM-CHG', 'Connector',   'USB-C'),
    ('3-A-O-IF16PrM-CHG', 'USB Spec',    'USB 3.0'),
    -- iPhone 14 Charge Port
    ('3-A-O-IF14-CHG',    'Connector',   'Lightning'),
    ('3-A-O-IF14-CHG',    'USB Spec',    'USB 2.0'),
    -- Galaxy S24 Ultra Battery
    ('3-C-P-SGP24U',  'Capacity',        '5000 mAh'),
    ('3-C-P-SGP24U',  'Fast Charging',   '45W'),
    ('3-C-P-SGP24U',  'Chemistry',       'Lithium-Ion'),
    -- Galaxy Z Fold 6 Battery
    ('3-C-P-SZF6',    'Capacity',        '4400 mAh (Dual Cell)'),
    ('3-C-P-SZF6',    'Fast Charging',   '25W'),
    ('3-C-P-SZF6',    'Cell Config',     'Dual Cell'),
    -- Galaxy S24 Ultra Camera
    ('3-B-O-SGP24U-CAM', 'Main',         '200MP Fusion'),
    ('3-B-O-SGP24U-CAM', 'Periscope',    '50MP 5x Optical'),
    ('3-B-O-SGP24U-CAM', 'Telephoto',    '10MP 3x Optical'),
    ('3-B-O-SGP24U-CAM', 'Ultra Wide',   '12MP'),
    -- Cross-compatible OLED display
    ('1-B-A-IF13-14-OLED', 'Panel Type', 'Super Retina XDR OLED'),
    ('1-B-A-IF13-14-OLED', 'Size',       '6.1"'),
    ('1-B-A-IF13-14-OLED', 'Refresh',    '60Hz'),
    ('1-B-A-IF13-14-OLED', 'Cross-Compatible', 'Yes'),
    -- Cross-compatible flex cable
    ('4-A-O-IF13-14-FLX', 'Connector',   'Lightning'),
    ('4-A-O-IF13-14-FLX', 'Length',      '18cm'),
    ('4-A-O-IF13-14-FLX', 'Microphone',  'Included'),
    ('4-A-O-IF13-14-FLX', 'Cross-Compatible', 'Yes');


-- ==============================================================================
-- 16. SEED — COMPATIBILITY MAP
--     Maps each SKU to the specific Variant IDs it fits.
--     Single-device parts get one row. Cross-compatible parts get many.
-- ==============================================================================

-- iPhone 16 Pro Max Battery → iPhone 16 Pro Max only
INSERT INTO compatibility_map (sku_id, variant_id) VALUES
    ('3-C-P-IF16PrM', (SELECT id FROM variants WHERE model_number = 'A3084'));

-- iPhone 15 Pro Max Battery → iPhone 15 Pro Max only
INSERT INTO compatibility_map (sku_id, variant_id) VALUES
    ('3-C-P-IF15PrM', (SELECT id FROM variants WHERE model_number = 'A2849'));

-- iPhone 14 Battery → iPhone 14 Base only
INSERT INTO compatibility_map (sku_id, variant_id) VALUES
    ('3-C-P-IF14', (SELECT id FROM variants WHERE model_number = 'A2649'));

-- iPhone 13 Battery → iPhone 13 Base only
INSERT INTO compatibility_map (sku_id, variant_id) VALUES
    ('3-C-O-IP13', (SELECT id FROM variants WHERE model_number = 'A2482'));

-- iPhone 16 Pro Max Charge Port → iPhone 16 Pro Max only
INSERT INTO compatibility_map (sku_id, variant_id) VALUES
    ('3-A-O-IF16PrM-CHG', (SELECT id FROM variants WHERE model_number = 'A3084'));

-- iPhone 14 Charge Port → iPhone 14 Base only
INSERT INTO compatibility_map (sku_id, variant_id) VALUES
    ('3-A-O-IF14-CHG', (SELECT id FROM variants WHERE model_number = 'A2649'));

-- Galaxy S24 Ultra Battery → S24 Ultra only
INSERT INTO compatibility_map (sku_id, variant_id) VALUES
    ('3-C-P-SGP24U', (SELECT id FROM variants WHERE model_number = 'SM-S928-24'));

-- Galaxy Z Fold 6 Battery → Z Fold 6 only
INSERT INTO compatibility_map (sku_id, variant_id) VALUES
    ('3-C-P-SZF6', (SELECT id FROM variants WHERE model_number = 'SM-F956'));

-- Galaxy S24 Ultra Camera → S24 Ultra only
INSERT INTO compatibility_map (sku_id, variant_id) VALUES
    ('3-B-O-SGP24U-CAM', (SELECT id FROM variants WHERE model_number = 'SM-S928-24'));

-- OLED Display → iPhone 13 Base + iPhone 14 Base (cross-compatible)
INSERT INTO compatibility_map (sku_id, variant_id) VALUES
    ('1-B-A-IF13-14-OLED', (SELECT id FROM variants WHERE model_number = 'A2482')),
    ('1-B-A-IF13-14-OLED', (SELECT id FROM variants WHERE model_number = 'A2649'));

-- Lightning Flex Cable → iPhone 13 (all 4) + iPhone 14 Base + iPhone 14 Pro (cross-compatible)
INSERT INTO compatibility_map (sku_id, variant_id) VALUES
    ('4-A-O-IF13-14-FLX', (SELECT id FROM variants WHERE model_number = 'A2481')),
    ('4-A-O-IF13-14-FLX', (SELECT id FROM variants WHERE model_number = 'A2482')),
    ('4-A-O-IF13-14-FLX', (SELECT id FROM variants WHERE model_number = 'A2483')),
    ('4-A-O-IF13-14-FLX', (SELECT id FROM variants WHERE model_number = 'A2484')),
    ('4-A-O-IF13-14-FLX', (SELECT id FROM variants WHERE model_number = 'A2649')),
    ('4-A-O-IF13-14-FLX', (SELECT id FROM variants WHERE model_number = 'A2650'));


-- ==============================================================================
-- VERIFICATION QUERIES
-- Run these after seeding to confirm everything landed correctly.
-- ==============================================================================

-- SELECT 'brands'          AS table_name, COUNT(*) AS rows FROM brands
-- UNION ALL
-- SELECT 'model_types',                   COUNT(*)         FROM model_types
-- UNION ALL
-- SELECT 'generations',                   COUNT(*)         FROM generations
-- UNION ALL
-- SELECT 'variants',                      COUNT(*)         FROM variants
-- UNION ALL
-- SELECT 'categories',                    COUNT(*)         FROM categories
-- UNION ALL
-- SELECT 'inventory',                     COUNT(*)         FROM inventory
-- UNION ALL
-- SELECT 'specifications',                COUNT(*)         FROM specifications
-- UNION ALL
-- SELECT 'compatibility_map',             COUNT(*)         FROM compatibility_map;

-- Expected counts:
--   brands:            2
--   model_types:       5
--   generations:      23
--   variants:         44
--   categories:        4
--   inventory:        11
--   specifications:   36
--   compatibility_map: 18
