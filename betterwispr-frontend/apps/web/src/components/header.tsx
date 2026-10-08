import { Link } from "@tanstack/react-router";
import BrandMark from "@/components/brand-mark";
import DownloadCTA from "@/components/download-cta";
import StarOnGithub from "@/components/star-on-github";

export default function Header() {
  return (
    <header className="sticky top-0 z-50 border-b border-zinc-200 bg-white/95 backdrop-blur-xl">
      <nav
        aria-label="Main navigation"
        className="page-shell flex min-h-16 flex-wrap items-center justify-between gap-2 py-3"
      >
        <Link
          to="/"
          className="flex items-center gap-2 rounded-lg text-sm font-semibold text-zinc-900"
        >
          <BrandMark className="size-8" />
          BetterWispr
        </Link>
        <div className="flex items-center gap-2 sm:gap-4">
          <Link
            to="/compare"
            activeProps={{
              className: "text-zinc-950 underline underline-offset-4",
            }}
            className="rounded-lg py-2 text-sm text-zinc-600 hover:text-zinc-900"
          >
            Compare
          </Link>
          <Link
            to="/changelog"
            activeProps={{
              className: "text-zinc-950 underline underline-offset-4",
            }}
            className="hidden rounded-lg py-2 text-sm text-zinc-600 hover:text-zinc-900 sm:block"
          >
            Changelog
          </Link>
          <div className="hidden sm:block">
            <StarOnGithub compact />
          </div>
          <DownloadCTA compact />
        </div>
      </nav>
    </header>
  );
}
