import {
  HeadContent,
  Link,
  Outlet,
  createRootRouteWithContext,
} from "@tanstack/react-router";

import Footer from "@/components/footer";
import Header from "@/components/header";

import "@fontsource-variable/geist";
import "@fontsource-variable/geist-mono";
import "../index.css";

export interface RouterAppContext {}

const TITLE = "BetterWispr: local dictation for macOS";
const DESCRIPTION =
  "Hold a shortcut, speak, and BetterWispr types into the app you were using. Speech stays on your Mac. Free and open source.";

export const Route = createRootRouteWithContext<RouterAppContext>()({
  component: RootComponent,
  notFoundComponent: NotFound,
  head: () => ({
    meta: [
      { title: TITLE },
      { name: "description", content: DESCRIPTION },
      { name: "theme-color", content: "#ffffff" },
      { property: "og:type", content: "website" },
      { property: "og:title", content: TITLE },
      { property: "og:description", content: DESCRIPTION },
      { name: "twitter:card", content: "summary_large_image" },
      { property: "og:site_name", content: "BetterWispr" },
      { property: "og:image", content: "https://betterwispr.com/og-image.png" },
      { property: "og:image:width", content: "1730" },
      { property: "og:image:height", content: "909" },
      {
        property: "og:image:alt",
        content:
          "BetterWispr. Hold to talk. Release to type. Local dictation for Mac.",
      },
      {
        name: "twitter:image",
        content: "https://betterwispr.com/og-image.png",
      },
    ],
    links: [{ rel: "icon", type: "image/svg+xml", href: "/favicon.svg" }],
  }),
});

function RootComponent() {
  return (
    <>
      <HeadContent />
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:fixed focus:top-3 focus:left-3 focus:z-[60] focus:rounded-lg focus:bg-ink focus:px-3 focus:py-2 focus:text-sm focus:font-semibold focus:text-white"
      >
        Skip to content
      </a>
      <div className="flex min-h-svh flex-col bg-white text-zinc-900 antialiased">
        <Header />
        <main id="main" className="flex-1">
          <Outlet />
        </main>
        <Footer />
      </div>
    </>
  );
}

function NotFound() {
  return (
    <section className="mx-auto flex max-w-[680px] flex-col items-center px-6 py-24 text-center">
      <p className="font-mono text-sm text-zinc-400">404</p>
      <h1 className="mt-4 text-4xl tracking-tight text-zinc-900">
        Nothing was said here
      </h1>
      <p className="mt-4 text-base text-zinc-500">
        This page does not exist. It may have moved, or the link is out of date.
      </p>
      <Link
        to="/"
        className="mt-8 rounded-lg bg-ink px-3 py-2 text-base font-semibold text-white transition-all duration-700 ease-fluid hover:bg-zinc-700 active:scale-[0.98]"
      >
        Back to home
      </Link>
    </section>
  );
}
