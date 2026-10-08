import { ListIcon, XIcon } from "@phosphor-icons/react";
import { Link } from "@tanstack/react-router";
import { useRef, useState } from "react";
import BrandMark from "@/components/brand-mark";
import DownloadCTA from "@/components/download-cta";
import StarOnGithub from "@/components/star-on-github";
import { GITHUB_URL } from "@/lib/links";

export default function Header() {
  const [menuOpen, setMenuOpen] = useState(false);
  const menuButton = useRef<HTMLButtonElement>(null);

  return (
    <header className="sticky top-0 z-50 border-b border-zinc-200 bg-white/95 backdrop-blur-xl">
      <nav
        aria-label="Main navigation"
        className="page-shell flex min-h-16 flex-wrap items-center justify-between gap-2 py-3"
        onKeyDown={(event) => {
          if (event.key === "Escape" && menuOpen) {
            setMenuOpen(false);
            menuButton.current?.focus();
          }
        }}
        onBlur={(event) => {
          if (
            event.relatedTarget &&
            !event.currentTarget.contains(event.relatedTarget)
          ) {
            setMenuOpen(false);
          }
        }}
        onClick={(event) => {
          if (menuOpen && (event.target as Element).closest("a")) {
            setMenuOpen(false);
            menuButton.current?.focus();
          }
        }}
      >
        <Link
          to="/"
          className="flex items-center gap-2 rounded-lg text-sm font-semibold text-zinc-900"
        >
          <BrandMark className="size-8" />
          BetterWispr
        </Link>
        <button
          ref={menuButton}
          type="button"
          aria-label={menuOpen ? "Close menu" : "Open menu"}
          aria-expanded={menuOpen}
          aria-controls="navigation-links"
          onClick={() => setMenuOpen(!menuOpen)}
          className="flex size-11 items-center justify-center rounded-lg text-zinc-900 hover:bg-zinc-100 sm:hidden"
        >
          {menuOpen ? (
            <XIcon className="size-6" aria-hidden="true" />
          ) : (
            <ListIcon className="size-6" aria-hidden="true" />
          )}
        </button>
        <div
          id="navigation-links"
          className={`${menuOpen ? "flex" : "hidden"} basis-full flex-col items-stretch gap-1 border-t border-zinc-200 pt-3 pb-1 sm:flex sm:basis-auto sm:flex-row sm:items-center sm:gap-4 sm:border-0 sm:p-0`}
        >
          <Link
            to="/compare"
            activeProps={{
              className: "text-zinc-950 underline underline-offset-4",
            }}
            className="rounded-lg px-3 py-3 text-base text-zinc-600 hover:bg-zinc-50 hover:text-zinc-900 sm:px-0 sm:py-2 sm:text-sm sm:hover:bg-transparent"
          >
            Compare
          </Link>
          <Link
            to="/changelog"
            activeProps={{
              className: "text-zinc-950 underline underline-offset-4",
            }}
            className="rounded-lg px-3 py-3 text-base text-zinc-600 hover:bg-zinc-50 hover:text-zinc-900 sm:px-0 sm:py-2 sm:text-sm sm:hover:bg-transparent"
          >
            Changelog
          </Link>
          <a
            href={GITHUB_URL}
            className="rounded-lg px-3 py-3 text-base text-zinc-600 hover:bg-zinc-50 hover:text-zinc-900 sm:hidden"
          >
            GitHub
          </a>
          <div className="hidden sm:block">
            <StarOnGithub compact />
          </div>
          <div className="flex justify-center pt-3 sm:hidden">
            <DownloadCTA />
          </div>
          <div className="hidden sm:block">
            <DownloadCTA compact />
          </div>
        </div>
      </nav>
    </header>
  );
}
