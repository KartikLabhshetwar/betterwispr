# betterwispr-frontend

This project was created with [Better-T-Stack](https://github.com/AmanVarshney01/create-better-t-stack), a modern TypeScript stack that combines React, TanStack Router, Hono, and more.

## Features

- **TypeScript** - For type safety and improved developer experience
- **TanStack Router** - File-based routing with full type safety
- **TailwindCSS** - Utility-first CSS for rapid UI development
- **Shared UI package** - shadcn/ui primitives live in `packages/ui`
- **Hono** - Lightweight, performant server framework
- **workers** - Runtime environment

## Getting Started

First, install the dependencies:

```bash
pnpm install
```

Then, run the development server:

```bash
pnpm run dev
```

Open [http://localhost:3001](http://localhost:3001) in your browser to see the web application.
The API is running at [http://localhost:3000](http://localhost:3000).

## UI Customization

React web apps in this stack share shadcn/ui primitives through `packages/ui`.

- Change design tokens and global styles in `packages/ui/src/styles/globals.css`
- Update shared primitives in `packages/ui/src/components/*`
- Adjust shadcn aliases or style config in `packages/ui/components.json` and `apps/web/components.json`

### Add more shared components

Run this from the project root to add more primitives to the shared UI package:

```bash
npx shadcn@latest add accordion dialog popover sheet table -c packages/ui
```

Import shared components like this:

```tsx
import { Button } from "@betterwispr-frontend/ui/components/button";
```

### Add app-specific blocks

If you want to add app-specific blocks instead of shared primitives, run the shadcn CLI from `apps/web`.

## Environment Configuration

Each app owns its environment schema in `.env.schema`. Varlock generates `src/env.ts` during installation; run `pnpm run env:generate` after changing a schema. Commit schemas, and keep secrets in ignored env files or your deployment platform.

Import the generated `ENV` accessor in application code. Shared database and auth packages receive configuration or initialized clients from the application. See [Varlock's monorepo guide](https://varlock.dev/guides/monorepos/).

For Cloudflare, Alchemy loads and validates deployment inputs with `varlock/auto-load` in its Node/Bun deployment process. Worker code reads native bindings; web clients use the framework's public env API through `src/env.public.ts` where needed. Alchemy supplies resource URLs and managed database credentials. In-Worker Varlock protections are deferred until an official Alchemy integration is available; see [the non-Wrangler deployment guidance](https://varlock.dev/integrations/cloudflare/#non-wrangler-deploy-tools-alchemy-sst-pulumi).

Bun's automatic env loading is disabled in `bunfig.toml`; the framework integration or server bootstrap loads Varlock. Node deployments must include Varlock and its dependencies alongside the app schema.

Run standalone Node/Bun tools that use Varlock from the owning app directory so they load that app's schema and env files. `env:generate` only generates TypeScript files; it does not initialize environment values in a subsequent command.

## Production website

The public marketing site is the existing Cloudflare Worker **betterwispr** at
**https://betterwispr.com**. Its configuration is `apps/web/wrangler.jsonc`.
The Alchemy scaffold is separate and does not own this production worker.

```bash
pnpm run build
pnpm run check-types
pnpm --filter web test
pnpm run deploy
```

`deploy` builds and verifies the static pages, then deploys the website with a
pinned Wrangler CLI. It uses the local Cloudflare login (`pnpm dlx
wrangler@4.148.0 login`) or `CLOUDFLARE_API_TOKEN` from the environment. Never
commit credentials. Custom domain, worker name and account must match the
existing production site.

The web build prerenders all public routes, including comparison pages, so
search engines and social previews receive complete HTML and page metadata.
It also generates `sitemap.xml` and a branded `404.html`. Unknown paths return
404 instead of silently serving the homepage. The client hydrates the same
React routes for navigation and interactions.

Comparison content and dated official sources live in
`apps/web/src/lib/comparisons.ts`. Recheck sources when updating claims.
The download destination stays in `apps/web/src/lib/links.ts`.
`apps/web/public/og-image.png` is the product social image, generated with the
built-in image tool: “BetterWispr; Hold to talk. Release to type.; Local
dictation for Mac.; warm off-white, near-black typography, recording capsule
and Option/Space keys.” Its dimensions are declared in the root route metadata.

### Local preview

```bash
pnpm run dev:web
# Or serve the built site with production asset routing:
cd apps/web
pnpm dlx wrangler@4.148.0 dev --port 3003
```

## Project Structure

```
betterwispr-frontend/
├── apps/
│   ├── web/         # Frontend application (React + TanStack Router)
│   └── server/      # Backend API (Hono)
├── packages/
│   ├── ui/          # Shared shadcn/ui components and styles
```

## Available Scripts

- `pnpm run dev`: Start all applications in development mode
- `pnpm run build`: Build all applications
- `pnpm run dev:web`: Start only the web application
- `pnpm run dev:server`: Start only the server
- `pnpm run check-types`: Check TypeScript types across all apps
