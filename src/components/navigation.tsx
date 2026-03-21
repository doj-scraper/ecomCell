import { useEffect, useState } from 'react';
import { ShoppingCart, User, Menu, X } from 'lucide-react';

export function Navigation() {
  const [isScrolled, setIsScrolled] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 100);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const scrollToSection = (id: string) => {
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
      setIsMobileMenuOpen(false);
    }
  };

  return (
    <nav className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
      isScrolled ? 'bg-ct-bg/90 backdrop-blur-md border-b border-white/5' : 'bg-transparent'
    }`}>
      <div className="w-full px-6 lg:px-12">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-ct-accent flex items-center justify-center">
              <span className="text-ct-bg font-bold text-sm">CT</span>
            </div>
            <span className="font-display font-bold text-ct-text tracking-wide">CellTech</span>
          </div>

          {/* Desktop Navigation */}
          <div className="hidden md:flex items-center gap-8">
            <button onClick={() => scrollToSection('catalog')} className="nav-link">Catalog</button>
            <button onClick={() => scrollToSection('quote')} className="nav-link">Quote</button>
            <button onClick={() => scrollToSection('support')} className="nav-link">Support</button>
            <button onClick={() => scrollToSection('dashboard')} className="nav-link">Account</button>
          </div>

          {/* Actions */}
          <div className="hidden md:flex items-center gap-4">
            <button className="flex items-center gap-2 text-sm text-ct-text-secondary hover:text-ct-text transition-colors">
              <ShoppingCart className="w-4 h-4" />
              <span className="font-mono text-xs">(0)</span>
            </button>
            <button className="flex items-center gap-2 text-sm text-ct-text-secondary hover:text-ct-text transition-colors">
              <User className="w-4 h-4" />
              <span>Login</span>
            </button>
          </div>

          {/* Mobile Menu Button */}
          <button 
            className="md:hidden text-ct-text"
            onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
          >
            {isMobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </button>
        </div>
      </div>

      {/* Mobile Menu */}
      {isMobileMenuOpen && (
        <div className="md:hidden bg-ct-bg/95 backdrop-blur-md border-t border-white/5">
          <div className="px-6 py-4 space-y-4">
            <button onClick={() => scrollToSection('catalog')} className="block w-full text-left nav-link py-2">Catalog</button>
            <button onClick={() => scrollToSection('quote')} className="block w-full text-left nav-link py-2">Quote</button>
            <button onClick={() => scrollToSection('support')} className="block w-full text-left nav-link py-2">Support</button>
            <button onClick={() => scrollToSection('dashboard')} className="block w-full text-left nav-link py-2">Account</button>
            <div className="pt-4 border-t border-white/10 flex items-center gap-6">
              <button className="flex items-center gap-2 text-sm text-ct-text-secondary">
                <ShoppingCart className="w-4 h-4" />
                <span>Cart (0)</span>
              </button>
              <button className="flex items-center gap-2 text-sm text-ct-text-secondary">
                <User className="w-4 h-4" />
                <span>Login</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </nav>
  );
}
