import { ArrowLeftIcon, ArrowRightIcon } from "@phosphor-icons/react";
import { Link, createFileRoute, notFound } from "@tanstack/react-router";
import DownloadCTA, { ClosingCTA } from "@/components/download-cta";
import { BETTERWISPR_FACTS, comparisons, REVIEWED_ON } from "@/lib/comparisons";
import { pageHead } from "@/lib/seo";

export const Route = createFileRoute("/compare/$slug")({
  loader: ({ params }) => {
    const comparison = comparisons.find((item) => item.slug === params.slug);
    if (!comparison) throw notFound();
    return comparison;
  },
  head: ({ loaderData }) =>
    loaderData
      ? pageHead(
          `BetterWispr vs ${loaderData.name} | Mac dictation compared`,
          loaderData.intro,
          `/compare/${loaderData.slug}`,
        )
      : {
          meta: [
            { title: "Comparison not found | BetterWispr" },
            { name: "robots", content: "noindex" },
          ],
        },
  component: ComparisonPage,
});

function ComparisonPage() {
  const item = Route.useLoaderData();
  return (
    <>
      <article className="page-shell py-16 sm:py-20">
        <Link
          to="/compare"
          className="inline-flex items-center gap-2 text-sm text-zinc-600 hover:text-zinc-900"
        >
          <ArrowLeftIcon /> All comparisons
        </Link>
        <p className="eyebrow mt-12">{item.category}</p>
        <h1 className="mt-4 max-w-[880px] text-4xl tracking-tight sm:text-6xl">
          BetterWispr
          <br />
          <span className="text-zinc-500">vs {item.name}</span>
        </h1>
        <p className="mt-6 max-w-[680px] text-lg text-zinc-600">{item.intro}</p>
        <div className="mt-8">
          <DownloadCTA />
        </div>
        <p className="mt-6 text-sm text-zinc-500">
          Reviewed {REVIEWED_ON} · By the BetterWispr team
        </p>

        <section className="mt-16" aria-labelledby="comparison-title">
          <h2 id="comparison-title" className="text-2xl tracking-tight">
            At a glance
          </h2>
          <div
            className="mt-6 overflow-x-auto rounded-xl border border-zinc-200"
            role="region"
            aria-label={`Feature comparison with ${item.name}`}
            tabIndex={0}
          >
            <table className="w-full min-w-[620px] border-collapse text-left text-sm">
              <caption className="sr-only">
                BetterWispr and {item.name}: platform, processing, offline use,
                account, price model and cleanup
              </caption>
              <thead>
                <tr className="bg-zinc-50">
                  <th scope="col" className="p-6 font-medium text-zinc-500">
                    What matters
                  </th>
                  <th
                    scope="col"
                    className="w-[36%] bg-paper p-6 text-base font-semibold"
                  >
                    BetterWispr
                  </th>
                  <th
                    scope="col"
                    className="w-[36%] p-6 text-base font-semibold"
                  >
                    {item.name}
                  </th>
                </tr>
              </thead>
              <tbody>
                {BETTERWISPR_FACTS.map(([label, value], index) => (
                  <tr key={label} className="border-t border-zinc-200">
                    <th scope="row" className="p-6 align-top font-medium">
                      {label}
                    </th>
                    <td className="bg-paper/40 p-6 align-top text-zinc-700">
                      {value}
                    </td>
                    <td className="p-6 align-top text-zinc-600">
                      {item.facts[index]}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-xs text-zinc-500 sm:hidden">
            Swipe the table to see both apps.
          </p>
        </section>

        <section
          className="my-16 grid gap-12 sm:grid-cols-2"
          aria-label="Which app fits your workflow"
        >
          <div>
            <p className="eyebrow">Choose BetterWispr if</p>
            <h2 className="mt-4 text-2xl tracking-tight">
              Local dictation is the priority.
            </h2>
            <p className="mt-4 text-base text-zinc-600">{item.betterFor}</p>
          </div>
          <div>
            <p className="eyebrow">Consider {item.name} if</p>
            <h2 className="mt-4 text-2xl tracking-tight">
              Its workflow fits you better.
            </h2>
            <p className="mt-4 text-base text-zinc-600">
              {item.alternativeFor}
            </p>
          </div>
        </section>
        <aside className="rounded-xl bg-paper p-8">
          <h2 className="text-lg font-semibold">Our take</h2>
          <p className="mt-3 max-w-[680px] text-base text-zinc-700">
            {item.takeaway}
          </p>
        </aside>
        <section className="mt-12" aria-labelledby="sources-title">
          <h2 id="sources-title" className="text-lg font-semibold">
            Sources and scope
          </h2>
          <p className="mt-3 max-w-[680px] text-sm text-zinc-600">
            Based on the official pages below, reviewed {REVIEWED_ON}. This
            comparison is published by BetterWispr and is not an independent
            benchmark. We have not measured relative accuracy or speed. Check
            each provider for current plans and availability.
          </p>
          <ul className="mt-4 space-y-3">
            {item.sources.map((source) => (
              <li key={source.url}>
                <a
                  className="text-sm underline underline-offset-4 hover:text-zinc-600"
                  href={source.url}
                >
                  {source.label} ↗
                </a>
              </li>
            ))}
          </ul>
        </section>
        <nav
          className="mt-16 border-t border-zinc-200 pt-8"
          aria-label="Other comparisons"
        >
          <h2 className="text-lg font-semibold">Keep comparing</h2>
          <div className="mt-4 flex flex-wrap gap-x-8 gap-y-4">
            {comparisons
              .filter((other) => other.slug !== item.slug)
              .map((other) => (
                <Link
                  key={other.slug}
                  to="/compare/$slug"
                  params={{ slug: other.slug }}
                  className="inline-flex items-center gap-2 text-sm text-zinc-600 hover:text-zinc-900"
                >
                  {other.name}
                  <ArrowRightIcon />
                </Link>
              ))}
          </div>
        </nav>
      </article>
      <ClosingCTA />
    </>
  );
}
