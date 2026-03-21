# CellTech Distributor — Frontend

B2B wholesale mobile repair parts platform. A catalog-first, dark-themed application for CellTech Distributor — selling OEM-grade phone components (screens, batteries, boards, cameras) to repair shops at wholesale prices.

---

## Quick Start

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

---

## Project Structure (Next.js Migration)

The project has been migrated from a Vite SPA to a **Next.js 15 App Router** architecture for better performance, SEO, and scalability.

```
app/
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
├── AGENTS.md                   ← Agent/dev guidelines
├── ARCHITECTURE.md             ← Architecture decisions
└── README.md                   ← This file
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 15.5 (App Router) |
| Language | TypeScript 5.7 (Strict) |
| Styling | Tailwind CSS 4.0 + Framer Motion |
| API Client | Native Fetch with TypeScript interfaces |
| Icons | Lucide React |
| Fonts | Sora, Inter, IBM Plex Mono (via next/font) |

---

## Phase 2: API Integration & Deployment ✅

The application is now fully connected to the **CellTech Backend** and deployed.

### Key Achievements:
- **Next.js Migration:** Successfully moved from Vite to Next.js App Router.
- **Real-time Data:** The `Inventory` and `Catalog` sections now fetch live data from the backend API.
- **Dynamic Filtering:** Users can filter parts by Brand and Model using real data from the database.
- **Deployment:** 
  - **Frontend:** Deployed to Vercel with automatic CI/CD.
  - **Backend:** Deployed to Vercel/Neon (PostgreSQL).
- **Error Handling:** Implemented global Error Boundaries and 404 handling.

---

## Design System

### Color Palette (Custom Tokens)
- **Background:** `#070A12` (`bg-ct-bg`)
- **Accent:** `#00E5C0` (`text-ct-accent`)
- **Text:** `#F2F5FA` (`text-ct-text`)

### Typography
- **Display:** Sora (Headings)
- **Body:** Inter (Content)
- **Mono:** IBM Plex Mono (SKUs, Labels)

---

## Roadmap

- [x] Next.js App Router Migration
- [x] Backend API Integration (Inventory/Catalog)
- [ ] Authentication System (JWT/Session)
- [ ] Functional Quote Submission
- [ ] User Dashboard & Order History
- [ ] Shopping Cart Persistence
- [ ] Unit & Integration Testing
