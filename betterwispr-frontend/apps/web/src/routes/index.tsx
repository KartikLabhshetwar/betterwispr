import { createFileRoute } from "@tanstack/react-router";

import AppleLogo from "@/components/apple-logo";
import FeatureBento from "@/components/feature-bento";
import HeroDemo from "@/components/hero-demo";
import StarOnGithub from "@/components/star-on-github";
import { DOWNLOAD_URL } from "@/lib/links";

export const Route = createFileRoute("/")({
  component: HomeComponent,
});

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
        <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
          <a
            href={DOWNLOAD_URL}
            className="flex items-center gap-2 rounded-lg bg-ink px-3 py-2 text-base font-semibold text-white transition-all duration-700 ease-fluid hover:bg-zinc-700 active:scale-[0.98]"
          >
            <AppleLogo className="size-5" />
            Download for macOS
          </a>
          <StarOnGithub />
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
        <FeatureBento />
      </section>
    </>
  );
}
