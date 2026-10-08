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
    /<button\b[^>]*aria-haspopup="menu"[^>]*class="download-cta\b/.test(html),
    `${path}: header download menu`,
  );
  for (const arch of ["arm64", "x86_64"]) {
    assert.ok(
      html.includes(`href="https://github.com/opennookorg/betterwispr/releases/latest/download/BetterWispr-${arch}.dmg"`),
      `${path}: ${arch} download available`,
    );
  }
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
        repo: "opennookorg/betterwispr",
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
        `aria-label="Star opennookorg/betterwispr on GitHub (${full})"`,
      ),
      `${count}: accessible full count`,
    );
    assert.ok(
      html.includes('href="https://github.com/opennookorg/betterwispr"'),
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
  const loaded = renderToStaticMarkup(
    createElement(GitHubStars, {
      repo: "opennookorg/betterwispr",
      stargazersCount: 12,
    }),
  );
  const mark = (markup) => markup.match(/<svg[\s\S]*?<\/svg>/)?.[0];
  assert.ok(
    mark(fallback) && mark(fallback) === mark(loaded),
    "Loading shows the same GitHub mark as the loaded count",
  );
  assert.ok(
    fallback.includes('aria-label="Star opennookorg/betterwispr on GitHub"'),
    "Loading keeps a usable GitHub link without a fabricated count",
  );
  const homepage = await readFile("dist/index.html", "utf8");
  const { default: Testimonials } = await vite.ssrLoadModule(
    "/src/components/ui/cards.tsx",
  );
  const testimonial = {
    name: "Test author",
    handle: "@test_author",
    quote: "An exact quote <preserved> & escaped.",
    postUrl: "https://x.com/test_author/status/123456789",
  };
  const renderTestimonials = (testimonials) => renderToStaticMarkup(
    createElement(Testimonials, { testimonials }),
  );
  const empty = renderTestimonials([]);
  assert.equal(empty, "", "An empty testimonial list renders nothing");
  const single = renderTestimonials([testimonial]);
  assert.ok(single.includes(`href="${testimonial.postUrl}"`));
  assert.ok(single.includes("An exact quote &lt;preserved&gt; &amp; escaped."));
  assert.equal((single.match(/<blockquote/g) ?? []).length, 1);
  assert.ok(!single.includes("testimonials-track"), "Small collections stay static");
  for (const postUrl of ["javascript:alert(1)", "https://x.com.evil.test/a/status/1", "https://example.com/a/status/1", ""]) {
    assert.ok(!renderTestimonials([{ ...testimonial, postUrl }]).includes("<a "), "Only X post URLs are linked");
  }
  const scrolling = renderTestimonials(Array.from({ length: 6 }, () => testimonial));
  assert.equal((scrolling.match(/<blockquote/g) ?? []).length, 12);
  assert.equal((scrolling.match(/aria-hidden="true" inert=""/g) ?? []).length, 2, "Marquee copies are hidden from assistive technology and keyboard navigation");
  assert.ok(scrolling.includes('aria-pressed="false"'), "Scrolling has a pause control");
  const { default: TestimonialsDemo } = await vite.ssrLoadModule("/src/components/ui/demo.tsx");
  const demo = renderToStaticMarkup(createElement(TestimonialsDemo));
  assert.ok(demo.includes("not real endorsements") && !demo.includes("<a "));
  assert.ok(!homepage.includes('id="testimonials"'), "Testimonials stay off the homepage until requested");
  assert.ok(!homepage.includes("Sample author"), "The homepage never imports fictional endorsements");
  const menuButton = homepage.match(
    /<button\b[^>]*aria-controls="navigation-links"[^>]*>/,
  )?.[0];
  assert.ok(
    menuButton?.includes('aria-expanded="false"') &&
      menuButton.includes('aria-label="Open menu"'),
    "The mobile navigation starts collapsed with a named toggle",
  );
  const hero = homepage.match(
    /<section\b[^>]*aria-labelledby="hero-title"[^>]*>([\s\S]*?)<\/section>/,
  )?.[1];
  assert.ok(hero, "The homepage renders its hero");
  assert.deepEqual(
    [...hero.matchAll(/<a\b[^>]*href="([^"]+)"/g)].map((match) => match[1]),
    [
      "https://github.com/opennookorg/betterwispr/releases/latest/download/BetterWispr-arm64.dmg",
      "https://github.com/opennookorg/betterwispr/releases/latest/download/BetterWispr-x86_64.dmg",
    ],
    "The hero offers separate Apple Silicon and Intel downloads",
  );
} finally {
  await vite.close();
}
console.log(
  `Passed: ${paths.length} static pages, metadata, internal links, CTAs, comparison content, 404, OG image, GitHub stars and testimonials.`,
);
