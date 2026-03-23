 # Frontend-Backend Integration Plan

 ## Overview
 Connect the Next.js frontend to the new backend with the updated device hierarchy schema.

 ## Current State

 ### Backend (`/home/runner/workspace/backend/Test-master`)
 - Running at `http://localhost:3001`
 - New hierarchy: `Brand → ModelType → Generation → Variant`
 - API endpoints: `/api/brands`, `/api/hierarchy/:brandId`, `/api/inventory`, `/api/models`, `/api/parts`, `/api/cart/*`
 - Prisma schema with seeded data (4 categories, 2 brands, 6 variants, 4 inventory parts)

 ### Frontend (`/home/runner/workspace`)
 - Next.js 15 App Router
 - Current `lib/api.ts` is nearly empty (7 lines)
 - Components importing from `@/lib/api`:
   - `components/products-section.tsx`
   - `components/product/product-search-example.tsx`
   - `app/inventory/page.tsx`

 ---

 ## Proposed Steps

 ### Step 1: Copy API Client
 **Action:** Copy backend's `src/api.ts` to frontend's `lib/api.ts`

 **Reason:** The backend's api.ts contains both:
 - Legacy wrapper functions (returns old flat model shape)
 - New hierarchy-aware functions

 This keeps existing components working during migration.

 ---

 ### Step 2: Update API Base URL
 **Action:** Modify `lib/api.ts` line 12-13 to use environment variable

 ```typescript
 // Current
 const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://celltech-backend.vercel.app';

 // Change to
 const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3001';
 ```

 **Risk:** Low - just changes the endpoint

 ---

 ### Step 3: Update Environment Variables
 **Action:** Ensure `.env.local` has correct backend URL

 **Current:** `NEXT_PUBLIC_API_URL=https://your-railway-backend.up.railway.app`

 **Change to:** `NEXT_PUBLIC_API_URL=http://localhost:3001` (for local dev)

 ---

 ### Step 4: Test Inventory Page
 **Action:** Run frontend dev server and verify `/inventory` loads

 **Expected:** 
 - Brand filter populated from `/api/brands`
 - Model filter populated from `/api/models`
 - Inventory table populated from `/api/inventory`

 ---

 ### Step 5: Test Products Section
 **Action:** Verify homepage products section works

 **Expected:** Search by device name returns results from `/api/parts`

 ---

 ### Step 6: Verify Cart Flow (Optional)
 **Action:** Test cart validation endpoint if auth is implemented

 **Endpoints:** `/api/cart/validate`, `/api/cart/sync`, `/api/orders/checkout`

 ---

 ## Testing Checklist
 - [ ] Frontend loads at localhost:3000
 - [ ] Backend health check at localhost:3001/api/health
 - [ ] Inventory page shows brands from API
 - [ ] Inventory page shows parts from API
 - [ ] Homepage search returns results

 ---

 ## Rollback Plan
 If issues occur:
 1. Revert `lib/api.ts` to empty state
 2. Set `NEXT_PUBLIC_API_URL` back to original backend
 3. Frontend will fail gracefully (empty states shown)

 ---

 ## Estimated Time
 15-20 minutes

 ---

 ## Decision Required
 - [ ] Approve
 - [ ] Deny (with notes)
