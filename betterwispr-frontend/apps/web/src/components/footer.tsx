import { Link } from "@tanstack/react-router";
import type { ReactNode } from "react";

import BrandMark from "@/components/brand-mark";
import { DOWNLOAD_URL, GITHUB_URL } from "@/lib/links";

const LINK = "text-sm text-zinc-500 transition-colors duration-700 ease-fluid hover:text-zinc-900";

export default function Footer() {
  return (
    <footer className="border-t border-zinc-200">
      <div className="mx-auto grid max-w-[1100px] gap-12 px-6 py-16 sm:grid-cols-[1fr_auto_auto] sm:gap-24">
        <div className="max-w-xs">
          <Link to="/" className="flex w-max items-center gap-2 rounded-lg text-sm font-semibold text-zinc-900">
            <BrandMark className="size-6" />
            BetterWispr
          </Link>
          <p className="mt-4 text-sm text-zinc-500">
            Local dictation for macOS. Your voice is transcribed on your Mac and never leaves it.
          </p>
          <p className="mt-6 text-xs text-zinc-400">
            © {new Date().getFullYear()} BetterWispr. Built by{" "}
            <a href="https://x.com/code_kartik" className="underline underline-offset-2 hover:text-zinc-900">
              Kartik Labhshetwar
            </a>
            .
          </p>
        </div>
        <FooterColumn title="Product">
          <a href={DOWNLOAD_URL} className={LINK}>
            Download
          </a>
          <Link to="/changelog" className={LINK}>
            Changelog
          </Link>
        </FooterColumn>
        <FooterColumn title="Source">
          <a href={GITHUB_URL} className={LINK}>
            GitHub
          </a>
          <a href={`${GITHUB_URL}/issues`} className={LINK}>
            Report an issue
          </a>
          <a href={`${GITHUB_URL}/blob/main/LICENSE`} className={LINK}>
            Apache 2.0 license
          </a>
        </FooterColumn>
      </div>
    </footer>
  );
}

function FooterColumn({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-3">
      <p className="text-xs font-medium tracking-widest text-zinc-400 uppercase">{title}</p>
      {children}
    </div>
  );
}
