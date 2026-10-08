import {
  createMemoryHistory,
  createRouter,
  RouterProvider,
} from "@tanstack/react-router";
import { renderToString } from "react-dom/server";
import Document from "./components/document";
import { routeTree } from "./routeTree.gen";
import { comparisons } from "./lib/comparisons";

export const paths = [
  "/",
  "/compare",
  ...comparisons.map((item) => `/compare/${item.slug}`),
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
