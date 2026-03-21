# CellTech Distributor — Agent Guidelines

Read this before making changes. Every rule exists for a reason.

---

## 1. Project Identity

**What this is:** A B2B wholesale mobile repair parts landing page. It's a marketing-focused single-page site for CellTech Distributor — a company selling OEM-grade phone components (screens, batteries, boards, cameras) to repair shops at wholesale prices.

**What this is NOT:**
- Not a full e-commerce app (no cart, checkout, orders, or auth yet)
- Not a Next.js project (it's Vite + React SPA)
- Not a consumer retail site — the aesthetic is dense, industrial, and catalog-first

---

## 2. Repository Layout

```
/home/mya/Desktop/Project/app/    ← Project root (package.json lives here)
├── index.html                     ← Vite entry HTML
├── package.json                   ← Dependencies and scripts
├── vite.config.ts                 ← Vite config with @/* path alias
├── tailwind.config.js             ← Tailwind theme + ct-* custom colors
├── postcss.config.js              ← PostCSS (tailwind + autoprefixer)
├── tsconfig.json                  ← TS project references
├── tsconfig.app.json              ← App TS config (strict, bundler mode)
├── tsconfig.node.json             ← Node TS config (for vite config)
├── eslint.config.js               ← ESLint flat config
├── components.json                ← shadcn/ui config
├── public/
│   └── images/                    ← Static images (16 JPGs)
├── src/
│   ├── main.tsx                   ← App entry point
│   ├── App.tsx                    ← ALL page components (1345 lines)
│   ├── App.css                    ← Reset + selection + scrollbar
│   ├── index.css                  ← Global styles, tokens, overlays, animations
│   ├── components/
│   │   └── ui/                    ← 53 shadcn/ui primitives (currently unused)
│   ├── hooks/
│   │   └── use-mobile.ts          ← Mobile breakpoint hook
│   └── lib/
│       └── utils.ts               ← cn() helper (clsx + tailwind-merge)
├── AGENTS.md                      ← This file
├── ARCHITECTURE.md                ← Architecture decisions
└── README.md                      ← Project overview
```

**The `@/*` path alias resolves to `src/*`.** All imports use `@/components/...`, `@/hooks/...`, `@/lib/...`.

---

## 3. Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | React 19.2 |
| Build tool | Vite 7.2.4 |
| Language | TypeScript 5.9.3 (strict mode) |
| Styling | Tailwind CSS 3.4.19 + CSS variables + custom utility classes |
| UI primitives | shadcn/ui (53 Radix-based components, new-york style) |
| Icons | lucide-react |
| Forms | react-hook-form + @hookform/resolvers (installed, not yet used) |
| Validation | zod (installed, not yet used) |
| Charts | recharts (installed, not yet used) |
| Fonts | Sora (headings), Inter (body), IBM Plex Mono (code/labels) |

---

## 4. Design System Tokens

### Colors

```css
/* Dark theme — all colors are hex values, not HSL */
--ct-bg:             #070A12          /* Page background */
--ct-bg-secondary:   #111725          /* Section backgrounds */
--ct-accent:         #00E5C0          /* Primary accent (cyan-green) */
--ct-text:           #F2F5FA          /* Primary text */
--ct-text-secondary: #A7B1C6          /* Muted text */
```

Tailwind config maps these to `ct-bg`, `ct-bg-secondary`, `ct-accent`, `ct-text`, `ct-text-secondary`.

### Fonts

```css
.font-display    → Sora (headings, uppercase, tight tracking)
.font-body       → Inter (body copy)
.font-mono       → IBM Plex Mono (SKUs, labels, micro text)
```

### Custom CSS Classes (src/index.css)

| Class | Purpose |
|-------|---------|
| `.btn-primary` | Accent-filled button (cyan, pill-shaped) |
| `.btn-secondary` | Ghost outline button |
| `.card-dark` | Glassmorphism card (translucent bg + border + blur) |
| `.input-dark` | Dark form input |
| `.product-card` | Product card with hover lift |
| `.filter-chip` | Filter toggle chip |
| `.testimonial-card` | Testimonial card |
| `.category-tile` | Category grid tile with hover scale |
| `.dashboard-card` | Dashboard preview card with deep shadow |
| `.heading-display` | Uppercase heading (Sora, 700, tight spacing) |
| `.text-micro` | Uppercase micro label (IBM Plex Mono, 12px) |
| `.nav-link` | Navigation link |
| `.link-arrow` | Link with arrow icon, gap animation on hover |
| `.badge` | Accent badge (cyan bg) |
| `.stat-card` | Metric stat card |
| `.grid-overlay` | Fixed 12-column grid lines |
| `.vignette-overlay` | Radial dark vignette |
| `.noise-overlay` | SVG noise texture |

### Animations

| Keyframe | Description |
|----------|-------------|
| `border-pulse` | Subtle opacity pulse on borders |
| `float` | Gentle Y-axis float (±6px) |
| `drift` | Larger Y-axis drift (±8px) |

### Z-Index Layers

| Value | Element |
|-------|---------|
| 1 | `.grid-overlay` |
| 2 | `.vignette-overlay` |
| 3 | `.noise-overlay` |
| 10 | Hero section |
| 20 | Categories section |
| 30 | Products section |
| 40 | Checkout section |
| 50 | Quote section |
| 60 | Quality section |
| 70 | Shipping section |
| 80 | Support section |
| 90 | Dashboard section |
| 100 | Testimonials section |
| 110 | Partners section |
| 120 | CTA section |
| 130 | Footer section |
| 50+ | Navigation (fixed, z-50) |

---

## 5. Component Conventions

### Current Pattern

All components are defined as **function declarations inside `App.tsx`**. Each section follows this pattern:

```tsx
function SectionName() {
  const sectionRef = useRef<HTMLElement>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          observer.disconnect();
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

### Section Types

- **`section-pinned`** — full viewport height (100vh), used for hero and feature sections
- **`section-flowing`** — auto-height with min-h-screen, used for grids and testimonials

### Scroll Animation Pattern

Elements animate in via conditional Tailwind classes:
```tsx
className={`element transition-all duration-700 ${
  isVisible ? 'opacity-100 translate-x-0' : 'opacity-0 -translate-x-12'
}`}
```

Transition delays stagger children: `style={{ transitionDelay: `${index * 50}ms` }}`

---

## 6. Styling Rules

1. **Use `ct-*` Tailwind colors** — never hardcode hex values in JSX. Use `bg-ct-bg`, `text-ct-accent`, etc.
2. **Custom CSS classes live in `src/index.css`** — not in component files. `src/App.css` is for global resets only.
3. **Use the `cn()` utility** from `@/lib/utils` when merging class names conditionally.
4. **Fonts are set via Tailwind classes** — `font-display`, `font-body`, `font-mono`. Don't set `font-family` in inline styles.
5. **Responsive breakpoints** — `sm:` (640px), `md:` (768px), `lg:` (1024px), `xl:` (1280px). Mobile-first.
6. **Animations use CSS keyframes** defined in `src/index.css`, referenced via Tailwind `animate-*` classes or custom CSS.
7. **Section spacing** — sections use `px-6 lg:px-12` for horizontal padding. Vertical spacing is handled by `min-h-screen` or `py-20 lg:py-32`.

---

## 7. What's Built vs Not

### Built

- **Landing page** with 13 sections: Navigation, Hero, Categories, Products, Checkout, Quote, Quality, Shipping, Support, Dashboard, Testimonials, Partners, CTA, Footer
- **Design system** — dark glassmorphism theme with accent cyan, grid overlay, vignette, noise
- **Scroll animations** — intersection observer-based fade/slide on all sections
- **Responsive layout** — mobile menu, grid adjustments at breakpoints
- **Static product data** — 8 hardcoded products with SKU, price, MOQ, stock status
- **16 static images** in `public/images/`

### Not Built

- **Routing** — no React Router or any client-side routing. It's a single scrollable page.
- **API integration** — no fetch calls, no API client, no data fetching
- **State management** — no context providers, no global state, no cart
- **Auth** — no login/register, no protected routes
- **Cart/Checkout** — buttons exist but don't function
- **Quote form** — form UI exists but doesn't submit
- **Tests** — no test files, no test framework configured
- **Component extraction** — everything lives in App.tsx, no separate component files

---

## 8. Rules for Agents

### Do

- Add new sections by following the existing pattern in App.tsx (function declaration, IntersectionObserver, section-pinned/flowing)
- Use shadcn/ui components when building interactive UI (forms, dialogs, tables). Import from `@/components/ui/...`
- Keep the dark theme — don't introduce light mode unless explicitly asked
- Use `ct-*` Tailwind colors for consistency
- Add new CSS classes to `src/index.css`, not inline

### Don't

- ❌ Don't rename or remove `ct-*` color tokens in `tailwind.config.js`
- ❌ Don't add `#070A12` or other hex values directly in JSX — use Tailwind classes
- ❌ Don't break the z-index layer system (grid:1, vignette:2, noise:3, sections:10-130)
- ❌ Don't add backend code (no API routes, no database, no server)
- ❌ Don't install routing unless asked (this is intentionally a single page)
- ❌ Don't create files outside `src/` except documentation
- ❌ Don't remove the scroll animation pattern from existing sections
- ❌ Don't use the shadcn/ui components without a reason — custom CSS classes are preferred for this project's style

---

## 9. Context Files for Future Sessions

When starting a new session, include these files for full context:

**Always:**
- `AGENTS.md` (this file)
- `src/App.tsx` (all components)
- `src/index.css` (all custom styles + tokens)

**For styling work:**
- `tailwind.config.js` (theme config)
- `src/App.css` (global resets)

**For component work:**
- `components.json` (shadcn/ui config)
- `src/components/ui/` (available primitives)

**For build/config work:**
- `vite.config.ts`
- `tsconfig.app.json`
- `package.json`
