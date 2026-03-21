# CellTech Distributor — Architecture

This document explains the architectural decisions, how the pieces fit together, and what limitations exist. It is meant to be comprehensive enough that a developer with no prior context can understand the system and continue building it without ambiguity.

---

## 1. High-Level Architecture

This is a **static single-page application (SPA)** — a client-side React app with no backend, no database, and no API integration. All data is hardcoded in component-level constants.

```
┌─────────────────────────────────────────────────┐
│                   Browser                         │
│                                                    │
│  React (19.2) → Vite (7.2.4) → Build output      │
│                                                    │
│  src/App.tsx        All components in one file     │
│  src/index.css      Design tokens + custom classes │
│  src/App.css        Global resets                  │
│  src/main.tsx       Entry point → React.createRoot │
│  public/images/     Static product images          │
└─────────────────────────────────────────────────────┘
```

There is no server runtime, no SSR, no API calls, and no data fetching. The app renders entirely on the client using hardcoded data arrays.

---

## 2. Why This Stack

### React 19 + Vite

- **React 19** for the latest concurrent features, though none are used yet
- **Vite** over Create React App for faster HMR, simpler config, and ES module support
- **No SSR** — this is a landing page; SEO is not a priority

### Tailwind CSS 3.4

- Utility-first CSS for rapid iteration
- Custom `ct-*` color tokens defined in `tailwind.config.js` map to CSS variables
- `tailwindcss-animate` plugin available (not yet used)

### shadcn/ui

- 53 Radix-based components installed via CLI
- Configured with `new-york` style, `slate` base color, CSS variables
- **Currently unused** — the project uses custom CSS classes instead
- Available for future interactive components (forms, dialogs, dropdowns)

### TypeScript (strict mode)

- `noUnusedLocals`, `noUnusedParameters` enabled
- `erasableSyntaxOnly` — no enums or namespace declarations
- `verbatimModuleSyntax` — requires `import type` for type-only imports
- Path alias `@/*` → `src/*`

---

## 3. Styling Architecture

The styling system has three layers, from broadest to most specific:

### Layer 1: CSS Variables (index.css)

```css
:root {
  --background: 220 35% 4%;
  --primary: 168 100% 45%;
  --accent: 168 100% 45%;
  /* ... */
}
```

These shadcn/ui-generated variables define the theme in HSL format. Tailwind maps them to `bg-background`, `text-foreground`, etc.

### Layer 2: Tailwind Config Colors (tailwind.config.js)

```js
colors: {
  'ct-bg': '#070A12',
  'ct-bg-secondary': '#111725',
  'ct-accent': '#00E5C0',
  'ct-text': '#F2F5FA',
  'ct-text-secondary': '#A7B1C6',
}
```

These CellTech-specific hex colors are used throughout the app via Tailwind classes like `bg-ct-bg`, `text-ct-accent`.

### Layer 3: Custom CSS Classes (index.css)

```css
.btn-primary { /* ... */ }
.product-card { /* ... */ }
.heading-display { /* ... */ }
```

Component-level styles that combine multiple properties (colors, spacing, transitions, shadows). These are the primary way components get styled — not inline Tailwind on every element.

### Layer 4: Component Styles (App.css)

Global resets, scrollbar customization, focus rings, selection colors. Minimal — most styling is in index.css.

---

## 4. Design Token System

### Colors

| Token | Hex | HSL | Usage |
|-------|-----|-----|-------|
| `#070A12` | 220° 35% 4% | Page background |
| `#111725` | 220° 25% 12% | Section/card backgrounds |
| `#00E5C0` | 168° 100% 45% | Accent (buttons, links, badges) |
| `#F2F5FA` | 220° 20% 97% | Primary text |
| `#A7B1C6` | 220° 15% 70% | Muted/secondary text |

### Typography

| Token | Font | Weight | Size | Tracking |
|-------|------|--------|------|----------|
| `.font-display` | Sora | 700 | Variable | 0.08em, uppercase |
| `.font-body` | Inter | 400-600 | 14-16px | Normal |
| `.font-mono` | IBM Plex Mono | 400-500 | 12px | 0.12em, uppercase |

### Animations

| Keyframe | Duration | Range | Notes |
|----------|----------|-------|-------|
| `border-pulse` | 3.5s | opacity 0.25–0.45 | Subtle border glow |
| `float` | 4s | translateY ±6px | Gentle hover |
| `drift` | 4.5s | translateY ±8px | Larger movement |

### Overlay Layers (Z-Index)

| z-index | Element | Purpose |
|---------|---------|---------|
| 1 | `.grid-overlay` | Subtle 12-column grid lines |
| 2 | `.vignette-overlay` | Radial darkening at edges |
| 3 | `.noise-overlay` | SVG noise texture |
| 10–130 | Sections | Content layers (10 per section) |
| 50 | Navigation | Fixed, always on top of content |

---

## 5. Component Patterns

### Section Structure

Every section is a React function component following this pattern:

```tsx
function SectionName() {
  const sectionRef = useRef<HTMLElement>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          observer.disconnect(); // fire once
        }
      },
      { threshold: 0.2 }
    );
    if (sectionRef.current) observer.observe(sectionRef.current);
    return () => observer.disconnect();
  }, []);

  return (
    <section ref={sectionRef} className="section-pinned flex items-center" style={{ zIndex: N }}>
      <div className="w-full px-6 lg:px-12">
        {/* Content */}
      </div>
    </section>
  );
}
```

### Scroll Animations

Elements animate in by toggling Tailwind classes:

```tsx
className={`element transition-all duration-700 ${
  isVisible ? 'opacity-100 translate-x-0' : 'opacity-0 -translate-x-12'
}`}
```

Staggered children use `style={{ transitionDelay: `${index * 50}ms` }}`.

### Navigation

- Fixed position, scrolls to section via `element.scrollIntoView({ behavior: 'smooth' })`
- Detects scroll position to toggle background blur
- Mobile menu uses `useState` toggle

---

## 6. Known Limitations

### Monolithic App.tsx

All 13+ components live in a single 1345-line file. This is manageable for a landing page but will become a bottleneck if the project grows.

### No Routing

The app is a single scrollable page. There is no client-side routing — no React Router, no Next.js, no equivalent. Adding routing would require installing a router library and restructuring the component tree.

### No State Management

All data is hardcoded in component-level arrays (`products`, `testimonials`, `partners`). There is no:
- Context providers
- State management library (Redux, Zustand, Jotai)
- Local storage persistence

### No API Layer

There are no `fetch()` calls, no API client, no data fetching. Everything is static. Adding an API layer would require building a typed client (possibly in `src/lib/api/`).

### No Tests

No test framework is configured. No test files exist. Testing would require installing Vitest (compatible with Vite) or similar.

### shadcn/ui Unused

53 shadcn/ui components are installed but none are imported in the app. The project uses custom CSS classes instead. If interactive UI is needed (forms, dialogs, tables), these components are available.

### zod and react-hook-form Unused

Both are installed but not imported anywhere. They're available for future form validation and API contract definitions.

---

## 7. Future Architecture

### If Routing Is Added

```
src/
├── pages/
│   ├── Home.tsx
│   ├── Catalog.tsx
│   ├── ProductDetail.tsx
│   ├── Cart.tsx
│   ├── Checkout.tsx
│   └── Account.tsx
├── App.tsx         ← Router provider
└── main.tsx        ← App wrapper
```

### If API Integration Is Added

```
src/
├── lib/
│   ├── api/
│   │   ├── client.ts      ← fetch wrapper
│   │   ├── products.ts    ← product API calls
│   │   └── cart.ts         ← cart API calls
│   ├── types.ts            ← API response types
│   └── utils.ts            ← existing cn() helper
```

### If State Management Is Added

```
src/
├── contexts/
│   ├── AuthContext.tsx     ← user state
│   └── CartContext.tsx     ← cart state
├── hooks/
│   ├── use-auth.ts
│   └── use-cart.ts
```

### If Components Are Extracted

```
src/
├── components/
│   ├── ui/                  ← shadcn/ui (existing)
│   ├── navigation.tsx       ← from App.tsx
│   ├── hero-section.tsx
│   ├── categories-section.tsx
│   ├── products-section.tsx
│   ├── checkout-section.tsx
│   ├── quote-section.tsx
│   ├── quality-section.tsx
│   ├── shipping-section.tsx
│   ├── support-section.tsx
│   ├── dashboard-section.tsx
│   ├── testimonials-section.tsx
│   ├── partners-section.tsx
│   ├── cta-section.tsx
│   └── footer-section.tsx
```
