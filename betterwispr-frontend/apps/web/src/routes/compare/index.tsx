import { ArrowUpRightIcon } from "@phosphor-icons/react";
import { Link, createFileRoute } from "@tanstack/react-router";
import { ClosingCTA } from "@/components/download-cta";
import { comparisons, REVIEWED_ON } from "@/lib/comparisons";
import { pageHead } from "@/lib/seo";

export const Route = createFileRoute("/compare/")({
  component: Comparisons,
  head: () =>
    pageHead(
      "Compare dictation apps for Mac | BetterWispr",
      "Compare BetterWispr with Superwhisper, Wispr Flow, Kivi, FluidVoice, MacWhisper, Aqua Voice and Apple Dictation. Processing, offline use and workflow tradeoffs.",
      "/compare",
    ),
});

function Comparisons() {
  return (
    <>
      <section className="page-shell py-20 sm:py-24">
        <p className="eyebrow">The dictation field guide</p>
        <h1 className="mt-4 max-w-[680px] text-4xl tracking-tight sm:text-6xl">
          Find the right fit
          <br />
          for your voice.
        </h1>
        <p className="mt-6 max-w-[680px] text-lg text-zinc-600">
          Where your speech is processed. What works offline. How much your
          words get rewritten. The differences that matter when choosing a
          dictation app.
        </p>
        <p className="mt-6 text-sm text-zinc-500">
          Official sources reviewed {REVIEWED_ON}. Written by BetterWispr.
        </p>
        <div className="mt-12 border-t border-zinc-200">
          {comparisons.map((item, index) => (
            <Link
              key={item.slug}
              to="/compare/$slug"
              params={{ slug: item.slug }}
              className="comparison-link group"
            >
              <span className="hidden font-mono text-sm text-zinc-400 sm:block">
                0{index + 1}
              </span>
              <div>
                <p className="text-xl font-medium">
                  BetterWispr vs {item.name}
                </p>
                <p className="mt-2 text-base text-zinc-600">{item.summary}</p>
              </div>
              <span className="hidden text-sm text-zinc-500 lg:block">
                {item.category}
              </span>
              <ArrowUpRightIcon className="size-5 text-zinc-500 transition-transform duration-700 ease-fluid group-hover:translate-x-1" />
            </Link>
          ))}
        </div>
        <aside className="mt-12 max-w-[680px] text-sm text-zinc-600">
          <h2 className="font-semibold text-zinc-900">
            How to read these comparisons
          </h2>
          <p className="mt-3">
            These are feature and workflow comparisons, not accuracy benchmarks.
            We link to official documentation, distinguish local recognition
            from optional cloud rewriting, and say when a detail is unconfirmed.
            Plans and features can change.
          </p>
          <p className="mt-3">
            Try the same short passage in each app using your own microphone,
            language and everyday vocabulary. That tells you more than an
            unsourced accuracy score.
          </p>
        </aside>
      </section>
      <ClosingCTA />
    </>
  );
}
