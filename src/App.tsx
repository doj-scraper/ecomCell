import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { Home } from '@/pages/Home';
import { CatalogPage } from '@/pages/CatalogPage';
import { QuotePage } from '@/pages/QuotePage';
import { SupportPage } from '@/pages/SupportPage';
import { DashboardPage } from '@/pages/DashboardPage';
import { NotFound } from '@/pages/NotFound';
import './App.css';

export default function App() {
  return (
    <ErrorBoundary>
      <Router>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/catalog" element={<CatalogPage />} />
          <Route path="/quote" element={<QuotePage />} />
          <Route path="/support" element={<SupportPage />} />
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </Router>
    </ErrorBoundary>
  );
}
