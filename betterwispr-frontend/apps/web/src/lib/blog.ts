import type { MDXContent } from "mdx/types";

const modules = import.meta.glob<{ default: MDXContent; meta?: unknown }>(
  "../content/blog/*.mdx",
  { eager: true },
);

/** Validates a post's `export const meta` so a bad post fails the build with the file name. */
function parseMeta(file: string, meta: unknown) {
  const { title, description, date } = Object(meta);
  const problems = [
    (typeof title !== "string" || !title.trim()) && "add a title",
    (typeof description !== "string" || description.trim().length < 50) &&
      "write a description of at least 50 characters for search and social previews",
    (typeof date !== "string" ||
      !/^\d{4}-\d{2}-\d{2}$/.test(date) ||
      Number.isNaN(Date.parse(date))) &&
      "use a YYYY-MM-DD date",
  ].filter(Boolean);
  if (problems.length > 0) {
    throw new Error(`${file.replace("../", "src/")}: ${problems.join("; ")}`);
  }
  return { title: title as string, description: description as string, date: date as string };
}

export const articles = Object.entries(modules)
  .map(([file, module]) => ({
    slug: file.slice(file.lastIndexOf("/") + 1, -".mdx".length),
    ...parseMeta(file, module.meta),
    Content: module.default,
  }))
  .sort((a, b) => b.date.localeCompare(a.date));

export type Article = (typeof articles)[number];

export function formatDate(date: string) {
  return new Date(date).toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  });
}
