-- =============================================================================
-- CellTech Distributor — PostgreSQL Deploy Script
-- Target: Neon (PostgreSQL)
-- Usage:  psql $DATABASE_URL -f deploy.sql
--         OR paste directly into the Neon SQL Editor
--
-- This is a FULL RESET. Every table is dropped and recreated.
-- Run against your dev database first, not production.
-- =============================================================================


-- =============================================================================
-- SECTION 1 — CLEANUP (drop in reverse dependency order)
-- =============================================================================

DROP TABLE IF EXISTS "OrderItem"           CASCADE;
DROP TABLE IF EXISTS "Order"               CASCADE;
DROP TABLE IF EXISTS "CartItem"            CASCADE;
DROP TABLE IF EXISTS "Cart"                CASCADE;
DROP TABLE IF EXISTS "CompatibilityMap"    CASCADE;
DROP TABLE IF EXISTS "Specification"       CASCADE;
DROP TABLE IF EXISTS "Inventory"           CASCADE;
DROP TABLE IF EXISTS "Category"            CASCADE;
DROP TABLE IF EXISTS "Variant"             CASCADE;
DROP TABLE IF EXISTS "Generation"          CASCADE;
DROP TABLE IF EXISTS "ModelType"           CASCADE;
DROP TABLE IF EXISTS "Brand"               CASCADE;
DROP TABLE IF EXISTS "VerificationToken"   CASCADE;
DROP TABLE IF EXISTS "Session"             CASCADE;
DROP TABLE IF EXISTS "Account"             CASCADE;
DROP TABLE IF EXISTS "User"                CASCADE;

DROP TYPE IF EXISTS "QualityGrade";
DROP TYPE IF EXISTS "UserRole";
DROP TYPE IF EXISTS "OrderStatus";


-- =============================================================================
-- SECTION 2 — ENUM TYPES
-- =============================================================================

CREATE TYPE "QualityGrade" AS ENUM (
  'OEM',
  'Premium',
  'Aftermarket',
  'U',   -- Unknown: legacy / unverified stock
  'NA'   -- Not Applicable: tools, adhesives, etc.
);

CREATE TYPE "UserRole" AS ENUM (
  'CUSTOMER',
  'ADMIN'
);

CREATE TYPE "OrderStatus" AS ENUM (
  'PENDING',
  'CONFIRMED',
  'SHIPPED',
  'DELIVERED',
  'CANCELLED'
);


-- =============================================================================
-- SECTION 3 — AUTH & B2B USER TABLES (NextAuth Prisma Adapter)
-- =============================================================================

CREATE TABLE "User" (
  "id"            TEXT        NOT NULL,
  "email"         TEXT        NOT NULL,
  "password"      TEXT,                              -- bcrypt hash; NULL for OAuth users
  "emailVerified" TIMESTAMPTZ,
  "name"          TEXT,
  "image"         TEXT,
  -- B2B-specific fields
  "company"       TEXT,
  "taxId"         TEXT,
  "netTerms"      BOOLEAN     NOT NULL DEFAULT FALSE, -- Net-30 approved accounts
  "role"          "UserRole"  NOT NULL DEFAULT 'CUSTOMER',
  "createdAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "User_email_key" ON "User" ("email");


CREATE TABLE "Account" (
  "id"                TEXT NOT NULL,
  "userId"            TEXT NOT NULL,
  "type"              TEXT NOT NULL,
  "provider"          TEXT NOT NULL,
  "providerAccountId" TEXT NOT NULL,
  "refresh_token"     TEXT,
  "access_token"      TEXT,
  "expires_at"        INT,
  "token_type"        TEXT,
  "scope"             TEXT,
  "id_token"          TEXT,
  "session_state"     TEXT,
  CONSTRAINT "Account_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "Account_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX "Account_provider_providerAccountId_key"
  ON "Account" ("provider", "providerAccountId");


CREATE TABLE "Session" (
  "id"           TEXT        NOT NULL,
  "sessionToken" TEXT        NOT NULL,
  "userId"       TEXT        NOT NULL,
  "expires"      TIMESTAMPTZ NOT NULL,
  CONSTRAINT "Session_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "Session_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE
);

CREATE UNIQUE INDEX "Session_sessionToken_key" ON "Session" ("sessionToken");


-- Required by NextAuth for email verification and password reset
CREATE TABLE "VerificationToken" (
  "identifier" TEXT        NOT NULL,
  "token"      TEXT        NOT NULL,
  "expires"    TIMESTAMPTZ NOT NULL,
  CONSTRAINT "VerificationToken_token_key" UNIQUE ("token"),
  CONSTRAINT "VerificationToken_identifier_token_key" UNIQUE ("identifier", "token")
);


-- =============================================================================
-- SECTION 4 — DEVICE HIERARCHY  (Brand → ModelType → Generation → Variant)
-- =============================================================================

CREATE TABLE "Brand" (
  "id"        SERIAL      NOT NULL,
  "name"      TEXT        NOT NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "Brand_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "Brand_name_key" ON "Brand" ("name");


CREATE TABLE "ModelType" (
  "id"        SERIAL      NOT NULL,
  "brandId"   INT         NOT NULL,
  "name"      TEXT        NOT NULL,  -- e.g., 'iPhone', 'Galaxy S', 'Galaxy Z Fold'
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "ModelType_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ModelType_brandId_fkey"
    FOREIGN KEY ("brandId") REFERENCES "Brand" ("id")
);

CREATE UNIQUE INDEX "ModelType_brandId_name_key" ON "ModelType" ("brandId", "name");


CREATE TABLE "Generation" (
  "id"          SERIAL      NOT NULL,
  "modelTypeId" INT         NOT NULL,
  "name"        TEXT        NOT NULL,  -- e.g., '13', '14', 'S24'
  "releaseYear" INT,
  "createdAt"   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "Generation_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "Generation_modelTypeId_fkey"
    FOREIGN KEY ("modelTypeId") REFERENCES "ModelType" ("id")
);

CREATE UNIQUE INDEX "Generation_modelTypeId_name_key" ON "Generation" ("modelTypeId", "name");


CREATE TABLE "Variant" (
  "id"           SERIAL      NOT NULL,
  "generationId" INT         NOT NULL,
  "name"         TEXT        NOT NULL,   -- e.g., 'Pro Max', 'Ultra', 'Base'
  "modelNumber"  TEXT        NOT NULL,   -- e.g., 'A2631', 'SM-S928U'
  "createdAt"    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "Variant_pkey"        PRIMARY KEY ("id"),
  CONSTRAINT "Variant_modelNumber_key" UNIQUE ("modelNumber"),
  CONSTRAINT "Variant_generationId_fkey"
    FOREIGN KEY ("generationId") REFERENCES "Generation" ("id")
);

CREATE UNIQUE INDEX "Variant_generationId_name_key" ON "Variant" ("generationId", "name");


-- =============================================================================
-- SECTION 5 — CATALOG & INVENTORY
-- =============================================================================

-- The 4 Buckets:
--   1 = Visual Interface
--   2 = Chassis & Enclosure
--   3 = Functional Modules
--   4 = Interconnects
CREATE TABLE "Category" (
  "id"        SERIAL      NOT NULL,
  "name"      TEXT        NOT NULL,  -- e.g., 'Functional Modules'
  "prefix"    TEXT        NOT NULL,  -- e.g., '1', '2', '3', '4'
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "Category_pkey"       PRIMARY KEY ("id"),
  CONSTRAINT "Category_name_key"   UNIQUE ("name"),
  CONSTRAINT "Category_prefix_key" UNIQUE ("prefix")
);


-- Smart SKU format: [Bucket]-[PartType]-[Grade]-[Device]
-- e.g., 3-C-O-IP13 = Functional Module / Battery / OEM / iPhone 13
CREATE TABLE "Inventory" (
  "skuId"          TEXT           NOT NULL,
  "categoryId"     INT            NOT NULL,
  "partName"       TEXT           NOT NULL,
  "qualityGrade"   "QualityGrade" NOT NULL,
  "wholesalePrice" INT            NOT NULL DEFAULT 0,  -- cents; 0 = 'Contact for Price'
  "stockLevel"     INT            NOT NULL DEFAULT 0,
  "createdAt"      TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  "updatedAt"      TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
  CONSTRAINT "Inventory_pkey"       PRIMARY KEY ("skuId"),
  CONSTRAINT "Inventory_categoryId_fkey"
    FOREIGN KEY ("categoryId") REFERENCES "Category" ("id")
);


-- Dedicated spec rows — filterable, queryable, never pipe-delimited strings
CREATE TABLE "Specification" (
  "id"        SERIAL      NOT NULL,
  "skuId"     TEXT        NOT NULL,
  "label"     TEXT        NOT NULL,  -- e.g., 'Capacity'
  "value"     TEXT        NOT NULL,  -- e.g., '3227 mAh'
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "Specification_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "Specification_skuId_label_key" UNIQUE ("skuId", "label"),  -- one value per label per part
  CONSTRAINT "Specification_skuId_fkey"
    FOREIGN KEY ("skuId") REFERENCES "Inventory" ("skuId") ON DELETE CASCADE
);


-- Many-to-many glue: one part → many variants, one variant → many parts
CREATE TABLE "CompatibilityMap" (
  "skuId"     TEXT NOT NULL,
  "variantId" INT  NOT NULL,
  CONSTRAINT "CompatibilityMap_pkey" PRIMARY KEY ("skuId", "variantId"),
  CONSTRAINT "CompatibilityMap_skuId_fkey"
    FOREIGN KEY ("skuId")     REFERENCES "Inventory" ("skuId")   ON DELETE CASCADE,
  CONSTRAINT "CompatibilityMap_variantId_fkey"
    FOREIGN KEY ("variantId") REFERENCES "Variant"   ("id")      ON DELETE CASCADE
);


-- =============================================================================
-- SECTION 6 — CART (server-side persistence for multi-session B2B quotes)
-- =============================================================================

CREATE TABLE "Cart" (
  "id"        TEXT        NOT NULL,
  "userId"    TEXT        NOT NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "Cart_pkey"    PRIMARY KEY ("id"),
  CONSTRAINT "Cart_userId_key" UNIQUE ("userId"),            -- one active cart per user
  CONSTRAINT "Cart_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User" ("id") ON DELETE CASCADE
);


CREATE TABLE "CartItem" (
  "id"        TEXT        NOT NULL,
  "cartId"    TEXT        NOT NULL,
  "skuId"     TEXT        NOT NULL,
  "quantity"  INT         NOT NULL,
  "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "CartItem_pkey"            PRIMARY KEY ("id"),
  CONSTRAINT "CartItem_cartId_skuId_key" UNIQUE ("cartId", "skuId"),  -- adding existing SKU updates qty
  CONSTRAINT "CartItem_cartId_fkey"
    FOREIGN KEY ("cartId") REFERENCES "Cart"      ("id")    ON DELETE CASCADE,
  CONSTRAINT "CartItem_skuId_fkey"
    FOREIGN KEY ("skuId")  REFERENCES "Inventory" ("skuId")
);


-- =============================================================================
-- SECTION 7 — ORDERS (B2B ledger — prices snapshotted at purchase time)
-- =============================================================================

CREATE TABLE "Order" (
  "id"                    TEXT          NOT NULL,
  "userId"                TEXT          NOT NULL,
  "status"                "OrderStatus" NOT NULL DEFAULT 'PENDING',
  "shippingAddress"       JSONB         NOT NULL,  -- snapshot at order time, never join back to User
  "stripePaymentIntentId" TEXT,
  "notes"                 TEXT,
  "createdAt"             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  "updatedAt"             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  CONSTRAINT "Order_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "Order_stripePaymentIntentId_key" UNIQUE ("stripePaymentIntentId"),
  CONSTRAINT "Order_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User" ("id")
);


CREATE TABLE "OrderItem" (
  "id"                  TEXT        NOT NULL,
  "orderId"             TEXT        NOT NULL,
  "skuId"               TEXT        NOT NULL,
  "quantity"            INT         NOT NULL,
  "unitPriceAtPurchase" INT         NOT NULL,  -- cents, snapshot — never join back to Inventory for history
  "createdAt"           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "OrderItem_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "OrderItem_orderId_fkey"
    FOREIGN KEY ("orderId") REFERENCES "Order"     ("id")    ON DELETE CASCADE,
  CONSTRAINT "OrderItem_skuId_fkey"
    FOREIGN KEY ("skuId")   REFERENCES "Inventory" ("skuId")
);


-- =============================================================================
-- SECTION 8 — INDEXES (common query patterns)
-- =============================================================================

-- Hierarchy traversal
CREATE INDEX "idx_modeltype_brandid"      ON "ModelType"  ("brandId");
CREATE INDEX "idx_generation_modeltypeid" ON "Generation" ("modelTypeId");
CREATE INDEX "idx_variant_generationid"   ON "Variant"    ("generationId");

-- Inventory lookups
CREATE INDEX "idx_inventory_categoryid"   ON "Inventory"  ("categoryId");
CREATE INDEX "idx_inventory_grade"        ON "Inventory"  ("qualityGrade");
CREATE INDEX "idx_inventory_stock"        ON "Inventory"  ("stockLevel");

-- Compatibility joins
CREATE INDEX "idx_compat_variantid"       ON "CompatibilityMap" ("variantId");

-- Cart and order queries
CREATE INDEX "idx_cartitem_cartid"        ON "CartItem"  ("cartId");
CREATE INDEX "idx_orderitem_orderid"      ON "OrderItem" ("orderId");


-- =============================================================================
-- SECTION 9 — SEED DATA
-- =============================================================================

-- ── 9a. CATEGORIES (The 4 Buckets) ──────────────────────────────────────────

INSERT INTO "Category" ("name", "prefix") VALUES
  ('Visual Interface',    '1'),
  ('Chassis & Enclosure', '2'),
  ('Functional Modules',  '3'),
  ('Interconnects',       '4');


-- ── 9b. ADMIN USER ───────────────────────────────────────────────────────────
-- Password is bcrypt('admin123', 10). Change before deploying to production.

INSERT INTO "User" ("id", "email", "password", "name", "role", "company") VALUES
  (
    'cluser0000000000000000000',
    'admin@celltech.com',
    '$2b$10$wplaIA1smM7p9nWnq8wCM.h2iPg9JsGsoCfp2CvZHdRK8OhzC9PrK',
    'System Admin',
    'ADMIN',
    'CellTech Distributor'
  );


-- ── 9c. BRANDS ───────────────────────────────────────────────────────────────

INSERT INTO "Brand" ("name") VALUES
  ('Apple'),
  ('Samsung');


-- ── 9d. MODEL TYPES ──────────────────────────────────────────────────────────

INSERT INTO "ModelType" ("brandId", "name")
SELECT b."id", mt."name"
FROM (VALUES
  ('Apple',   'iPhone'),
  ('Samsung', 'Galaxy S')
) AS mt ("brand", "name")
JOIN "Brand" b ON b."name" = mt."brand";


-- ── 9e. GENERATIONS ──────────────────────────────────────────────────────────

INSERT INTO "Generation" ("modelTypeId", "name", "releaseYear")
SELECT mt."id", g."name", g."year"
FROM (VALUES
  ('iPhone',   '13', 2021),
  ('iPhone',   '14', 2022),
  ('Galaxy S', '24', 2024)
) AS g ("modelTypeName", "name", "year")
JOIN "ModelType" mt ON mt."name" = g."modelTypeName";


-- ── 9f. VARIANTS ─────────────────────────────────────────────────────────────

INSERT INTO "Variant" ("generationId", "name", "modelNumber")
SELECT gen."id", v."name", v."modelNumber"
FROM (VALUES
  -- iPhone 13 family
  ('iPhone', '13', 'Base',    'A2631'),
  ('iPhone', '13', 'Pro',     'A2636'),
  ('iPhone', '13', 'Pro Max', 'A2643'),
  -- iPhone 14 family
  ('iPhone', '14', 'Base',    'A2649'),
  ('iPhone', '14', 'Pro',     'A2650'),
  -- Samsung Galaxy S24
  ('Galaxy S', '24', 'Ultra', 'SM-S928U')
) AS v ("modelTypeName", "genName", "name", "modelNumber")
JOIN "ModelType" mt  ON mt."name"  = v."modelTypeName"
JOIN "Generation" gen ON gen."modelTypeId" = mt."id"
                     AND gen."name"        = v."genName";


-- ── 9g. INVENTORY PARTS ──────────────────────────────────────────────────────

INSERT INTO "Inventory" ("skuId", "categoryId", "partName", "qualityGrade", "wholesalePrice", "stockLevel")
SELECT i."skuId", c."id", i."partName", i."qualityGrade"::"QualityGrade", i."price", i."stock"
FROM (VALUES
  ('3-C-O-IP13',    'Functional Modules',  'iPhone 13 Replacement Battery',               'OEM',     1450,  100),
  ('1-B-P-S24U',    'Visual Interface',    'Galaxy S24 Ultra OLED Screen Assembly',       'Premium', 22500,  15),
  ('4-A-O-IP13-14', 'Interconnects',       'Lightning Dock Flex Cable — iPhone 13/14 Series', 'OEM', 850, 420),
  ('1-B-P-IP14P',   'Visual Interface',    'iPhone 14 Pro Super Retina XDR OLED Assembly','Premium',18500,  30)
) AS i ("skuId", "catName", "partName", "qualityGrade", "price", "stock")
JOIN "Category" c ON c."name" = i."catName";


-- ── 9h. SPECIFICATIONS ───────────────────────────────────────────────────────

INSERT INTO "Specification" ("skuId", "label", "value") VALUES
  -- iPhone 13 Battery
  ('3-C-O-IP13',    'Capacity',          '3227 mAh'),
  ('3-C-O-IP13',    'Chemistry',          'Lithium-Ion'),
  ('3-C-O-IP13',    'Adhesive Included',  'Yes'),
  ('3-C-O-IP13',    'Cycle Life',         '500+ cycles'),
  -- Galaxy S24 Ultra OLED
  ('1-B-P-S24U',    'Panel Type',         'Dynamic AMOLED 2X'),
  ('1-B-P-S24U',    'Resolution',         '3088 x 1440'),
  ('1-B-P-S24U',    'Refresh Rate',       '120Hz'),
  ('1-B-P-S24U',    'Size',               '6.8"'),
  -- Lightning Flex Cable
  ('4-A-O-IP13-14', 'Connector Type',     'Lightning'),
  ('4-A-O-IP13-14', 'Cable Length',       '18cm'),
  ('4-A-O-IP13-14', 'Microphone',         'Included'),
  ('4-A-O-IP13-14', 'Cross-Compatible',   'Yes'),
  -- iPhone 14 Pro OLED
  ('1-B-P-IP14P',   'Panel Type',         'Super Retina XDR OLED'),
  ('1-B-P-IP14P',   'Resolution',         '2556 x 1179'),
  ('1-B-P-IP14P',   'Refresh Rate',       '120Hz ProMotion'),
  ('1-B-P-IP14P',   'Size',               '6.1"');


-- ── 9i. COMPATIBILITY MAP ────────────────────────────────────────────────────

-- iPhone 13 Battery → iPhone 13 Base only
INSERT INTO "CompatibilityMap" ("skuId", "variantId")
SELECT '3-C-O-IP13', v."id"
FROM "Variant" v WHERE v."modelNumber" = 'A2631';  -- iPhone 13 Base

-- Galaxy S24 Ultra OLED → S24 Ultra only
INSERT INTO "CompatibilityMap" ("skuId", "variantId")
SELECT '1-B-P-S24U', v."id"
FROM "Variant" v WHERE v."modelNumber" = 'SM-S928U';  -- Galaxy S24 Ultra

-- Lightning Flex Cable → iPhone 13 Base, Pro, Pro Max + iPhone 14 Base, Pro (5 rows)
INSERT INTO "CompatibilityMap" ("skuId", "variantId")
SELECT '4-A-O-IP13-14', v."id"
FROM "Variant" v
WHERE v."modelNumber" IN ('A2631', 'A2636', 'A2643', 'A2649', 'A2650');

-- iPhone 14 Pro OLED → iPhone 14 Pro only
INSERT INTO "CompatibilityMap" ("skuId", "variantId")
SELECT '1-B-P-IP14P', v."id"
FROM "Variant" v WHERE v."modelNumber" = 'A2650';  -- iPhone 14 Pro


-- =============================================================================
-- SECTION 10 — VERIFICATION QUERIES  (uncomment and run after seeding)
-- =============================================================================

-- Expected counts after a clean run:
--   categories:       4
--   users:            1
--   brands:           2
--   model_types:      2
--   generations:      3
--   variants:         6
--   inventory:        4
--   specifications:  16
--   compat_rows:      8   (1 + 1 + 5 + 1)

/*
SELECT 'categories'     AS table_name, COUNT(*) AS row_count FROM "Category"
UNION ALL
SELECT 'users',                         COUNT(*) FROM "User"
UNION ALL
SELECT 'brands',                        COUNT(*) FROM "Brand"
UNION ALL
SELECT 'model_types',                   COUNT(*) FROM "ModelType"
UNION ALL
SELECT 'generations',                   COUNT(*) FROM "Generation"
UNION ALL
SELECT 'variants',                      COUNT(*) FROM "Variant"
UNION ALL
SELECT 'inventory',                     COUNT(*) FROM "Inventory"
UNION ALL
SELECT 'specifications',                COUNT(*) FROM "Specification"
UNION ALL
SELECT 'compat_rows',                   COUNT(*) FROM "CompatibilityMap"
ORDER BY table_name;
*/

-- Verify cross-compatible flex cable maps to exactly 5 variants:
/*
SELECT i."skuId", i."partName", COUNT(cm."variantId") AS compat_count
FROM "Inventory" i
JOIN "CompatibilityMap" cm ON cm."skuId" = i."skuId"
WHERE i."skuId" = '4-A-O-IP13-14'
GROUP BY i."skuId", i."partName";
-- Expected: compat_count = 5
*/

-- Verify full hierarchy resolves cleanly:
/*
SELECT
  b."name"   AS brand,
  mt."name"  AS model_type,
  g."name"   AS generation,
  g."releaseYear",
  v."name"   AS variant,
  v."modelNumber"
FROM "Variant" v
JOIN "Generation" g  ON g."id"  = v."generationId"
JOIN "ModelType"  mt ON mt."id" = g."modelTypeId"
JOIN "Brand"      b  ON b."id"  = mt."brandId"
ORDER BY b."name", mt."name", g."releaseYear", v."name";
-- Expected: 6 rows
*/
