import { mkdir, readFile, writeFile } from "node:fs/promises";
import { createServer } from "vite";

const template = await readFile("dist/index.html", "utf8");
const assets =
  template
    .match(
      /<(?:script\b[^>]*src=[^>]*><\/script|link\b[^>]*rel="stylesheet"[^>]*)>/g,
    )
    ?.join("") ?? "";
if (!assets.includes("script")) throw new Error("Missing built client entry");
const vite = await createServer({
  server: { middlewareMode: true },
  appType: "custom",
});
try {
  const { render, paths } = await vite.ssrLoadModule("/src/prerender.tsx");
  for (const path of [...paths, "/404"]) {
    const html = (await render(path)).replace(
      "</head>",
      `${assets}${path === "/404" ? '<meta name="robots" content="noindex" />' : ""}</head>`,
    );
    const file =
      path === "/"
        ? "dist/index.html"
        : path === "/404"
          ? "dist/404.html"
          : `dist${path}.html`;
    await writeFile(file, html).catch(async (error) => {
      if (error.code !== "ENOENT") throw error;
      await mkdir(file.slice(0, file.lastIndexOf("/")), { recursive: true });
      await writeFile(file, html);
    });
  }
  await writeFile(
    "dist/sitemap.xml",
    `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">${paths.map((path) => `<url><loc>https://betterwispr.com${path}</loc></url>`).join("")}</urlset>`,
  );
  console.log(`Prerendered ${paths.length} pages and the 404 page.`);
} finally {
  await vite.close();
}
