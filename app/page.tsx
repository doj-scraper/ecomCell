import { Navigation } from '@/components/navigation';
import { HeroSection } from '@/components/hero-section';
import { CategoriesSection } from '@/components/categories-section';
import { ProductsSection } from '@/components/products-section';
import { ProductSearchExample } from '@/components/product/product-search-example';
import { CheckoutSection } from '@/components/checkout-section';
import { QuoteSection } from '@/components/quote-section';
import { QualitySection } from '@/components/quality-section';
import { ShippingSection } from '@/components/shipping-section';
import { SupportSection } from '@/components/support-section';
import { DashboardSection } from '@/components/dashboard-section';
import { TestimonialsSection } from '@/components/testimonials-section';
import { PartnersSection } from '@/components/partners-section';
import { CTASection } from '@/components/cta-section';
import { FooterSection } from '@/components/footer-section';

export default function HomePage() {
  return (
    <div className="bg-ct-bg">
      <Navigation />
      <HeroSection />
      <CategoriesSection />
      <ProductsSection />
      <ProductSearchExample />
      <CheckoutSection />
      <QuoteSection />
      <QualitySection />
      <ShippingSection />
      <SupportSection />
      <DashboardSection />
      <TestimonialsSection />
      <PartnersSection />
      <CTASection />
      <FooterSection />
    </div>
  );
}
