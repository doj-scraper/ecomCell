"use strict";
// prisma/seed.ts
//
// BEFORE RUNNING: ensure bcrypt is installed
//   npm install bcrypt
//   npm install -D @types/bcrypt
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const client_1 = require("@prisma/client");
const bcrypt_1 = __importDefault(require("bcrypt"));
const prisma = new client_1.PrismaClient();
async function main() {
    console.log('--- RESETTING DATABASE ---');
    // Delete in strict dependency order (children before parents)
    await prisma.orderItem.deleteMany();
    await prisma.order.deleteMany();
    await prisma.cartItem.deleteMany();
    await prisma.cart.deleteMany();
    await prisma.compatibilityMap.deleteMany();
    await prisma.specification.deleteMany();
    await prisma.inventory.deleteMany();
    await prisma.variant.deleteMany();
    await prisma.generation.deleteMany();
    await prisma.modelType.deleteMany();
    await prisma.brand.deleteMany();
    await prisma.category.deleteMany();
    await prisma.verificationToken.deleteMany();
    await prisma.session.deleteMany();
    await prisma.account.deleteMany();
    await prisma.user.deleteMany();
    console.log('--- SEEDING SYSTEM DATA ---');
    // ── 1. CATEGORIES (The 4 Buckets) ─────────────────────────────
    const cat1 = await prisma.category.create({
        data: { name: 'Visual Interface', prefix: '1' },
    });
    const cat2 = await prisma.category.create({
        data: { name: 'Chassis & Enclosure', prefix: '2' },
    });
    const cat3 = await prisma.category.create({
        data: { name: 'Functional Modules', prefix: '3' },
    });
    const cat4 = await prisma.category.create({
        data: { name: 'Interconnects', prefix: '4' },
    });
    console.log('✅ Categories created');
    // ── 2. ADMIN USER ──────────────────────────────────────────────
    const hashedPassword = await bcrypt_1.default.hash('admin123', 10);
    await prisma.user.create({
        data: {
            email: 'admin@celltech.com',
            password: hashedPassword,
            name: 'System Admin',
            role: client_1.UserRole.ADMIN,
            company: 'CellTech Distributor',
        },
    });
    console.log('✅ Admin user created');
    // ── 3. BRANDS ──────────────────────────────────────────────────
    const apple = await prisma.brand.create({ data: { name: 'Apple' } });
    const samsung = await prisma.brand.create({ data: { name: 'Samsung' } });
    // ── 4. MODEL TYPES ─────────────────────────────────────────────
    const iphone = await prisma.modelType.create({ data: { brandId: apple.id, name: 'iPhone' } });
    const galaxyS = await prisma.modelType.create({ data: { brandId: samsung.id, name: 'Galaxy S' } });
    console.log('✅ Brands and model types created');
    // ── 5. GENERATIONS ─────────────────────────────────────────────
    const ip13Gen = await prisma.generation.create({
        data: { modelTypeId: iphone.id, name: '13', releaseYear: 2021 },
    });
    const ip14Gen = await prisma.generation.create({
        data: { modelTypeId: iphone.id, name: '14', releaseYear: 2022 },
    });
    const s24Gen = await prisma.generation.create({
        data: { modelTypeId: galaxyS.id, name: '24', releaseYear: 2024 },
    });
    // ── 6. VARIANTS ────────────────────────────────────────────────
    // iPhone 13 family
    const ip13Base = await prisma.variant.create({
        data: { generationId: ip13Gen.id, name: 'Base', modelNumber: 'A2631' },
    });
    const ip13Pro = await prisma.variant.create({
        data: { generationId: ip13Gen.id, name: 'Pro', modelNumber: 'A2636' },
    });
    const ip13ProM = await prisma.variant.create({
        data: { generationId: ip13Gen.id, name: 'Pro Max', modelNumber: 'A2643' },
    });
    // iPhone 14 family
    const ip14Base = await prisma.variant.create({
        data: { generationId: ip14Gen.id, name: 'Base', modelNumber: 'A2649' },
    });
    const ip14Pro = await prisma.variant.create({
        data: { generationId: ip14Gen.id, name: 'Pro', modelNumber: 'A2650' },
    });
    // Samsung Galaxy S24
    const s24Ultra = await prisma.variant.create({
        data: { generationId: s24Gen.id, name: 'Ultra', modelNumber: 'SM-S928U' },
    });
    console.log('✅ Device hierarchy created (6 variants across 3 generations)');
    // ── 7. INVENTORY PARTS ─────────────────────────────────────────
    console.log('--- SEEDING INVENTORY ---');
    // ── 7a. Direct part: iPhone 13 Battery (maps to one variant) ──
    const ip13Battery = await prisma.inventory.create({
        data: {
            skuId: '3-C-O-IP13',
            categoryId: cat3.id,
            partName: 'iPhone 13 Replacement Battery',
            qualityGrade: client_1.QualityGrade.OEM,
            wholesalePrice: 1450, // $14.50
            stockLevel: 100,
        },
    });
    await prisma.specification.createMany({
        data: [
            { skuId: ip13Battery.skuId, label: 'Capacity', value: '3227 mAh' },
            { skuId: ip13Battery.skuId, label: 'Chemistry', value: 'Lithium-Ion' },
            { skuId: ip13Battery.skuId, label: 'Adhesive Included', value: 'Yes' },
            { skuId: ip13Battery.skuId, label: 'Cycle Life', value: '500+ cycles' },
        ],
    });
    await prisma.compatibilityMap.create({
        data: { skuId: ip13Battery.skuId, variantId: ip13Base.id },
    });
    // ── 7b. Direct part: Samsung S24 Ultra OLED (maps to one variant) ──
    const s24Screen = await prisma.inventory.create({
        data: {
            skuId: '1-B-P-S24U',
            categoryId: cat1.id,
            partName: 'Galaxy S24 Ultra OLED Screen Assembly',
            qualityGrade: client_1.QualityGrade.Premium,
            wholesalePrice: 22500, // $225.00
            stockLevel: 15,
        },
    });
    await prisma.specification.createMany({
        data: [
            { skuId: s24Screen.skuId, label: 'Panel Type', value: 'Dynamic AMOLED 2X' },
            { skuId: s24Screen.skuId, label: 'Resolution', value: '3088 x 1440' },
            { skuId: s24Screen.skuId, label: 'Refresh Rate', value: '120Hz' },
            { skuId: s24Screen.skuId, label: 'Size', value: '6.8"' },
        ],
    });
    await prisma.compatibilityMap.create({
        data: { skuId: s24Screen.skuId, variantId: s24Ultra.id },
    });
    // ── 7c. CROSS-COMPATIBLE PART (validates the whole system) ─────
    //
    // This Lightning dock flex cable fits iPhone 13 Base, Pro, Pro Max
    // AND iPhone 14 Base, Pro — demonstrating one SKU → many variants
    // via CompatibilityMap. This is the core value prop of the schema.
    const lightningFlex = await prisma.inventory.create({
        data: {
            skuId: '4-A-O-IP13-14',
            categoryId: cat4.id,
            partName: 'Lightning Dock Flex Cable — iPhone 13/14 Series',
            qualityGrade: client_1.QualityGrade.OEM,
            wholesalePrice: 850, // $8.50
            stockLevel: 420,
        },
    });
    await prisma.specification.createMany({
        data: [
            { skuId: lightningFlex.skuId, label: 'Connector Type', value: 'Lightning' },
            { skuId: lightningFlex.skuId, label: 'Cable Length', value: '18cm' },
            { skuId: lightningFlex.skuId, label: 'Microphone', value: 'Included' },
            { skuId: lightningFlex.skuId, label: 'Cross-Compatible', value: 'Yes' },
        ],
    });
    // Five rows in CompatibilityMap — one SKU, five variants
    await prisma.compatibilityMap.createMany({
        data: [
            { skuId: lightningFlex.skuId, variantId: ip13Base.id },
            { skuId: lightningFlex.skuId, variantId: ip13Pro.id },
            { skuId: lightningFlex.skuId, variantId: ip13ProM.id },
            { skuId: lightningFlex.skuId, variantId: ip14Base.id },
            { skuId: lightningFlex.skuId, variantId: ip14Pro.id },
        ],
    });
    // ── 7d. Direct part: iPhone 14 Pro OLED ──
    const ip14ProScreen = await prisma.inventory.create({
        data: {
            skuId: '1-B-P-IP14P',
            categoryId: cat1.id,
            partName: 'iPhone 14 Pro Super Retina XDR OLED Assembly',
            qualityGrade: client_1.QualityGrade.Premium,
            wholesalePrice: 18500, // $185.00
            stockLevel: 30,
        },
    });
    await prisma.specification.createMany({
        data: [
            { skuId: ip14ProScreen.skuId, label: 'Panel Type', value: 'Super Retina XDR OLED' },
            { skuId: ip14ProScreen.skuId, label: 'Resolution', value: '2556 x 1179' },
            { skuId: ip14ProScreen.skuId, label: 'Refresh Rate', value: '120Hz ProMotion' },
            { skuId: ip14ProScreen.skuId, label: 'Size', value: '6.1"' },
        ],
    });
    await prisma.compatibilityMap.create({
        data: { skuId: ip14ProScreen.skuId, variantId: ip14Pro.id },
    });
    console.log('✅ Inventory created:');
    console.log('   - 3-C-O-IP13   : iPhone 13 Battery (1 variant)');
    console.log('   - 1-B-P-S24U   : Galaxy S24 Ultra OLED (1 variant)');
    console.log('   - 4-A-O-IP13-14: Lightning Flex Cable (5 variants — cross-compatible)');
    console.log('   - 1-B-P-IP14P  : iPhone 14 Pro OLED (1 variant)');
    console.log(`
╔══════════════════════════════════════════╗
║   ✅ Seeding Complete                    ║
║                                          ║
║   Categories:           4                ║
║   Brands:               2                ║
║   Model Types:          2                ║
║   Generations:          3                ║
║   Variants:             6                ║
║   Inventory Parts:      4                ║
║   Compatibility Rows:   8                ║
║   Specification Rows:  16                ║
║   Admin User:           1                ║
╚══════════════════════════════════════════╝
  `);
}
main()
    .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
})
    .finally(async () => {
    await prisma.$disconnect();
});
