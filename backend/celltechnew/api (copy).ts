/**
 * lib/api.ts
 * CellTech API Client
 *
 * Two sets of functions:
 *   LEGACY  — original flat-model functions; kept so existing components
 *             (ProductsSection, inventory/page, product-search-example) need
 *             no changes during the Device Explorer migration.
 *   NEW     — hierarchy-aware functions for the Device Explorer and cart sync.
 */

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || 'https://celltech-backend.vercel.app';

// ─── SHARED FETCH HELPER ─────────────────────────────

async function apiFetch<T>(url: string, options?: RequestInit): Promise<T> {
  const res = await fetch(url, options);
  if (!res.ok) {
    const text = await res.text().catch(() => res.statusText);
    throw new Error(`API ${res.status}: ${text}`);
  }
  return res.json() as Promise<T>;
}

// ─── LEGACY INTERFACES (match existing component props) ──

export interface Brand {
  id:   number;
  name: string;
}

export interface Model {
  id:            number;
  modelNumber:   string;
  marketingName: string;
  releaseYear?:  number | null;
  brandId:       number;
  brand?:        Brand;
}

export interface InventoryItem {
  skuId:            string;
  partName?:        string;
  specifications?:  string;          // legacy string field — not used in new responses
  category:         string;
  quality?:         string;
  price?:           number | null;
  stock:            number;
  primaryModel?:    string | null;
  compatibleModels?: Model[];
}

// ─── NEW INTERFACES (Device Explorer + Cart) ─────────

export interface Variant {
  id:          number;
  name:        string;
  modelNumber: string;
  generation?: string;
  modelType?:  string;
  brand?:      string;
  releaseYear?: number | null;
}

export interface Generation {
  id:          number;
  name:        string;
  releaseYear?: number | null;
  variants:    Variant[];
}

export interface ModelType {
  id:          number;
  name:        string;
  generations: Generation[];
}

export interface BrandHierarchy extends Brand {
  hierarchy: ModelType[];
}

export interface SpecificationItem {
  label: string;
  value: string;
}

export interface FullInventoryItem {
  skuId:           string;
  partName:        string;
  category:        string;
  categoryPrefix?: string;
  quality:         string;
  price:           number;
  stock:           number;
  specifications:  SpecificationItem[];
  compatibleWith?: Array<{
    variantId:     number;
    modelNumber:   string;
    marketingName: string;
    brand:         string;
  }>;
  compatibleModels?: Array<{
    id:            number;
    modelNumber:   string;
    marketingName: string;
    brand:         string;
    releaseYear?:  number | null;
  }>;
  primaryModel?: string | null;
}

export interface PaginationMeta {
  total:      number;
  page:       number;
  limit:      number;
  totalPages: number;
}

export interface CartSyncItem {
  skuId:    string;
  quantity: number;
}

// ─── LEGACY FUNCTIONS ────────────────────────────────
// These keep existing components working without any changes.

/**
 * Fetch all inventory (paginated, no filters).
 * Used by: app/inventory/page.tsx
 */
export async function fetchInventory(): Promise<InventoryItem[]> {
  try {
    const data = await apiFetch<{ inventory: InventoryItem[] }>(
      `${API_BASE_URL}/api/inventory?limit=100`,
      { cache: 'no-store' }
    );
    return data.inventory || [];
  } catch (error) {
    console.error('[fetchInventory]', error);
    return [];
  }
}

/**
 * Fetch inventory for a specific model/variant ID.
 * Used by: app/inventory/page.tsx filter
 */
export async function fetchInventoryByModel(modelId: number): Promise<InventoryItem[]> {
  try {
    const data = await apiFetch<{ parts: InventoryItem[] }>(
      `${API_BASE_URL}/api/inventory/model/${modelId}`,
      { cache: 'no-store' }
    );
    return data.parts || [];
  } catch (error) {
    console.error('[fetchInventoryByModel]', error);
    return [];
  }
}

/**
 * Fetch a single part by SKU.
 * Used by: product detail page fallback
 */
export async function fetchPartBySku(skuId: string): Promise<InventoryItem | null> {
  try {
    const data = await apiFetch<{ part: InventoryItem }>(
      `${API_BASE_URL}/api/inventory/${encodeURIComponent(skuId)}`,
      { cache: 'no-store' }
    );
    return data.part || null;
  } catch (error) {
    console.error('[fetchPartBySku]', error);
    return null;
  }
}

/**
 * Fetch all brands (flat list).
 * Used by: app/inventory/page.tsx brand filter
 */
export async function fetchBrands(): Promise<Brand[]> {
  try {
    const data = await apiFetch<{ brands: Brand[] }>(
      `${API_BASE_URL}/api/brands`,
      { cache: 'no-store' }
    );
    return data.brands || [];
  } catch (error) {
    console.error('[fetchBrands]', error);
    return [];
  }
}

/**
 * Fetch models (returns Variants shaped as old Model type).
 * Used by: app/inventory/page.tsx model filter, product-search-example
 */
export async function fetchModels(brandId?: number): Promise<Model[]> {
  try {
    const url = brandId
      ? `${API_BASE_URL}/api/models?brandId=${brandId}`
      : `${API_BASE_URL}/api/models`;
    const data = await apiFetch<{ models: Model[] }>(url, { cache: 'no-store' });
    return data.models || [];
  } catch (error) {
    console.error('[fetchModels]', error);
    return [];
  }
}

/**
 * Search parts by device name string.
 * Used by: components/products-section.tsx, product-search-example
 */
export async function searchParts(device: string): Promise<{
  success: boolean;
  parts: InventoryItem[];
  count?: number;
}> {
  try {
    return await apiFetch(
      `${API_BASE_URL}/api/parts?device=${encodeURIComponent(device)}`
    );
  } catch (error) {
    console.error('[searchParts]', error);
    return { success: false, parts: [] };
  }
}

/**
 * Get full part detail by SKU.
 * Used by: app/product/[skuId]/page.tsx
 */
export async function getPartDetails(skuId: string): Promise<{
  success: boolean;
  part: FullInventoryItem;
}> {
  return apiFetch(
    `${API_BASE_URL}/api/inventory/${encodeURIComponent(skuId)}`,
    { cache: 'no-store' }
  );
}

/**
 * Get compatibility list for a SKU.
 * Used by: FitmentChecker (fallback)
 */
export async function getCompatibility(skuId: string): Promise<{
  success: boolean;
  compatibleModels: Variant[];
}> {
  return apiFetch(
    `${API_BASE_URL}/api/compatibility/${encodeURIComponent(skuId)}`,
    { cache: 'no-store' }
  );
}

/**
 * Health check.
 */
export async function checkBackendHealth(): Promise<boolean> {
  try {
    await apiFetch(`${API_BASE_URL}/api/health`, { cache: 'no-store' });
    return true;
  } catch {
    return false;
  }
}

// ─── NEW FUNCTIONS (Device Explorer + Cart) ──────────

/**
 * Get the full Brand → ModelType → Generation → Variant tree for one brand.
 * Used by: Device Explorer drill-down navigation.
 */
export async function getDeviceHierarchy(brandId: number): Promise<{
  brand:     Brand;
  hierarchy: ModelType[];
}> {
  return apiFetch(
    `${API_BASE_URL}/api/hierarchy/${brandId}`,
    { cache: 'no-store' }
  );
}

/**
 * Get all parts compatible with a specific Variant ID.
 * Used by: Device Explorer product grid.
 */
export async function getPartsForVariant(variantId: number): Promise<{
  success: boolean;
  variant: Variant;
  count:   number;
  parts:   FullInventoryItem[];
}> {
  return apiFetch(
    `${API_BASE_URL}/api/inventory/variant/${variantId}`,
    { cache: 'no-store' }
  );
}

/**
 * Fetch all categories with part counts.
 * Used by: Device Explorer filter chips, catalog page.
 */
export async function fetchCategories(): Promise<Array<{
  id:        number;
  name:      string;
  prefix:    string;
  partCount: number;
}>> {
  try {
    const data = await apiFetch<{ categories: Array<{ id: number; name: string; prefix: string; partCount: number }> }>(
      `${API_BASE_URL}/api/categories`,
      { cache: 'no-store' }
    );
    return data.categories || [];
  } catch (error) {
    console.error('[fetchCategories]', error);
    return [];
  }
}

/**
 * Fetch paginated inventory with optional filters.
 * Used by: catalog page, Device Explorer filtered views.
 */
export async function fetchInventoryFiltered(params?: {
  category?: string;
  brand?:    string;
  quality?:  string;
  page?:     number;
  limit?:    number;
}): Promise<{
  pagination: PaginationMeta;
  inventory:  FullInventoryItem[];
}> {
  const query = new URLSearchParams();
  if (params?.category) query.set('category', params.category);
  if (params?.brand)    query.set('brand',    params.brand);
  if (params?.quality)  query.set('quality',  params.quality);
  if (params?.page)     query.set('page',     String(params.page));
  if (params?.limit)    query.set('limit',    String(params.limit));

  const url = `${API_BASE_URL}/api/inventory?${query.toString()}`;
  return apiFetch(url, { cache: 'no-store' });
}

/**
 * Sync the client-side Zustand cart to the server.
 * Call debounced (500ms) whenever the local cart changes.
 * Only call when user is authenticated.
 */
export async function syncCart(
  userId: string,
  items:  CartSyncItem[]
): Promise<{ success: boolean; cartId?: string; itemCount?: number }> {
  return apiFetch(`${API_BASE_URL}/api/cart/sync`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify({ userId, items }),
  });
}

/**
 * Validate cart items before checkout (MOQ + stock check).
 * Call before creating a Stripe session.
 */
export async function validateCart(items: CartSyncItem[]): Promise<{
  success:    boolean;
  valid:      boolean;
  orderTotal: number;
  items:      Array<{
    skuId:    string;
    quantity: number;
    valid:    boolean;
    errors:   string[];
    part?:    { partName: string; price: number; stock: number; subtotal: number };
  }>;
}> {
  return apiFetch(`${API_BASE_URL}/api/cart/validate`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify({ items }),
  });
}

/**
 * Convert the server-side cart into an Order.
 * Call after validateCart() passes and Stripe payment succeeds.
 */
export async function checkout(
  userId:          string,
  shippingAddress: object
): Promise<{
  success: boolean;
  order:   {
    id:         string;
    status:     string;
    itemCount:  number;
    orderTotal: number;
    createdAt:  string;
  };
}> {
  return apiFetch(`${API_BASE_URL}/api/orders/checkout`, {
    method:  'POST',
    headers: { 'Content-Type': 'application/json' },
    body:    JSON.stringify({ userId, shippingAddress }),
  });
}
