import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { createServer } from "vite";

const origin = "https://betterwispr.com";
const sitemap = await readFile("dist/sitemap.xml", "utf8");
const paths = [
  ...sitemap.matchAll(/<loc>https:\/\/betterwispr.com([^<]*)<\/loc>/g),
].map((match) => match[1]);
assert.equal(
  paths.length,
  12,
  "Expected homepage, comparison hub, seven comparisons and three information pages",
);
const titles = new Set();
for (const path of paths) {
  const html = await readFile(
    path === "/" ? "dist/index.html" : `dist${path}.html`,
    "utf8",
  );
  const head = html.slice(0, html.indexOf("</head>"));
  const title = head.match(/<title>(.*?)<\/title>/)?.[1];
  assert.ok(title && !titles.has(title), `${path}: unique static title`);
  titles.add(title);
  assert.equal(
    (html.match(/<h1\b/g) ?? []).length,
    1,
    `${path}: one rendered heading`,
  );
  assert.ok(
    head.includes(`rel="canonical" href="${origin}${path}"`),
    `${path}: canonical URL`,
  );
  assert.ok(
    head.includes(
      'property="og:image" content="https://betterwispr.com/og-image.png"',
    ),
    `${path}: static OG image`,
  );
  assert.ok(
    head.includes('name="twitter:card" content="summary_large_image"'),
    `${path}: large social card`,
  );
  assert.ok(
    html.includes(
      'href="https://github.com/KartikLabhshetwar/betterwispr/releases/latest"',
    ),
    `${path}: working CTA destination configuration`,
  );
  for (const [, href] of html.matchAll(/href="(\/[^"#]*)/g)) {
    assert.ok(
      paths.includes(href) ||
        href.startsWith("/assets/") ||
        href === "/favicon.svg",
      `${path}: unknown internal link ${href}`,
    );
  }
  if (path.startsWith("/compare/")) {
    assert.ok(
      html.includes("<table") && html.includes("Sources and scope"),
      `${path}: prerendered comparison content`,
    );
  }
}
assert.ok(
  (await readFile("dist/404.html", "utf8")).includes("Nothing was said here"),
  "Branded 404",
);
const png = await readFile("dist/og-image.png");
assert.equal(png.subarray(1, 4).toString(), "PNG");
assert.equal(png.readUInt32BE(16), 1730);
assert.equal(png.readUInt32BE(20), 909);

const vite = await createServer({
  server: { middlewareMode: true },
  appType: "custom",
});
try {
  const { GitHubStars } = await vite.ssrLoadModule(
    "/src/components/github-stars.tsx",
  );
  for (const [count, compact, full, locales] of [
    [0, "0", "0 stars", "en-US"],
    [1, "1", "1 star", "en-US"],
    [1200, "1.2k", "1,200 stars", "en-US"],
    [2050, "2.1k", "2,050 stars", "en-US"],
    [1200000, "1.2m", "1,200,000 stars", "en-US"],
    [2050, "2,1\u00a0mil", "2050 stars", "es-ES"],
  ]) {
    const html = renderToStaticMarkup(
      createElement(GitHubStars, {
        repo: "KartikLabhshetwar/betterwispr",
        stargazersCount: count,
        locales,
      }),
    );
    assert.ok(
      html.includes(`>${compact}</span>`),
      `${count}: compact ${locales} count`,
    );
    assert.ok(
      html.includes(
        `aria-label="Star KartikLabhshetwar/betterwispr on GitHub (${full})"`,
      ),
      `${count}: accessible full count`,
    );
    assert.ok(
      html.includes('href="https://github.com/KartikLabhshetwar/betterwispr"'),
    );
    assert.ok(
      html.includes('target="_blank"') && html.includes('rel="noopener"'),
    );
    assert.ok(
      html.includes('role="link"'),
      "The GitHub action keeps link semantics",
    );
  }
  const { default: StarOnGithub } = await vite.ssrLoadModule(
    "/src/components/star-on-github.tsx",
  );
  const fallback = renderToStaticMarkup(
    createElement(StarOnGithub, { compact: true }),
  );
  assert.ok(
    fallback.includes('aria-busy="true"') &&
      fallback.includes('aria-label="BetterWispr on GitHub"'),
    "Loading keeps a usable GitHub link without a fabricated count",
  );
  assert.ok(
    renderToStaticMarkup(createElement(StarOnGithub)).includes(
      "Star on GitHub",
    ),
    "The hero retains its original star action",
  );
} finally {
  await vite.close();
}
console.log(
  `Passed: ${paths.length} static pages, metadata, internal links, CTAs, comparison content, 404, OG image and GitHub stars.`,
);
