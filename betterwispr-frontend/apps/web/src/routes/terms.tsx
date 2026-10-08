import { createFileRoute } from "@tanstack/react-router";
import { GITHUB_URL } from "@/lib/links";
import { pageHead } from "@/lib/seo";

export const Route = createFileRoute("/terms")({
  head: () =>
    pageHead(
      "Software terms | BetterWispr",
      "BetterWispr’s software license and third party notices.",
      "/terms",
    ),
  component: () => (
    <article className="legal-page">
      <p className="eyebrow">Software terms</p>
      <h1>License and use</h1>
      <p>
        Original BetterWispr code is licensed under the Apache License, Version
        2.0. The license supplied with the software governs its use,
        redistribution and modification.
      </p>
      <h2>License and notices</h2>
      <p>
        Read the{" "}
        <a href={`${GITHUB_URL}/blob/main/LICENSE`}>Apache 2.0 license</a> and
        the project’s{" "}
        <a href={`${GITHUB_URL}/blob/main/docs/oss-reuse.md`}>
          third party notices
        </a>
        . Dependencies, speech models and tokenizers retain their own licenses
        and terms.
      </p>
      <h2>Review your transcripts</h2>
      <p>
        Speech recognition can make mistakes. Review text before sending or
        relying on it. Results depend on your model, language, microphone and
        hardware. No relative accuracy or speed guarantee is made on this
        website.
      </p>
      <h2>Comparison pages</h2>
      <p>
        Comparisons are written by BetterWispr using the official sources linked
        on each page. Other product names belong to their respective owners.
        Their mention does not imply affiliation or endorsement.
      </p>
    </article>
  ),
});
