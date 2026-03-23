"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
// src/server.ts
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const client_1 = require("@prisma/client");
const path_1 = __importDefault(require("path"));
require('dotenv').config();
const app = (0, express_1.default)();
const prisma = new client_1.PrismaClient();
// ─── MIDDLEWARE ───────────────────────────────────────
app.use((0, cors_1.default)({
    origin: (process.env.CORS_ORIGIN || 'http://localhost:3000').split(','),
    credentials: true,
}));
app.use(express_1.default.json());
app.use(express_1.default.static('public'));
// ─── HEALTH ───────────────────────────────────────────
/**
 * GET /api/health
 */
app.get('/api/health', (_req, res) => {
    res.json({
        success: true,
        message: 'CellTech Backend is running',
        timestamp: new Date().toISOString(),
    });
});
// ─── DEVICE HIERARCHY ────────────────────────────────
/**
 * GET /api/brands
 * Entry point for the Device Explorer. Returns all brands with their model types.
 */
app.get('/api/brands', async (_req, res, next) => {
    try {
        const brands = await prisma.brand.findMany({
            orderBy: { name: 'asc' },
            include: { modelTypes: true },
        });
        res.json({ success: true, count: brands.length, brands });
    }
    catch (error) {
        next(error);
    }
});
/**
 * GET /api/hierarchy/:brandId
 * Walks the full tree: ModelType → Generation → Variant for one brand.
 * Powers the drill-down navigation in the Device Explorer.
 */
app.get('/api/hierarchy/:brandId', async (req, res, next) => {
    try {
        const brandId = parseInt(req.params.brandId);
        if (isNaN(brandId)) {
            return res.status(400).json({ success: false, error: 'brandId must be a number' });
        }
        const brand = await prisma.brand.findUnique({ where: { id: brandId } });
        if (!brand) {
            return res.status(404).json({ success: false, error: `Brand ${brandId} not found` });
        }
        const hierarchy = await prisma.modelType.findMany({
            where: { brandId },
            orderBy: { name: 'asc' },
            include: {
                generations: {
                    orderBy: { releaseYear: 'desc' },
                    include: {
                        variants: { orderBy: { name: 'asc' } },
                    },
                },
            },
        });
        res.json({ success: true, brand, hierarchy });
    }
    catch (error) {
        next(error);
    }
});
/**
 * GET /api/models
 * Backward-compatible: returns Variants shaped like the old Model response.
 * Keeps existing fetchModels() calls in the frontend working during migration.
 * Optional ?brandId= filter.
 */
app.get('/api/models', async (req, res, next) => {
    try {
        const { brandId } = req.query;
        const where = brandId
            ? { generation: { modelType: { brandId: parseInt(brandId) } } }
            : {};
        const variants = await prisma.variant.findMany({
            where,
            orderBy: { modelNumber: 'asc' },
            include: {
                generation: {
                    include: { modelType: { include: { brand: true } } },
                },
            },
        });
        const models = variants.map((v) => ({
            id: v.id,
            modelNumber: v.modelNumber,
            marketingName: `${v.generation.modelType.name} ${v.generation.name} ${v.name}`.trim(),
            releaseYear: v.generation.releaseYear,
            brandId: v.generation.modelType.brandId,
            brand: v.generation.modelType.brand,
        }));
        res.json({ success: true, count: models.length, models });
    }
    catch (error) {
        next(error);
    }
});
/**
 * GET /api/categories
 * Returns all 4 buckets with their part counts.
 */
app.get('/api/categories', async (_req, res, next) => {
    try {
        const categories = await prisma.category.findMany({
            orderBy: { prefix: 'asc' },
            include: { _count: { select: { inventory: true } } },
        });
        res.json({
            success: true,
            count: categories.length,
            categories: categories.map((c) => ({
                id: c.id,
                name: c.name,
                prefix: c.prefix,
                partCount: c._count.inventory,
            })),
        });
    }
    catch (error) {
        next(error);
    }
});
// ─── INVENTORY ───────────────────────────────────────
//
// ROUTE ORDER IS CRITICAL. Express matches top-to-bottom.
// /inventory/variant/:id and /inventory/model/:id MUST come
// before /inventory/:skuId — otherwise "variant" and "model"
// get captured as the :skuId param value.
/**
 * GET /api/inventory/variant/:variantId
 * All parts compatible with a specific device variant.
 * Primary lookup for the Device Explorer product grid.
 */
app.get('/api/inventory/variant/:variantId', async (req, res, next) => {
    try {
        const variantId = parseInt(req.params.variantId);
        if (isNaN(variantId)) {
            return res.status(400).json({ success: false, error: 'variantId must be a number' });
        }
        const variant = await prisma.variant.findUnique({
            where: { id: variantId },
            include: {
                generation: {
                    include: { modelType: { include: { brand: true } } },
                },
            },
        });
        if (!variant) {
            return res.status(404).json({ success: false, error: `Variant ${variantId} not found` });
        }
        const parts = await prisma.inventory.findMany({
            where: { compatibilities: { some: { variantId } } },
            include: {
                category: true,
                specifications: { orderBy: { label: 'asc' } },
            },
            orderBy: { skuId: 'asc' },
        });
        res.json({
            success: true,
            variant: {
                id: variant.id,
                name: variant.name,
                modelNumber: variant.modelNumber,
                generation: variant.generation.name,
                modelType: variant.generation.modelType.name,
                brand: variant.generation.modelType.brand.name,
                releaseYear: variant.generation.releaseYear,
            },
            count: parts.length,
            parts: parts.map((p) => ({
                skuId: p.skuId,
                partName: p.partName,
                category: p.category.name,
                categoryPrefix: p.category.prefix,
                quality: p.qualityGrade,
                price: p.wholesalePrice / 100,
                stock: p.stockLevel,
                specifications: p.specifications.map((s) => ({ label: s.label, value: s.value })),
            })),
        });
    }
    catch (error) {
        next(error);
    }
});
/**
 * GET /api/inventory/model/:modelId
 * Backward-compatible alias for /api/inventory/variant/:variantId.
 * modelId is treated as variantId — same concept, renamed.
 */
app.get('/api/inventory/model/:modelId', async (req, res, next) => {
    try {
        const variantId = parseInt(req.params.modelId);
        if (isNaN(variantId)) {
            return res.status(400).json({ success: false, error: 'modelId must be a number' });
        }
        const variant = await prisma.variant.findUnique({
            where: { id: variantId },
            include: {
                generation: {
                    include: { modelType: { include: { brand: true } } },
                },
            },
        });
        if (!variant) {
            return res.status(404).json({ success: false, error: `Variant ${variantId} not found` });
        }
        const parts = await prisma.inventory.findMany({
            where: { compatibilities: { some: { variantId } } },
            include: { category: true, specifications: true },
            orderBy: { skuId: 'asc' },
        });
        res.json({
            success: true,
            model: {
                id: variant.id,
                modelNumber: variant.modelNumber,
                marketingName: `${variant.generation.modelType.name} ${variant.generation.name} ${variant.name}`.trim(),
                brandName: variant.generation.modelType.brand.name,
                releaseYear: variant.generation.releaseYear,
            },
            count: parts.length,
            parts: parts.map((p) => ({
                skuId: p.skuId,
                partName: p.partName,
                category: p.category.name,
                quality: p.qualityGrade,
                price: p.wholesalePrice / 100,
                stock: p.stockLevel,
                specifications: p.specifications.map((s) => ({ label: s.label, value: s.value })),
            })),
        });
    }
    catch (error) {
        next(error);
    }
});
/**
 * GET /api/inventory
 * Browse all inventory. Supports optional filters and pagination.
 *
 * Query params:
 *   ?category=Functional Modules
 *   ?brand=Apple
 *   ?quality=OEM | Premium | Aftermarket | U | NA
 *   ?page=1&limit=20
 */
app.get('/api/inventory', async (req, res, next) => {
    try {
        const { category, brand, quality, page = '1', limit = '20' } = req.query;
        const pageNum = Math.max(1, parseInt(page) || 1);
        const limitNum = Math.min(100, Math.max(1, parseInt(limit) || 20));
        const skip = (pageNum - 1) * limitNum;
        const where = {};
        if (category && typeof category === 'string') {
            where.category = { name: { equals: category, mode: 'insensitive' } };
        }
        if (brand && typeof brand === 'string') {
            where.compatibilities = {
                some: {
                    variant: {
                        generation: {
                            modelType: {
                                brand: { name: { contains: brand, mode: 'insensitive' } },
                            },
                        },
                    },
                },
            };
        }
        if (quality && typeof quality === 'string') {
            const validGrades = Object.values(client_1.QualityGrade);
            const matched = validGrades.find((g) => g.toLowerCase() === quality.toLowerCase());
            if (matched)
                where.qualityGrade = matched;
        }
        const [total, parts] = await Promise.all([
            prisma.inventory.count({ where }),
            prisma.inventory.findMany({
                where,
                include: {
                    category: true,
                    specifications: { orderBy: { label: 'asc' } },
                    compatibilities: {
                        include: {
                            variant: {
                                include: {
                                    generation: {
                                        include: { modelType: { include: { brand: true } } },
                                    },
                                },
                            },
                        },
                    },
                },
                orderBy: { skuId: 'asc' },
                skip,
                take: limitNum,
            }),
        ]);
        res.json({
            success: true,
            pagination: {
                total,
                page: pageNum,
                limit: limitNum,
                totalPages: Math.ceil(total / limitNum),
            },
            inventory: parts.map((p) => ({
                skuId: p.skuId,
                partName: p.partName,
                category: p.category.name,
                quality: p.qualityGrade,
                price: p.wholesalePrice / 100,
                stock: p.stockLevel,
                specifications: p.specifications.map((s) => ({ label: s.label, value: s.value })),
                compatibleWith: p.compatibilities.map((c) => ({
                    variantId: c.variant.id,
                    modelNumber: c.variant.modelNumber,
                    marketingName: `${c.variant.generation.modelType.name} ${c.variant.generation.name} ${c.variant.name}`.trim(),
                    brand: c.variant.generation.modelType.brand.name,
                })),
            })),
        });
    }
    catch (error) {
        next(error);
    }
});
/**
 * GET /api/inventory/:skuId
 * Full part detail with specs, primary model string, and complete compatibility list.
 * Used by the product detail page.
 *
 * NOTE: Must stay AFTER all /inventory/[word]/... routes.
 */
app.get('/api/inventory/:skuId', async (req, res, next) => {
    try {
        const { skuId } = req.params;
        const part = await prisma.inventory.findUnique({
            where: { skuId },
            include: {
                category: true,
                specifications: { orderBy: { label: 'asc' } },
                compatibilities: {
                    include: {
                        variant: {
                            include: {
                                generation: {
                                    include: { modelType: { include: { brand: true } } },
                                },
                            },
                        },
                    },
                },
            },
        });
        if (!part) {
            return res.status(404).json({ success: false, error: `Part ${skuId} not found` });
        }
        const firstVariant = part.compatibilities[0]?.variant;
        const primaryModel = firstVariant
            ? `${firstVariant.generation.modelType.brand.name} ${firstVariant.generation.modelType.name} ${firstVariant.generation.name} ${firstVariant.name}`.trim()
            : null;
        res.json({
            success: true,
            part: {
                skuId: part.skuId,
                partName: part.partName,
                category: part.category.name,
                quality: part.qualityGrade,
                price: part.wholesalePrice / 100,
                stock: part.stockLevel,
                primaryModel,
                specifications: part.specifications.map((s) => ({ label: s.label, value: s.value })),
                compatibleModels: part.compatibilities.map((c) => ({
                    id: c.variant.id,
                    modelNumber: c.variant.modelNumber,
                    marketingName: `${c.variant.generation.modelType.name} ${c.variant.generation.name} ${c.variant.name}`.trim(),
                    brand: c.variant.generation.modelType.brand.name,
                    releaseYear: c.variant.generation.releaseYear,
                })),
            },
        });
    }
    catch (error) {
        next(error);
    }
});
// ─── SEARCH ───────────────────────────────────────────
/**
 * GET /api/parts?device=iPhone 13
 * Full-text search across variant names, model numbers, and generation names.
 * Backward-compatible — used by ProductsSection and search components.
 */
app.get('/api/parts', async (req, res, next) => {
    try {
        const { device } = req.query;
        if (!device || typeof device !== 'string') {
            return res.status(400).json({ success: false, error: 'device query param is required' });
        }
        const parts = await prisma.inventory.findMany({
            where: {
                compatibilities: {
                    some: {
                        variant: {
                            OR: [
                                { modelNumber: { contains: device, mode: 'insensitive' } },
                                { name: { contains: device, mode: 'insensitive' } },
                                { generation: { name: { contains: device, mode: 'insensitive' } } },
                                { generation: { modelType: { name: { contains: device, mode: 'insensitive' } } } },
                            ],
                        },
                    },
                },
            },
            include: {
                category: true,
                compatibilities: {
                    take: 1,
                    include: {
                        variant: {
                            include: {
                                generation: { include: { modelType: true } },
                            },
                        },
                    },
                },
            },
            orderBy: { skuId: 'asc' },
        });
        res.json({
            success: true,
            device,
            count: parts.length,
            parts: parts.map((p) => {
                const v = p.compatibilities[0]?.variant;
                return {
                    skuId: p.skuId,
                    partName: p.partName,
                    category: p.category.name,
                    quality: p.qualityGrade,
                    price: p.wholesalePrice / 100,
                    stock: p.stockLevel,
                    modelName: v
                        ? `${v.generation.modelType.name} ${v.generation.name} ${v.name}`.trim()
                        : 'Universal / Cross-Compatible',
                };
            }),
        });
    }
    catch (error) {
        next(error);
    }
});
/**
 * GET /api/compatibility/:skuId
 * Returns the full compatibility list for a SKU.
 * Backward-compatible with existing getCompatibility() calls.
 */
app.get('/api/compatibility/:skuId', async (req, res, next) => {
    try {
        const { skuId } = req.params;
        const part = await prisma.inventory.findUnique({
            where: { skuId },
            include: {
                compatibilities: {
                    include: {
                        variant: {
                            include: {
                                generation: {
                                    include: { modelType: { include: { brand: true } } },
                                },
                            },
                        },
                    },
                },
            },
        });
        if (!part) {
            return res.status(404).json({ success: false, error: `SKU ${skuId} not found` });
        }
        res.json({
            success: true,
            skuId,
            compatibleModels: part.compatibilities.map((c) => ({
                id: c.variant.id,
                modelNumber: c.variant.modelNumber,
                marketingName: `${c.variant.generation.modelType.name} ${c.variant.generation.name} ${c.variant.name}`.trim(),
                brand: c.variant.generation.modelType.brand.name,
                releaseYear: c.variant.generation.releaseYear,
            })),
        });
    }
    catch (error) {
        next(error);
    }
});
// ─── CART ─────────────────────────────────────────────
/**
 * POST /api/cart/validate
 * Pre-checkout MOQ + stock validation per line item.
 * Call this before creating a Stripe session.
 *
 * Body: { items: [{ skuId: string, quantity: number }] }
 */
app.post('/api/cart/validate', async (req, res, next) => {
    try {
        const { items } = req.body;
        if (!items || !Array.isArray(items) || items.length === 0) {
            return res.status(400).json({
                success: false,
                error: 'items array is required and must not be empty',
            });
        }
        const MOQ = 5;
        const skuIds = items.map((i) => i.skuId);
        const parts = await prisma.inventory.findMany({ where: { skuId: { in: skuIds } } });
        const partMap = new Map(parts.map((p) => [p.skuId, p]));
        const results = items.map((item) => {
            const errors = [];
            const part = partMap.get(item.skuId);
            if (!part) {
                return { skuId: item.skuId, quantity: item.quantity, valid: false, errors: [`SKU ${item.skuId} not found`] };
            }
            if (item.quantity < MOQ) {
                errors.push(`Minimum order quantity is ${MOQ} (requested ${item.quantity})`);
            }
            if (item.quantity > part.stockLevel) {
                errors.push(`Only ${part.stockLevel} in stock (requested ${item.quantity})`);
            }
            const price = part.wholesalePrice / 100;
            return {
                skuId: item.skuId,
                quantity: item.quantity,
                valid: errors.length === 0,
                errors,
                part: {
                    partName: part.partName,
                    price,
                    stock: part.stockLevel,
                    subtotal: parseFloat((price * item.quantity).toFixed(2)),
                },
            };
        });
        const orderTotal = parseFloat(results.reduce((sum, r) => sum + (r.part?.subtotal ?? 0), 0).toFixed(2));
        res.json({
            success: true,
            valid: results.every((r) => r.valid),
            orderTotal,
            items: results,
        });
    }
    catch (error) {
        next(error);
    }
});
/**
 * POST /api/cart/sync
 * Persists the Zustand client cart to the database.
 * Uses clear-and-rebuild — safe and simple at B2B cart sizes.
 * Call this debounced whenever the local cart changes.
 *
 * Body: { userId: string, items: [{ skuId: string, quantity: number }] }
 */
app.post('/api/cart/sync', async (req, res, next) => {
    try {
        const { userId, items } = req.body;
        if (!userId) {
            return res.status(400).json({ success: false, error: 'userId is required' });
        }
        if (!items || !Array.isArray(items)) {
            return res.status(400).json({ success: false, error: 'items array is required' });
        }
        const cart = await prisma.cart.upsert({
            where: { userId },
            create: { userId },
            update: {},
        });
        await prisma.cartItem.deleteMany({ where: { cartId: cart.id } });
        if (items.length > 0) {
            await prisma.cartItem.createMany({
                data: items.map((item) => ({
                    cartId: cart.id,
                    skuId: item.skuId,
                    quantity: item.quantity,
                })),
            });
        }
        res.json({
            success: true,
            message: 'Cart synced',
            cartId: cart.id,
            itemCount: items.length,
        });
    }
    catch (error) {
        next(error);
    }
});
// ─── ORDERS ───────────────────────────────────────────
/**
 * POST /api/orders/checkout
 * Converts server cart → Order. Snapshots prices. Clears cart on success.
 *
 * Body: { userId: string, shippingAddress: object }
 */
app.post('/api/orders/checkout', async (req, res, next) => {
    try {
        const { userId, shippingAddress } = req.body;
        if (!userId)
            return res.status(400).json({ success: false, error: 'userId is required' });
        if (!shippingAddress)
            return res.status(400).json({ success: false, error: 'shippingAddress is required' });
        const userCart = await prisma.cart.findUnique({
            where: { userId },
            include: { items: { include: { inventory: true } } },
        });
        if (!userCart || userCart.items.length === 0) {
            return res.status(400).json({ success: false, error: 'Cart is empty' });
        }
        // Stock check before committing
        const stockErrors = [];
        for (const item of userCart.items) {
            if (item.quantity > item.inventory.stockLevel) {
                stockErrors.push(`${item.skuId}: only ${item.inventory.stockLevel} in stock (requested ${item.quantity})`);
            }
        }
        if (stockErrors.length > 0) {
            return res.status(409).json({
                success: false,
                error: 'Stock validation failed',
                details: stockErrors,
            });
        }
        const order = await prisma.order.create({
            data: {
                userId,
                shippingAddress,
                status: 'PENDING',
                items: {
                    create: userCart.items.map((item) => ({
                        skuId: item.skuId,
                        quantity: item.quantity,
                        unitPriceAtPurchase: item.inventory.wholesalePrice, // cents — snapshot
                    })),
                },
            },
            include: { items: true },
        });
        // Clear cart after successful order
        await prisma.cartItem.deleteMany({ where: { cartId: userCart.id } });
        res.json({
            success: true,
            order: {
                id: order.id,
                status: order.status,
                itemCount: order.items.length,
                orderTotal: order.items.reduce((sum, i) => sum + (i.unitPriceAtPurchase / 100) * i.quantity, 0),
                createdAt: order.createdAt,
            },
        });
    }
    catch (error) {
        next(error);
    }
});
// ─── STATIC ───────────────────────────────────────────
app.get('/', (_req, res) => {
    res.sendFile(path_1.default.join(__dirname, '../public/index.html'));
});
process.on('SIGINT', async () => {
    await prisma.$disconnect();
    process.exit(0);
});
// eslint-disable-next-line @typescript-eslint/no-unused-vars
app.use((err, _req, res, _next) => {
    console.error('[Error]', err.message);
    res.status(err.statusCode || 500).json({
        success: false,
        error: err.message || 'Internal server error',
    });
});
// ─── START ────────────────────────────────────────────
const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
    console.log(`
╔══════════════════════════════════════╗
║   🚀 CellTech Backend Server         ║
║   http://localhost:${PORT}                ║
╚══════════════════════════════════════╝
  `);
});
exports.default = app;
