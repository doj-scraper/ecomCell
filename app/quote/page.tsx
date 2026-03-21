import type { Metadata } from "next";
import { Navigation } from '@/components/navigation';
import { QuoteSection } from '@/components/quote-section';
import { FooterSection } from '@/components/footer-section';

export const metadata: Metadata = {
  title: "Request Quote | CellTech Distributor",
  description: "Get a custom quote for bulk orders of mobile phone parts. Competitive wholesale pricing.",
};

export default function QuotePage() {
  return (
    <div className="flex flex-col min-h-screen bg-ct-bg">
      <Navigation />
      <main className="flex-1 pt-16">
        <QuoteSection />
      </main>
      <FooterSection />
    </div>
  );
}
