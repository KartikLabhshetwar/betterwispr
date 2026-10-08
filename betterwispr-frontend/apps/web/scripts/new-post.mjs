import { writeFile } from "node:fs/promises";

const title = process.argv.slice(2).join(" ").trim();
if (!title) {
  console.error('Usage: pnpm new-post "Your post title"');
  process.exit(1);
}
const slug = title
  .toLowerCase()
  .normalize("NFKD")
  .replace(/[^a-z0-9]+/g, "-")
  .replace(/^-|-$/g, "");
const now = new Date();
const date = [now.getFullYear(), now.getMonth() + 1, now.getDate()]
  .map((part) => String(part).padStart(2, "0"))
  .join("-");
const file = `src/content/blog/${slug}.mdx`;

await writeFile(
  file,
  `export const meta = {
  title: ${JSON.stringify(title)},
  description: "",
  date: "${date}",
};

Open with the problem or question this post answers.

## First section

Write in short paragraphs. Link to the code or official docs behind every claim.
`,
  { flag: "wx" },
).catch((error) => {
  if (error.code !== "EEXIST") throw error;
  console.error(`${file} already exists. Pick another title or edit that post.`);
  process.exit(1);
});

console.log(`Created ${file}
Next:
  1. Write the description (50+ characters) and the post body.
  2. Preview it with pnpm start at http://localhost:3001/blog/${slug}
  3. Run pnpm run build && pnpm test before you commit.`);
