import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuLinkItem,
  DropdownMenuTrigger,
} from "@betterwispr-frontend/ui/components/dropdown-menu";
import { track } from "@databuddy/sdk";
import { CaretDownIcon, DownloadSimpleIcon } from "@phosphor-icons/react";

import AppleLogo from "@/components/apple-logo";
import { DOWNLOAD_URL, INTEL_DOWNLOAD_URL } from "@/lib/links";

const DOWNLOADS = [
  { href: DOWNLOAD_URL, chip: "Apple Silicon", macs: "M1 or newer" },
  { href: INTEL_DOWNLOAD_URL, chip: "Intel", macs: "Intel-based Macs" },
];

export default function DownloadCTA({
  compact = false,
}: {
  compact?: boolean;
}) {
  if (compact) {
    return (
      <DropdownMenu>
        <DropdownMenuTrigger className="download-cta group cursor-pointer text-sm">
          <AppleLogo className="size-4" />
          Download
          <CaretDownIcon
            weight="bold"
            className="size-3.5 transition-transform duration-300 ease-fluid group-data-popup-open:rotate-180"
            aria-hidden="true"
          />
        </DropdownMenuTrigger>
        <DropdownMenuContent
          align="end"
          sideOffset={8}
          className="w-60 rounded-xl bg-white p-1 text-zinc-900 shadow-lg ring-zinc-200"
        >
          {DOWNLOADS.map(({ href, chip, macs }) => (
            <DropdownMenuLinkItem
              key={href}
              href={href}
              closeOnClick
              onClick={() => track("download_started")}
              className="cursor-pointer gap-3 rounded-lg px-3 py-2 text-sm focus:bg-zinc-100 focus:text-zinc-900"
            >
              <span className="flex-1">
                <span className="block font-semibold">{chip}</span>
                <span className="block text-xs text-zinc-600">{macs}</span>
              </span>
              <DownloadSimpleIcon className="text-zinc-500" />
            </DropdownMenuLinkItem>
          ))}
        </DropdownMenuContent>
      </DropdownMenu>
    );
  }
  return (
    <div className="inline-flex flex-col items-center gap-3">
      <a
        href={DOWNLOAD_URL}
        onClick={() => track("download_started")}
        className="download-cta text-base"
      >
        <AppleLogo className="size-5" />
        Download for Apple Silicon
      </a>
      <a
        href={INTEL_DOWNLOAD_URL}
        onClick={() => track("download_started")}
        className="text-sm text-zinc-600 underline underline-offset-4 hover:text-zinc-900"
      >
        Download for Intel
      </a>
    </div>
  );
}

export function ClosingCTA() {
  return (
    <section
      className="bg-paper px-6 py-20 text-center"
      aria-labelledby="start-title"
    >
      <p className="eyebrow">Your next thought, in your own words</p>
      <h2
        id="start-title"
        className="mx-auto mt-4 max-w-[680px] text-4xl tracking-tight sm:text-5xl"
      >
        Give your keyboard a break.
      </h2>
      <p className="mx-auto mt-6 max-w-xl text-lg text-zinc-600">
        Local speech models. The apps you already use. A little more room to
        think.
      </p>
      <div className="mt-8">
        <DownloadCTA />
      </div>
      <p className="mt-4 text-sm text-zinc-600">
        macOS 14+ · Apple Silicon recommended · No account in the app
      </p>
    </section>
  );
}
