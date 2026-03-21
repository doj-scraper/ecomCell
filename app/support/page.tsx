import type { Metadata } from "next";
import { Navigation } from '@/components/navigation';
import { SupportSection } from '@/components/support-section';
import { FooterSection } from '@/components/footer-section';

export const metadata: Metadata = {
  title: "Support | CellTech Distributor",
  description: "Get help with your orders, technical support, and answers to frequently asked questions.",
};

export default function SupportPage() {
  return (
    <div className="flex flex-col min-h-screen bg-ct-bg">
      <Navigation />
      <main className="flex-1 pt-16">
        <SupportSection />
      </main>
      <FooterSection />
    </div>
  );
}
