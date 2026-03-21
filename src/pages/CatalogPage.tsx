import { RootLayout } from '@/components/RootLayout';
import { ProductsSection } from '@/components/products-section';

export function CatalogPage() {
  return (
    <RootLayout>
      <div className="pt-16">
        <ProductsSection />
      </div>
    </RootLayout>
  );
}
