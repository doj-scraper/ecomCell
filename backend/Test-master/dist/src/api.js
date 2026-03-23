"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.fetchInventory = fetchInventory;
exports.fetchInventoryByModel = fetchInventoryByModel;
exports.fetchPartBySku = fetchPartBySku;
exports.fetchBrands = fetchBrands;
exports.fetchModels = fetchModels;
exports.searchParts = searchParts;
exports.getPartDetails = getPartDetails;
exports.getCompatibility = getCompatibility;
exports.checkBackendHealth = checkBackendHealth;
exports.getDeviceHierarchy = getDeviceHierarchy;
exports.getPartsForVariant = getPartsForVariant;
exports.fetchCategories = fetchCategories;
exports.fetchInventoryFiltered = fetchInventoryFiltered;
exports.syncCart = syncCart;
exports.validateCart = validateCart;
exports.checkout = checkout;
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://celltech-backend.vercel.app';
// ─── SHARED FETCH HELPER ─────────────────────────────
async function apiFetch(url, options) {
    const res = await fetch(url, options);
    if (!res.ok) {
        const text = await res.text().catch(() => res.statusText);
        throw new Error(`API ${res.status}: ${text}`);
    }
    return res.json();
}
// ─── LEGACY FUNCTIONS ────────────────────────────────
// These keep existing components working without any changes.
/**
 * Fetch all inventory (paginated, no filters).
 * Used by: app/inventory/page.tsx
 */
async function fetchInventory() {
    try {
        const data = await apiFetch(`${API_BASE_URL}/api/inventory?limit=100`, { cache: 'no-store' });
        return data.inventory || [];
    }
    catch (error) {
        console.error('[fetchInventory]', error);
        return [];
    }
}
/**
 * Fetch inventory for a specific model/variant ID.
 * Used by: app/inventory/page.tsx filter
 */
async function fetchInventoryByModel(modelId) {
    try {
        const data = await apiFetch(`${API_BASE_URL}/api/inventory/model/${modelId}`, { cache: 'no-store' });
        return data.parts || [];
    }
    catch (error) {
        console.error('[fetchInventoryByModel]', error);
        return [];
    }
}
/**
 * Fetch a single part by SKU.
 * Used by: product detail page fallback
 */
async function fetchPartBySku(skuId) {
    try {
        const data = await apiFetch(`${API_BASE_URL}/api/inventory/${encodeURIComponent(skuId)}`, { cache: 'no-store' });
        return data.part || null;
    }
    catch (error) {
        console.error('[fetchPartBySku]', error);
        return null;
    }
}
/**
 * Fetch all brands (flat list).
 * Used by: app/inventory/page.tsx brand filter
 */
async function fetchBrands() {
    try {
        const data = await apiFetch(`${API_BASE_URL}/api/brands`, { cache: 'no-store' });
        return data.brands || [];
    }
    catch (error) {
        console.error('[fetchBrands]', error);
        return [];
    }
}
/**
 * Fetch models (returns Variants shaped as old Model type).
 * Used by: app/inventory/page.tsx model filter, product-search-example
 */
async function fetchModels(brandId) {
    try {
        const url = brandId
            ? `${API_BASE_URL}/api/models?brandId=${brandId}`
            : `${API_BASE_URL}/api/models`;
        const data = await apiFetch(url, { cache: 'no-store' });
        return data.models || [];
    }
    catch (error) {
        console.error('[fetchModels]', error);
        return [];
    }
}
/**
 * Search parts by device name string.
 * Used by: components/products-section.tsx, product-search-example
 */
async function searchParts(device) {
    try {
        return await apiFetch(`${API_BASE_URL}/api/parts?device=${encodeURIComponent(device)}`);
    }
    catch (error) {
        console.error('[searchParts]', error);
        return { success: false, parts: [] };
    }
}
/**
 * Get full part detail by SKU.
 * Used by: app/product/[skuId]/page.tsx
 */
async function getPartDetails(skuId) {
    return apiFetch(`${API_BASE_URL}/api/inventory/${encodeURIComponent(skuId)}`, { cache: 'no-store' });
}
/**
 * Get compatibility list for a SKU.
 * Used by: FitmentChecker (fallback)
 */
async function getCompatibility(skuId) {
    return apiFetch(`${API_BASE_URL}/api/compatibility/${encodeURIComponent(skuId)}`, { cache: 'no-store' });
}
/**
 * Health check.
 */
async function checkBackendHealth() {
    try {
        await apiFetch(`${API_BASE_URL}/api/health`, { cache: 'no-store' });
        return true;
    }
    catch {
        return false;
    }
}
// ─── NEW FUNCTIONS (Device Explorer + Cart) ──────────
/**
 * Get the full Brand → ModelType → Generation → Variant tree for one brand.
 * Used by: Device Explorer drill-down navigation.
 */
async function getDeviceHierarchy(brandId) {
    return apiFetch(`${API_BASE_URL}/api/hierarchy/${brandId}`, { cache: 'no-store' });
}
/**
 * Get all parts compatible with a specific Variant ID.
 * Used by: Device Explorer product grid.
 */
async function getPartsForVariant(variantId) {
    return apiFetch(`${API_BASE_URL}/api/inventory/variant/${variantId}`, { cache: 'no-store' });
}
/**
 * Fetch all categories with part counts.
 * Used by: Device Explorer filter chips, catalog page.
 */
async function fetchCategories() {
    try {
        const data = await apiFetch(`${API_BASE_URL}/api/categories`, { cache: 'no-store' });
        return data.categories || [];
    }
    catch (error) {
        console.error('[fetchCategories]', error);
        return [];
    }
}
/**
 * Fetch paginated inventory with optional filters.
 * Used by: catalog page, Device Explorer filtered views.
 */
async function fetchInventoryFiltered(params) {
    const query = new URLSearchParams();
    if (params?.category)
        query.set('category', params.category);
    if (params?.brand)
        query.set('brand', params.brand);
    if (params?.quality)
        query.set('quality', params.quality);
    if (params?.page)
        query.set('page', String(params.page));
    if (params?.limit)
        query.set('limit', String(params.limit));
    const url = `${API_BASE_URL}/api/inventory?${query.toString()}`;
    return apiFetch(url, { cache: 'no-store' });
}
/**
 * Sync the client-side Zustand cart to the server.
 * Call debounced (500ms) whenever the local cart changes.
 * Only call when user is authenticated.
 */
async function syncCart(userId, items) {
    return apiFetch(`${API_BASE_URL}/api/cart/sync`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, items }),
    });
}
/**
 * Validate cart items before checkout (MOQ + stock check).
 * Call before creating a Stripe session.
 */
async function validateCart(items) {
    return apiFetch(`${API_BASE_URL}/api/cart/validate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ items }),
    });
}
/**
 * Convert the server-side cart into an Order.
 * Call after validateCart() passes and Stripe payment succeeds.
 */
async function checkout(userId, shippingAddress) {
    return apiFetch(`${API_BASE_URL}/api/orders/checkout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, shippingAddress }),
    });
}
