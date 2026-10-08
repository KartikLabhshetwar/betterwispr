import { ArrowLeftIcon } from "@phosphor-icons/react";
import { Link } from "@tanstack/react-router";
import type { MDXComponents } from "mdx/types";
import { ClosingCTA } from "@/components/download-cta";
import { type Article as ArticleData, formatDate } from "@/lib/blog";

const components: MDXComponents = {
  h2: ({ children }) => (
    <h2 className="mt-12 text-2xl tracking-tight text-balance">{children}</h2>
  ),
  h3: ({ children }) => (
    <h3 className="mt-8 text-lg font-semibold text-balance">{children}</h3>
  ),
  p: ({ children }) => (
    <p className="mt-4 text-base text-pretty text-zinc-700">{children}</p>
  ),
  ul: ({ children }) => (
    <ul className="mt-4 list-disc space-y-2 pl-5 text-base text-zinc-700 marker:text-zinc-300">
      {children}
    </ul>
  ),
  ol: ({ children }) => (
    <ol className="mt-4 list-decimal space-y-2 pl-5 text-base text-zinc-700 marker:text-zinc-400">
      {children}
    </ol>
  ),
  strong: ({ children }) => (
    <strong className="font-semibold text-zinc-900">{children}</strong>
  ),
  code: ({ children }) => (
    <code className="rounded bg-zinc-100 px-1 py-0.5 font-mono text-sm text-zinc-800">
      {children}
    </code>
  ),
  a: ({ children, href }) => (
    <a
      href={href}
      className="text-zinc-900 underline underline-offset-4 hover:text-zinc-600"
    >
      {children}
    </a>
  ),
};

export default function Article({ article }: { article: ArticleData }) {
  return (
    <>
      <article className="page-shell py-16 sm:py-20">
        <Link
          to="/blog"
          className="inline-flex items-center gap-2 text-sm text-zinc-600 hover:text-zinc-900"
        >
          <ArrowLeftIcon /> All posts
        </Link>
        <p className="eyebrow mt-12">
          <time dateTime={article.date}>{formatDate(article.date)}</time>
        </p>
        <h1 className="mt-4 max-w-[880px] text-4xl tracking-tight text-balance sm:text-6xl">
          {article.title}
        </h1>
        <p className="mt-6 max-w-[680px] text-lg text-pretty text-zinc-600">
          {article.description}
        </p>
        <p className="mt-6 text-sm text-zinc-500">By the BetterWispr team</p>
        <div className="mt-12 max-w-[680px] border-t border-zinc-200 pt-4">
          <article.Content components={components} />
        </div>
      </article>
      <ClosingCTA />
    </>
  );
}
