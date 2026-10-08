import { track } from "@databuddy/sdk";

import AppleLogo from "@/components/apple-logo";
import { DOWNLOAD_URL, GITHUB_URL, INTEL_DOWNLOAD_URL } from "@/lib/links";

export default function DownloadCTA({
  compact = false,
}: {
  compact?: boolean;
}) {
  const primary = (
    <a
      href={compact ? `${GITHUB_URL}/releases/latest` : DOWNLOAD_URL}
      onClick={() => track("download_started")}
      className={`download-cta ${compact ? "text-sm" : "text-base"}`}
    >
      <AppleLogo className={compact ? "size-4" : "size-5"} />
      {compact ? "Download" : "Download for Apple Silicon"}
    </a>
  );
  if (compact) return primary;
  return (
    <div className="inline-flex flex-col items-center gap-3">
      {primary}
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
