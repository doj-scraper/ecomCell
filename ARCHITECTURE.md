# CellTech Distributor — Architecture

This document explains the architectural decisions, how the pieces fit together, and what limitations exist. It is meant to be comprehensive enough that a developer with no prior context can understand the system and continue building it without ambiguity.

---

## 1. High-Level Architecture

The project has been migrated from a static Vite SPA to a **Next.js 15 App Router** architecture. This transition enables better performance, SEO, and a more scalable structure for future features like authentication and server-side rendering.

```
┌─────────────────────────────────────────────────┐
│                   Browser                         │
│                                                    │
│  Next.js (15.5) → App Router → Build output      │
│                                                    │
│  app/layout.tsx     Root layout with fonts         │
│  app/page.tsx       Home page (composed)           │
│  app/inventory/     Real-time inventory page       │
│  app/catalog/       Parts catalog page             │
│  components/        Extracted section components   │
│  lib/api.ts         Typed API client               │
│  public/images/     Static product images          │
└─────────────────────────────────────────────────────┘
```

The application is now a **Full-Stack Frontend** that communicates with a separate **Express.js Backend** via a typed API client.

---

## 2. Why This Stack

### Next.js 15 + App Router

- **App Router** for nested layouts, server components, and improved routing.
- **next/font** for optimized font loading (Sora, Inter, IBM Plex Mono).
- **next/image** for optimized image delivery (WIP).
- **Server Components** for initial data fetching where appropriate.

### Tailwind CSS 4.0

- Utility-first CSS for rapid iteration.
- Custom `ct-*` color tokens defined in `tailwind.config.js` map to CSS variables.
- Modern CSS-in-JS capabilities with Tailwind 4.

### Framer Motion

- Used for smooth entrance animations and scroll-based interactions.
- Replaces the manual IntersectionObserver pattern in most sections.

### TypeScript (Strict Mode)

- Typed API interfaces for all backend responses.
- Strict type checking for props and state.
- Path alias `@/*` → `./*`

---

## 3. Styling Architecture

The styling system has three layers, from broadest to most specific:

### Layer 1: CSS Variables (globals.css)

Defines the theme in HSL format. Tailwind maps them to `bg-background`, `text-foreground`, etc.

### Layer 2: Tailwind Config Colors (tailwind.config.js)

CellTech-specific hex colors are used throughout the app via Tailwind classes like `bg-ct-bg`, `text-ct-accent`.

### Layer 3: Custom CSS Classes (globals.css)

Component-level styles that combine multiple properties (colors, spacing, transitions, shadows). These are the primary way components get styled — not inline Tailwind on every element.

---

## 4. Design Token System

### Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `#070A12` | `bg-ct-bg` | Page background |
| `#111725` | `bg-ct-bg-secondary` | Section/card backgrounds |
| `#00E5C0` | `text-ct-accent` | Accent (buttons, links, badges) |
| `#F2F5FA` | `text-ct-text` | Primary text |
| `#A7B1C6` | `text-ct-text-secondary` | Muted/secondary text |

### Typography

| Token | Font | Weight | Size | Tracking |
|-------|------|--------|------|----------|
| `.font-display` | Sora | 700 | Variable | 0.08em, uppercase |
| `.font-body` | Inter | 400-600 | 14-16px | Normal |
| `.font-mono` | IBM Plex Mono | 400-500 | 12px | 0.12em, uppercase |

---

## 5. Component Patterns

### Section Structure

Sections have been extracted from the monolithic `App.tsx` into individual files in the `components/` directory.

### API Integration

The `lib/api.ts` file contains a typed client for all backend communication. Components use this client to fetch real-time data from the database.

Example:
```typescript
import { fetchInventory } from '@/lib/api';

// Inside component
const data = await fetchInventory();
```

---

## 6. Known Limitations & Future Work

### Component Extraction
Most sections have been extracted, but some logic still resides in the main `page.tsx`. Further extraction is planned.

### Authentication
The UI for login/register exists, but the backend integration is pending.

### Quote Submission
The quote form is visually complete but does not yet submit data to the backend.

### Testing
No test framework is currently configured. Vitest is recommended for future implementation.
