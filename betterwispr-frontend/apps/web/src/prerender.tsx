import {
  createMemoryHistory,
  createRouter,
  RouterProvider,
} from "@tanstack/react-router";
import { renderToString } from "react-dom/server";
import Document from "./components/document";
import { routeTree } from "./routeTree.gen";
import { articles } from "./lib/blog";
import { comparisons } from "./lib/comparisons";

export const paths = [
  "/",
  "/blog",
  ...articles.map((item) => `/blog/${item.slug}`),
  ...comparisons.map((item) => `/blog/${item.slug}`),
  "/changelog",
  "/privacy",
  "/terms",
];

export async function render(path: string) {
  const router = createRouter({
    routeTree,
    history: createMemoryHistory({ initialEntries: [path] }),
    context: {},
  });
  await router.load();
  return (
    "<!doctype html>" +
    renderToString(
      <Document>
        <RouterProvider router={router} />
      </Document>,
    )
  );
}
