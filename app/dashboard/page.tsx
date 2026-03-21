import type { Metadata } from "next";
import { Navigation } from '@/components/navigation';
import { DashboardSection } from '@/components/dashboard-section';
import { FooterSection } from '@/components/footer-section';

export const metadata: Metadata = {
  title: "Dashboard | CellTech Distributor",
  description: "Manage your account, view orders, and track shipments.",
};

export default function DashboardPage() {
  return (
    <div className="flex flex-col min-h-screen bg-ct-bg">
      <Navigation />
      <main className="flex-1 pt-16">
        <DashboardSection />
      </main>
      <FooterSection />
    </div>
  );
}
