import { Link } from "@tanstack/react-router";
import type { ReactNode } from "react";
import BrandMark from "@/components/brand-mark";
import { comparisons } from "@/lib/comparisons";
import { DOWNLOAD_URL, GITHUB_URL, INTEL_DOWNLOAD_URL } from "@/lib/links";

const LINK =
  "text-sm text-zinc-600 transition-colors duration-700 ease-fluid hover:text-zinc-900";

export default function Footer() {
  return (
    <footer className="border-t border-zinc-200">
      <div className="page-shell grid gap-12 py-16 sm:grid-cols-2 lg:grid-cols-[1.5fr_1fr_1.5fr_1fr]">
        <div className="max-w-xs">
          <Link
            to="/"
            className="flex w-max items-center gap-2 rounded-lg text-sm font-semibold"
          >
            <BrandMark className="size-8" />
            BetterWispr
          </Link>
          <p className="mt-4 text-sm text-zinc-600">
            A quieter way to get your thoughts down. Local dictation for macOS.
          </p>
          <p className="mt-6 text-xs text-zinc-500">
            © {new Date().getFullYear()} BetterWispr.
            <br />
            Built by{" "}
            <a
              href="https://x.com/code_kartik"
              className="underline underline-offset-2 hover:text-zinc-900"
            >
              Kartik Labhshetwar
            </a>
            .
          </p>
          <a
            href="https://usefulshelf.co/apps/betterwispr?utm_source=betterwispr.com&utm_medium=referral&utm_campaign=badge&utm_content=light"
            target="_blank"
            rel="noopener"
            className="mt-6 block w-max"
          >
            <img
              src="https://usefulshelf.co/badge/betterwispr.svg"
              alt="Featured on UsefulShelf"
              width={248}
              height={66}
              loading="lazy"
            />
          </a>
        </div>
        <FooterColumn title="Product">
          <a href={DOWNLOAD_URL} className={LINK}>
            Download for Apple Silicon
          </a>
          <a href={INTEL_DOWNLOAD_URL} className={LINK}>
            Download for Intel
          </a>
          <Link to="/" hash="how-it-works" className={LINK}>
            How it works
          </Link>
          <Link to="/changelog" className={LINK}>
            Changelog
          </Link>
          <a href={GITHUB_URL} className={LINK}>
            GitHub
          </a>
        </FooterColumn>
        <FooterColumn title="Blog">
          {comparisons.map((item) => (
            <Link
              to="/blog/$slug"
              params={{ slug: item.slug }}
              key={item.slug}
              className={LINK}
            >
              vs {item.name}
            </Link>
          ))}
          <Link to="/blog" className={LINK}>
            All posts
          </Link>
        </FooterColumn>
        <FooterColumn title="About">
          <Link to="/privacy" className={LINK}>
            Privacy
          </Link>
          <Link to="/terms" className={LINK}>
            Software terms
          </Link>
          <a href={`${GITHUB_URL}/issues`} className={LINK}>
            Report an issue
          </a>
        </FooterColumn>
      </div>
    </footer>
  );
}

function FooterColumn({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-3">
      <p className="eyebrow mb-1">{title}</p>
      {children}
    </div>
  );
}
