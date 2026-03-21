# CellTech Distributor — Agent Guidelines

Read this before making changes. Every rule exists for a reason.

---

## 1. Project Identity

**What this is:** A B2B wholesale mobile repair parts platform. It's a marketing-focused application for CellTech Distributor — a company selling OEM-grade phone components (screens, batteries, boards, cameras) to repair shops at wholesale prices.

**What this is NOT:**
- Not a consumer retail site — the aesthetic is dense, industrial, and catalog-first.
- Not a static Vite SPA anymore (it's a **Next.js 15 App Router** project).

---

## 2. Repository Layout

```
/home/ubuntu/ecomCell/    ← Project root (package.json lives here)
├── app/                        ← Next.js App Router
│   ├── layout.tsx              ← Root layout with fonts & metadata
│   ├── page.tsx                ← Home page (composed of sections)
│   ├── catalog/                ← Parts catalog page
│   ├── inventory/              ← Real-time inventory table (API-connected)
│   └── globals.css             ← Tailwind & global styles
├── components/                 ← Reusable UI components
│   ├── navigation.tsx          ← Shared navigation
│   ├── products-section.tsx    ← API-connected product grid
│   └── ...                     ← Other section components
├── lib/
│   ├── api.ts                  ← Typed API client for backend communication
│   └── utils.ts                ← Utility functions (cn helper)
├── public/
│   └── images/                 ← Static assets
├── AGENTS.md                   ← This file
├── ARCHITECTURE.md             ← Architecture decisions
└── README.md                   ← Project overview
```

**The `@/*` path alias resolves to `./*`.** All imports use `@/components/...`, `@/hooks/...`, `@/lib/...`.

---

## 3. Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 15.5 (App Router) |
| Language | TypeScript 5.7 (Strict) |
| Styling | Tailwind CSS 4.0 + Framer Motion |
| API Client | Native Fetch with TypeScript interfaces |
| Icons | Lucide React |
| Fonts | Sora, Inter, IBM Plex Mono (via next/font) |

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

---

## 5. Component Conventions

### Current Pattern

Components are extracted into individual files in the `components/` directory. Each section follows this pattern:

```tsx
"use client";

import { useEffect, useRef, useState } from 'react';
import { motion } from 'framer-motion';

export function SectionName() {
  // Use Framer Motion for entrance animations
  return (
    <section className="section-flowing py-20 lg:py-32">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
      >
        {/* Content */}
      </motion.div>
    </section>
  );
}
```

---

## 6. Styling Rules

1. **Use `ct-*` Tailwind colors** — never hardcode hex values in JSX. Use `bg-ct-bg`, `text-ct-accent`, etc.
2. **Custom CSS classes live in `app/globals.css`** — not in component files.
3. **Use the `cn()` utility** from `@/lib/utils` when merging class names conditionally.
4. **Fonts are set via Tailwind classes** — `font-display`, `font-body`, `font-mono`.
5. **Responsive breakpoints** — `sm:` (640px), `md:` (768px), `lg:` (1024px), `xl:` (1280px). Mobile-first.

---

## 7. Rules for Agents

### Do

- Add new sections by extracting them into separate files in `components/`.
- Use **Framer Motion** for animations instead of manual IntersectionObserver.
- Use the typed API client in `lib/api.ts` for all backend communication.
- Keep the dark theme — don't introduce light mode unless explicitly asked.
- Use `ct-*` Tailwind colors for consistency.

### Don't

- ❌ Don't rename or remove `ct-*` color tokens in `tailwind.config.js`.
- ❌ Don't add `#070A12` or other hex values directly in JSX — use Tailwind classes.
- ❌ Don't break the z-index layer system (grid:1, vignette:2, noise:3, sections:10-130).
- ❌ Don't add backend code (no API routes, no database, no server) in the frontend repo.
- ❌ Don't remove the animation pattern from existing sections.
- ❌ Don't use the shadcn/ui components without a reason — custom CSS classes are preferred for this project's style.

---

## 8. Context Files for Future Sessions

When starting a new session, include these files for full context:

**Always:**
- `AGENTS.md` (this file)
- `app/page.tsx` (main entry)
- `app/globals.css` (all custom styles + tokens)
- `lib/api.ts` (API client)

**For styling work:**
- `tailwind.config.js` (theme config)

**For build/config work:**
- `next.config.ts`
- `tsconfig.json`
- `package.json`
