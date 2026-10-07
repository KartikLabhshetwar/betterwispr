import {
  CaretRightIcon,
  ClockCounterClockwiseIcon,
  CpuIcon,
  CursorTextIcon,
  MicrophoneIcon,
  ShieldCheckIcon,
  TextAaIcon,
  type Icon,
} from "@phosphor-icons/react";
import { Link, createFileRoute } from "@tanstack/react-router";

import AppleLogo from "@/components/apple-logo";
import Changelog from "@/components/changelog";
import HeroDemo from "@/components/hero-demo";
import { DOWNLOAD_URL, GITHUB_URL } from "@/lib/links";

export const Route = createFileRoute("/")({
  component: HomeComponent,
});

const FEATURES: { icon: Icon; title: string; body: string }[] = [
  {
    icon: ShieldCheckIcon,
    title: "Stays on your Mac",
    body: "Speech is transcribed by models running on your Mac. There is no account, no API key and no cloud fallback.",
  },
  {
    icon: MicrophoneIcon,
    title: "Hold to talk",
    body: "Hold ⌥ Space while you speak and release to finish. Prefer a toggle? Switch to press to toggle in Settings.",
  },
  {
    icon: CursorTextIcon,
    title: "Types where you were",
    body: "The text is pasted into the app you were using. If paste is blocked, it stays on your clipboard so nothing is lost.",
  },
  {
    icon: CpuIcon,
    title: "Models you choose",
    body: "Apple speech, Parakeet TDT v3 for 25 European languages, or Whisper Large v3 Turbo. Download once, then work offline.",
  },
  {
    icon: TextAaIcon,
    title: "Your vocabulary",
    body: "Add names and terms as hints, and set replacements so the words you use come out the way you spell them.",
  },
  {
    icon: ClockCounterClockwiseIcon,
    title: "History you control",
    body: "Dictations are kept locally with both the raw and the corrected text. Turn history off whenever you like.",
  },
];

function HomeComponent() {
  return (
    <>
      <section className="px-6 pt-24 pb-16 text-center sm:pt-32">
        <p className="text-sm text-zinc-500">Local dictation for Mac</p>
        <h1 className="mx-auto mt-4 max-w-[680px] bg-linear-to-r from-black to-[#666666] bg-clip-text text-5xl tracking-tight text-transparent sm:text-6xl">
          Hold to talk.
          <br />
          Release to type.
        </h1>
        <p className="mx-auto mt-6 max-w-[680px] text-lg text-zinc-500">
          Hold ⌥ Space, say what you mean, and BetterWispr pastes the text into the app you were using. Speech
          stays on your Mac. Free and open source.
        </p>
        <div className="mt-8 flex flex-wrap items-center justify-center gap-6">
          <a
            href={DOWNLOAD_URL}
            className="flex items-center gap-2 rounded-lg bg-ink px-3 py-2 text-base font-semibold text-white transition-all duration-700 ease-fluid hover:bg-zinc-700 active:scale-[0.98]"
          >
            <AppleLogo className="size-5" />
            Download for macOS
          </a>
          <Link
            to="/"
            hash="changelog"
            className="group flex items-center gap-1 rounded-lg text-base text-zinc-600 transition-colors duration-700 ease-fluid hover:text-zinc-900"
          >
            Read the changelog
            <CaretRightIcon className="size-4 transition-transform duration-700 ease-fluid group-hover:translate-x-0.5" />
          </Link>
        </div>
        <p className="mt-6 text-sm text-zinc-400">macOS 14 or later · Apple Silicon recommended · No account</p>
      </section>

      <section className="px-6 pb-24">
        <HeroDemo />
      </section>

      <section aria-labelledby="features" className="reveal mx-auto max-w-[1100px] px-6 pb-24">
        <h2 id="features" className="mx-auto max-w-[680px] text-center text-3xl tracking-tight text-zinc-900">
          Speak instead of typing, in any app on your Mac
        </h2>
        <div className="mt-12 grid gap-px overflow-hidden rounded-2xl border border-zinc-200 bg-zinc-200 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map(({ icon: FeatureIcon, title, body }) => (
            <div key={title} className="bg-white p-8">
              <FeatureIcon className="size-5 text-zinc-900" />
              <h3 className="mt-4 text-base font-medium text-zinc-900">{title}</h3>
              <p className="mt-2 text-sm text-zinc-500">{body}</p>
            </div>
          ))}
        </div>
      </section>

      <section id="changelog" aria-labelledby="changelog-title" className="mx-auto max-w-[680px] scroll-mt-20 px-6 pb-24">
        <h2 id="changelog-title" className="text-3xl tracking-tight text-zinc-900">
          Changelog
        </h2>
        <p className="mt-3 text-base text-zinc-500">
          Every release, rendered from{" "}
          <a
            href={`${GITHUB_URL}/blob/main/CHANGELOG.md`}
            className="text-zinc-900 underline underline-offset-2 hover:text-zinc-600"
          >
            CHANGELOG.md
          </a>{" "}
          in the repository.
        </p>
        <Changelog />
      </section>
    </>
  );
}
