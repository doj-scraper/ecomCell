import { RootLayout } from '@/components/RootLayout';
import { SupportSection } from '@/components/support-section';

export function SupportPage() {
  return (
    <RootLayout>
      <div className="pt-16">
        <SupportSection />
      </div>
    </RootLayout>
  );
}
