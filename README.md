# CellTech Distributor

B2B wholesale mobile repair parts landing page. A catalog-first, dark-themed marketing site for CellTech Distributor — selling OEM-grade phone components (screens, batteries, boards, cameras) to repair shops at wholesale prices.

---

## Quick Start

```bash
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173).

---

## Project Structure

```
app/
├── index.html                  ← Vite entry
├── package.json                ← Dependencies & scripts
├── vite.config.ts              ← Vite config (@/* path alias)
├── tailwind.config.js          ← Tailwind theme + ct-* colors
├── tsconfig.app.json           ← TypeScript (strict, bundler mode)
├── eslint.config.js            ← ESLint flat config
├── components.json             ← shadcn/ui config
├── public/
│   └── images/                 ← 16 static product/category images
├── src/
│   ├── main.tsx                ← App entry point
│   ├── App.tsx                 ← All page sections (1345 lines)
│   ├── App.css                 ← Global resets + scrollbar
│   ├── index.css               ← Design tokens, custom classes, animations
│   ├── components/ui/          ← 53 shadcn/ui primitives (available, not yet used)
│   ├── hooks/use-mobile.ts     ← Mobile breakpoint hook
│   └── lib/utils.ts            ← cn() helper
├── AGENTS.md                   ← Agent/dev guidelines
├── ARCHITECTURE.md             ← Architecture decisions
└── README.md                   ← This file
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | React 19.2 |
| Build | Vite 7.2.4 |
| Language | TypeScript 5.9.3 (strict) |
| Styling | Tailwind CSS 3.4.19 + custom CSS classes |
| UI Primitives | shadcn/ui (53 Radix components, new-york style) |
| Icons | lucide-react |
| Forms | react-hook-form (installed, not yet used) |
| Validation | zod (installed, not yet used) |
| Charts | recharts (installed, not yet used) |
| Fonts | Sora, Inter, IBM Plex Mono |

---

## Available Scripts

```bash
npm run dev      # Start dev server (Vite)
npm run build    # TypeScript check + production build
npm run lint     # Run ESLint
npm run preview  # Preview production build
```

---

## Design System

### Color Palette

| Token | Hex | Tailwind Class | Usage |
|-------|-----|---------------|-------|
| Background | `#070A12` | `bg-ct-bg` | Page background |
| Background alt | `#111725` | `bg-ct-bg-secondary` | Section backgrounds |
| Accent | `#00E5C0` | `text-ct-accent` / `bg-ct-accent` | Primary CTA color |
| Text | `#F2F5FA` | `text-ct-text` | Primary text |
| Text muted | `#A7B1C6` | `text-ct-text-secondary` | Secondary text |

### Typography

| Token | Font | Usage |
|-------|------|-------|
| `.font-display` | Sora | Headings (uppercase, tight tracking) |
| `.font-body` | Inter | Body copy |
| `.font-mono` | IBM Plex Mono | SKUs, labels, micro text |

### Custom CSS Classes

Key classes defined in `src/index.css`:

- **Buttons:** `.btn-primary` (accent filled, pill), `.btn-secondary` (ghost outline)
- **Cards:** `.card-dark` (glassmorphism), `.product-card`, `.stat-card`, `.dashboard-card`
- **Navigation:** `.nav-link`, `.filter-chip`, `.link-arrow`
- **Typography:** `.heading-display` (uppercase Sora), `.text-micro` (mono 12px)
- **Inputs:** `.input-dark` (dark theme form input)
- **Overlays:** `.grid-overlay`, `.vignette-overlay`, `.noise-overlay`

---

## Current Status

**Landing page complete.** The site is a single scrollable page with 13 sections:

1. Navigation (fixed, sticky, mobile menu)
2. Hero (split layout, animated entrance)
3. Categories (grid of 4 part types)
4. Products (8 hardcoded items, filterable)
5. Checkout (feature showcase)
6. Quote (form UI, non-functional)
7. Quality (trust badges)
8. Shipping (delivery metrics)
9. Support (resource links)
10. Dashboard (preview image)
11. Testimonials (6 cards)
12. Partners (brand logos)
13. CTA (email capture)
14. Footer

---

## Roadmap

- [ ] Client-side routing (React Router or equivalent)
- [ ] API integration layer
- [ ] State management (React Context or store)
- [ ] Functional cart and checkout
- [ ] Auth (login/register)
- [ ] Order history and account pages
- [ ] Extract sections into separate component files
- [ ] Add unit and integration tests
- [ ] Integrate real product data from API
