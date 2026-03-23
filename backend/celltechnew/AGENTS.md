Four files. Here's a precise summary of what changed in each and what to do before deploying.

---

**schema.prisma** — Clean output of your approved design. No changes from `update.txt` except inline comments explaining every table and constraint. This is your source of truth going forward.

**seed.ts** — Two additions beyond your version. First, `bcrypt` is now used correctly (`import bcrypt from 'bcrypt'` — run `npm install bcrypt && npm install -D @types/bcrypt` before seeding). Second, a cross-compatible part `4-A-O-IP13-14` is seeded with 5 rows in `CompatibilityMap` pointing to iPhone 13 Base, Pro, Pro Max, iPhone 14 Base, and iPhone 14 Pro — this validates the entire schema design end-to-end and gives the `CompatibilityMatrix` component something real to render. The delete order at the top is also complete — `verificationToken`, `session`, and `account` are now cleared before `user`.

**server.ts** — Full merge of old and new. All routes from the previously fixed version are preserved (`GET /api/inventory` with filters, `GET /api/models` backward-compat, `GET /api/categories`, `POST /api/cart/validate`). All new routes from your stub are added (`GET /api/hierarchy/:brandId`, `GET /api/inventory/variant/:variantId`, `POST /api/cart/sync`, `POST /api/orders/checkout`). Every single route has try/catch. The error handler is at the bottom. The route ordering comment explains why `/inventory/variant/:id` must precede `/inventory/:skuId`. All Prisma queries now walk the full hierarchy to build readable strings like `"iPhone 13 Pro Max"` from raw relation data.

**api.ts** — Three fixes applied across the board: `API_BASE_URL` now reads from `NEXT_PUBLIC_API_URL` env var so it works in production; a shared `apiFetch<T>` helper handles `res.ok` checking and throws real errors on every call instead of silently failing; all original functions (`fetchInventory`, `fetchBrands`, `fetchModels`, `searchParts`, `getPartDetails`, `getCompatibility`, `checkBackendHealth`) are preserved untouched so zero existing components break. New functions are additive: `getDeviceHierarchy`, `getPartsForVariant`, `fetchCategories`, `fetchInventoryFiltered`, `syncCart`, `validateCart`, `checkout`.

---

**Migration steps when you deploy:**

```bash
npx prisma migrate dev --name "new_hierarchy_schema"
npx prisma generate
npx ts-node prisma/seed.ts
```

Run these against your Neon dev database first, not production.