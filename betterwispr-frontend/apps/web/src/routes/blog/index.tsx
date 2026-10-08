import { ArrowUpRightIcon } from "@phosphor-icons/react";
import { Link, createFileRoute } from "@tanstack/react-router";
import { ClosingCTA } from "@/components/download-cta";
import { articles, formatDate } from "@/lib/blog";
import { comparisons, REVIEWED_ON } from "@/lib/comparisons";
import { pageHead } from "@/lib/seo";

export const Route = createFileRoute("/blog/")({
  component: Blog,
  head: () =>
    pageHead(
      "Blog: local dictation and Mac apps compared | BetterWispr",
      "The BetterWispr blog. How local dictation works on a Mac, plus comparisons with Superwhisper, Wispr Flow, Kivi, FluidVoice, MacWhisper, Aqua Voice and Apple Dictation.",
      "/blog",
    ),
});

function Blog() {
  return (
    <>
      <section className="page-shell py-20 sm:py-24">
        <p className="eyebrow">Blog</p>
        <h1 className="mt-4 max-w-[680px] text-4xl tracking-tight text-balance sm:text-6xl">
          Notes on talking
          <br />
          instead of typing.
        </h1>
        <p className="mt-6 max-w-[680px] text-lg text-pretty text-zinc-600">
          How local dictation works, how BetterWispr compares with other
          dictation apps, and how much your words get rewritten. Written by the
          people building BetterWispr.
        </p>
        {articles.length > 0 && (
          <section className="mt-16" aria-labelledby="articles-title">
            <h2 id="articles-title" className="text-2xl tracking-tight">
              Articles
            </h2>
            <div className="mt-6 border-t border-zinc-200">
              {articles.map((item) => (
                <Link
                  key={item.slug}
                  to="/blog/$slug"
                  params={{ slug: item.slug }}
                  className="comparison-link group lg:grid-cols-[auto_1fr_auto]"
                >
                  <time
                    dateTime={item.date}
                    className="hidden w-36 text-sm text-zinc-400 sm:block"
                  >
                    {formatDate(item.date)}
                  </time>
                  <div>
                    <p className="text-xl font-medium text-balance">
                      {item.title}
                    </p>
                    <p className="mt-2 text-base text-pretty text-zinc-600">
                      {item.description}
                    </p>
                  </div>
                  <ArrowUpRightIcon className="size-5 text-zinc-500 transition-transform duration-700 ease-fluid group-hover:translate-x-1" />
                </Link>
              ))}
            </div>
          </section>
        )}
        <h2 className="mt-16 text-2xl tracking-tight">Comparisons</h2>
        <div className="mt-6 border-t border-zinc-200">
          {comparisons.map((item, index) => (
            <Link
              key={item.slug}
              to="/blog/$slug"
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
            How to read our comparisons
          </h2>
          <p className="mt-3">
            These are feature and workflow comparisons, not accuracy benchmarks.
            We link to official documentation, distinguish local recognition
            from optional cloud rewriting, and say when a detail is unconfirmed.
            Official sources were reviewed {REVIEWED_ON}. Plans and features can
            change.
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
