import { GithubLogoIcon } from "@phosphor-icons/react";
import { Link } from "@tanstack/react-router";

import AppleLogo from "@/components/apple-logo";
import BrandMark from "@/components/brand-mark";
import { DOWNLOAD_URL, GITHUB_URL } from "@/lib/links";

export default function Header() {
  return (
    <header className="fixed inset-x-0 top-0 z-50 h-14 border-b border-zinc-200 bg-white/90 backdrop-blur-xl">
      <nav className="mx-auto flex h-full max-w-[1100px] items-center justify-between px-6">
        <Link to="/" className="flex items-center gap-2 rounded-lg text-sm font-semibold text-zinc-900">
          <BrandMark className="size-6" />
          BetterWispr
        </Link>
        <div className="flex items-center gap-1">
          <Link
            to="/"
            hash="changelog"
            className="hidden rounded-lg px-3 py-2 text-sm text-zinc-500 transition-colors sm:block duration-700 ease-fluid hover:text-zinc-900"
          >
            Changelog
          </Link>
          <a
            href={GITHUB_URL}
            aria-label="BetterWispr on GitHub"
            className="rounded-lg p-2 text-zinc-500 transition-colors duration-700 ease-fluid hover:text-zinc-900"
          >
            <GithubLogoIcon className="size-5" />
          </a>
          <a
            href={DOWNLOAD_URL}
            className="ml-2 flex items-center gap-2 rounded-lg bg-ink px-3 py-2 text-sm font-semibold text-white transition-all duration-700 ease-fluid hover:bg-zinc-700 active:scale-[0.98]"
          >
            <AppleLogo className="size-4" />
            Download
          </a>
        </div>
      </nav>
    </header>
  );
}
