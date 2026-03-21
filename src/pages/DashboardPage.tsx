import { RootLayout } from '@/components/RootLayout';
import { DashboardSection } from '@/components/dashboard-section';

export function DashboardPage() {
  return (
    <RootLayout>
      <div className="pt-16">
        <DashboardSection />
      </div>
    </RootLayout>
  );
}
