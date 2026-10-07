import { createFileRoute } from "@tanstack/react-router";

import Changelog from "@/components/changelog";
import { GITHUB_URL } from "@/lib/links";

const TITLE = "Changelog · BetterWispr";
const DESCRIPTION = "Every BetterWispr release and what changed in it.";

export const Route = createFileRoute("/changelog")({
  component: ChangelogPage,
  head: () => ({
    meta: [
      { title: TITLE },
      { name: "description", content: DESCRIPTION },
      { property: "og:title", content: TITLE },
      { property: "og:description", content: DESCRIPTION },
    ],
  }),
});

function ChangelogPage() {
  return (
    <section aria-labelledby="changelog-title" className="mx-auto max-w-[680px] px-6 pt-24 pb-24 sm:pt-32">
      <h1 id="changelog-title" className="text-4xl tracking-tight text-zinc-900">
        Changelog
      </h1>
      <p className="mt-4 text-base text-zinc-500">
        Every release, rendered from{" "}
        <a
          href={`${GITHUB_URL}/blob/main/CHANGELOG.md`}
          className="text-zinc-900 underline underline-offset-2 hover:text-zinc-600"
        >
          CHANGELOG.md
        </a>{" "}
        in the repository.
      </p>
      <Changelog />
    </section>
  );
}
