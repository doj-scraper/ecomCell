import type { Metadata } from "next";
import { Navigation } from '@/components/navigation';
import { ProductsSection } from '@/components/products-section';
import { FooterSection } from '@/components/footer-section';

export const metadata: Metadata = {
  title: "Parts Catalog | CellTech Distributor",
  description: "Browse our extensive catalog of premium mobile phone parts - screens, batteries, cameras, and more.",
};

export default function CatalogPage() {
  return (
    <div className="flex flex-col min-h-screen bg-ct-bg">
      <Navigation />
      <main className="flex-1 pt-16">
        <ProductsSection />
      </main>
      <FooterSection />
    </div>
  );
}
