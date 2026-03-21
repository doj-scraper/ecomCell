import { RootLayout } from '@/components/RootLayout';
import { QuoteSection } from '@/components/quote-section';

export function QuotePage() {
  return (
    <RootLayout>
      <div className="pt-16">
        <QuoteSection />
      </div>
    </RootLayout>
  );
}
