import { createFileRoute } from "@tanstack/react-router";
import Changelog from "@/components/changelog";
import { ClosingCTA } from "@/components/download-cta";
import { pageHead } from "@/lib/seo";

export const Route = createFileRoute("/changelog")({
  head: () =>
    pageHead(
      "Changelog | BetterWispr",
      "Updates and release notes for BetterWispr, the local dictation app for Mac.",
      "/changelog",
    ),
  component: () => (
    <>
      <section className="mx-auto max-w-[880px] px-6 py-20">
        <p className="eyebrow">Better with every release</p>
        <h1 className="mt-4 text-5xl tracking-tight">Changelog</h1>
        <p className="mt-6 text-lg text-zinc-600">
          What’s new, what’s fixed, and what’s coming next.
        </p>
        <Changelog />
      </section>
      <ClosingCTA />
    </>
  ),
});
