"use client";

import { useEffect, useRef, useState } from 'react';
import { ArrowRight } from 'lucide-react';
import Link from 'next/link';

export function ProductsSection() {
  const sectionRef = useRef<HTMLElement>(null);
  const [isVisible, setIsVisible] = useState(false);
  const [activeFilter, setActiveFilter] = useState('All');
  const [products, setProducts] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          observer.disconnect();
        }
      },
      { threshold: 0.1 }
    );

    if (sectionRef.current) {
      observer.observe(sectionRef.current);
    }

    // Fetch real products from backend
    const loadProducts = async () => {
      try {
        setIsLoading(true);
        const response = await fetch('https://celltech-backend.vercel.app/api/parts?device=iPhone');
        const data = await response.json();
        if (data.success) {
          const mappedProducts = data.parts.map((p: any) => ({
            name: p.partName,
            sku: p.skuId,
            price: p.price ? `$${p.price.toFixed(2)}` : 'Contact for Price',
            moq: 1, // Default MOQ
            stock: p.stock > 0 ? 'In Stock' : 'Out of Stock',
            image: '/images/product_placeholder.jpg', // Placeholder since backend doesn't provide images
            category: p.category
          }));
          setProducts(mappedProducts);
        }
      } catch (error) {
        console.error('Failed to fetch products:', error);
      } finally {
        setIsLoading(false);
      }
    };

    loadProducts();

    return () => observer.disconnect();
  }, []);

  const filters = ['All', 'Display', 'Battery', 'Camera', 'Charging Port'];

  const filteredProducts = activeFilter === 'All' 
    ? products 
    : products.filter(p => p.category === activeFilter);

  return (
    <section ref={sectionRef} id="catalog" className="section-flowing py-20 lg:py-32" style={{ zIndex: 30 }}>
      <div className="w-full px-6 lg:px-12">
        {/* Header */}
        <div 
          className={`flex flex-col lg:flex-row lg:items-end lg:justify-between mb-12 transition-all duration-700 ${
            isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-6'
          }`}
        >
          <div>
            <h2 className="heading-display text-3xl sm:text-4xl lg:text-5xl text-ct-text mb-2">
              IN-DEMAND <span className="text-ct-accent">PARTS</span>
            </h2>
            <p className="text-ct-text-secondary text-sm lg:text-base">
              High-rotation components with clear MOQ and stock status.
            </p>
          </div>
          
          {/* Filter Chips */}
          <div className="flex flex-wrap gap-2 mt-6 lg:mt-0">
            {filters.map((filter) => (
              <button
                key={filter}
                onClick={() => setActiveFilter(filter)}
                className={`filter-chip ${activeFilter === filter ? 'active' : ''}`}
              >
                {filter}
              </button>
            ))}
          </div>
        </div>

        {/* Products Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 lg:gap-6">
          {filteredProducts.map((product, index) => (
            <div 
              key={product.sku}
              className={`product-card transition-all duration-500 ${
                isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'
              }`}
              style={{ transitionDelay: `${index * 50}ms` }}
            >
              <div className="aspect-square bg-ct-bg-secondary/50 p-4 flex items-center justify-center">
                <img 
                  src={product.image} 
                  alt={product.name}
                  className="w-full h-full object-contain"
                />
              </div>
              <div className="p-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="text-micro text-ct-text-secondary">{product.sku}</span>
                  <span className={`badge ${product.stock === 'Low Stock' ? 'text-amber-400 bg-amber-400/10' : ''}`}>
                    {product.stock}
                  </span>
                </div>
                <h3 className="text-ct-text font-medium text-sm mb-1">{product.name}</h3>
                <div className="flex items-center justify-between mb-3">
                  <span className="text-ct-accent font-semibold">{product.price}</span>
                  <span className="text-micro text-ct-text-secondary">MOQ: {product.moq}</span>
                </div>
                <button className="w-full py-2 rounded-lg text-sm font-medium transition-all duration-200 border border-ct-accent/30 text-ct-accent hover:bg-ct-accent/10">
                  Add to Quote
                </button>
              </div>
            </div>
          ))}
        </div>

        <div className="mt-12 text-center">
          <Link href="/inventory" className="link-arrow">
            View full catalog <ArrowRight className="w-4 h-4" />
          </Link>
        </div>
      </div>
    </section>
  );
}
