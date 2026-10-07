import ChangelogContent from "@root/CHANGELOG.md";
import type { MDXComponents } from "mdx/types";
import { Children, type ComponentPropsWithoutRef } from "react";

const RELEASE_HEADING = /^\[(.+?)\](?:\s*-\s*(.+))?$/;

function Release({ children }: ComponentPropsWithoutRef<"h2">) {
  const text = Children.toArray(children).join("");
  const [, version = text, date] = RELEASE_HEADING.exec(text) ?? [];
  const unreleased = version.toLowerCase() === "unreleased";

  return (
    <h3
      id={unreleased ? "unreleased" : `v${version.replaceAll(".", "-")}`}
      className="mt-10 scroll-mt-20 border-t border-zinc-100 pt-8 sm:col-start-1 sm:row-span-2"
    >
      <span className="block font-mono text-sm text-zinc-900">{unreleased ? "Unreleased" : `v${version}`}</span>
      <span className="mt-1 block text-xs text-zinc-400">
        {date
          ? new Date(date).toLocaleDateString("en-US", {
              month: "short",
              day: "numeric",
              year: "numeric",
              timeZone: "UTC",
            })
          : "Next release"}
      </span>
    </h3>
  );
}

const components: MDXComponents = {
  h2: Release,
  h3: ({ children }) => (
    <h4 className="pt-6 text-sm font-medium text-zinc-900 sm:col-start-2 sm:[h3+&]:mt-10 sm:[h3+&]:border-t sm:[h3+&]:border-zinc-100 sm:[h3+&]:pt-8">
      {children}
    </h4>
  ),
  ul: ({ children }) => (
    <ul className="mt-3 list-disc space-y-2 pl-5 text-sm text-zinc-600 marker:text-zinc-300 sm:col-start-2">
      {children}
    </ul>
  ),
  code: ({ children }) => (
    <code className="rounded bg-zinc-100 px-1 py-0.5 font-mono text-xs text-zinc-800">{children}</code>
  ),
  a: ({ children, href }) => (
    <a href={href} className="text-zinc-900 underline underline-offset-2 hover:text-zinc-600">
      {children}
    </a>
  ),
};

export default function Changelog() {
  return (
    <div className="sm:grid sm:grid-cols-[120px_minmax(0,1fr)] sm:gap-x-8">
      <ChangelogContent components={components} />
    </div>
  );
}
