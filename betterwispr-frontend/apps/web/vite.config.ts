import path from "node:path";

import mdx from "@mdx-js/rollup";
import tailwindcss from "@tailwindcss/vite";
import { tanstackRouter } from "@tanstack/router-plugin/vite";
import react from "@vitejs/plugin-react";
import { defineConfig, searchForWorkspaceRoot } from "vite";

const repoRoot = path.resolve(import.meta.dirname, "../../..");

/** Drops the changelog preamble so rendering starts at the first release heading. */
function startAtFirstRelease() {
  return (tree: { children: { type: string; depth?: number }[] }) => {
    tree.children.splice(
      0,
      tree.children.findIndex((node) => node.type === "heading" && node.depth === 2),
    );
  };
}

export default defineConfig({
  server: {
    port: 3001,
    fs: {
      allow: [searchForWorkspaceRoot(process.cwd()), path.join(repoRoot, "CHANGELOG.md")],
    },
  },
  resolve: {
    tsconfigPaths: true,
    dedupe: ["react", "react-dom"],
    alias: { "@root": repoRoot },
  },
  plugins: [
    tailwindcss(),
    tanstackRouter({
      target: "react",
      autoCodeSplitting: true,
    }),
    { enforce: "pre", ...mdx({ remarkPlugins: [startAtFirstRelease] }) },
    react({ include: /\.(md|mdx|js|jsx|ts|tsx)$/ }),
  ],
});
