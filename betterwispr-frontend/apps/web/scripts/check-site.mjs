import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

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
console.log(
  `Passed: ${paths.length} static pages, metadata, internal links, CTAs, comparison content, 404 and OG image.`,
);
