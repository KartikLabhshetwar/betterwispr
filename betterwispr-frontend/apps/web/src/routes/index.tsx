import { ArrowRightIcon, CheckIcon } from "@phosphor-icons/react";
import { Link, createFileRoute } from "@tanstack/react-router";
import { useEffect, useRef } from "react";
import DownloadCTA, { ClosingCTA } from "@/components/download-cta";
import HeroDemo from "@/components/hero-demo";
import FeatureBento from "@/components/feature-bento";
import StarOnGithub from "@/components/star-on-github";
import { comparisons } from "@/lib/comparisons";
import { pageHead } from "@/lib/seo";

export const Route = createFileRoute("/")({
  component: HomeComponent,
  head: () =>
    pageHead(
      "BetterWispr: local dictation for macOS",
      "Hold a shortcut, speak, and BetterWispr types into your Mac apps. Local speech models, vocabulary and history. Free, with no account required.",
      "/",
    ),
});

const FAQS = [
  [
    "Is BetterWispr free?",
    "Yes. BetterWispr has no dictation subscription, account or API key requirement. Model files use storage on your Mac.",
  ],
  [
    "Which Macs does it support?",
    "BetterWispr requires macOS 14 or later. Apple Silicon is recommended for local model inference. Model availability and performance depend on your hardware and language.",
  ],
  [
    "Does it work without internet?",
    "Yes, once a compatible local model and its required assets are installed. Downloadable models need an explicit installation first. Apple on device speech also depends on supported languages and OS assets. There is no cloud transcription fallback.",
  ],
  [
    "How do I dictate?",
    "Focus a text field, hold Option + Space, speak, and release to transcribe. You can switch to press to toggle in Settings. Transcription begins after recording stops, rather than appearing word by word while you talk.",
  ],
  [
    "Why does it need permissions?",
    "Microphone permission lets BetterWispr record your voice. Accessibility permission allows automatic insertion into another app. Apple speech also requires Speech Recognition permission. You control these in System Settings.",
  ],
  [
    "What if automatic paste does not work?",
    "BetterWispr checks the target app before inserting text. If it cannot safely paste, retrieve the transcript from the dashboard and copy it yourself. Secure fields and some apps may block automatic insertion.",
  ],
  [
    "Which languages are supported?",
    "Language support depends on the selected model. Parakeet TDT v3 covers 25 European languages; Whisper offers broader multilingual recognition. Apple speech depends on your locale and installed assets. Test your chosen model with your own speech.",
  ],
  [
    "Does it rewrite everything I say?",
    "BetterWispr applies local transcript cleanup and your configured replacements. It keeps raw and corrected text distinct in history. It does not send your words to a cloud writing service.",
  ],
];

function HomeComponent() {
  return (
    <>
      <section className="page-shell pt-16 pb-12 text-center sm:pt-24">
        <p className="eyebrow">A little less typing. A little more thinking.</p>
        <h1 className="mx-auto mt-6 max-w-[680px] bg-linear-to-r from-black to-[#666666] bg-clip-text text-5xl tracking-tight text-transparent sm:text-7xl">
          Hold to talk.
          <br />
          Release to type.
        </h1>
        <p className="mx-auto mt-6 max-w-[680px] text-lg text-zinc-600">
          Your thoughts, in the app you’re already using. Hold{" "}
          <kbd className="whitespace-nowrap font-medium text-zinc-900">
            ⌥ Space
          </kbd>
          , speak naturally, and let BetterWispr do the typing. Speech stays on
          your Mac.
        </p>
        <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
          <DownloadCTA />
          <StarOnGithub />
        </div>
        <p className="mt-4 text-sm text-zinc-500">
          Free · macOS 14+ · Apple Silicon recommended
        </p>
        <ul
          className="mt-8 flex flex-wrap justify-center gap-x-6 gap-y-2 text-sm text-zinc-600"
          aria-label="Product essentials"
        >
          {["No account", "Local speech models", "Your vocabulary"].map(
            (text) => (
              <li key={text} className="flex items-center gap-2">
                <CheckIcon className="size-4" />
                {text}
              </li>
            ),
          )}
        </ul>
      </section>
      <section className="page-shell pb-20">
        <HeroDemo />
      </section>

      <section aria-labelledby="features" className="page-shell pb-24">
        <h2
          id="features"
          className="mx-auto max-w-[680px] text-center text-3xl tracking-tight text-zinc-900"
        >
          Speak instead of typing, in any app on your Mac
        </h2>
        <FeatureBento />
      </section>

      <section
        id="how-it-works"
        className="page-shell pb-24"
        aria-labelledby="how-title"
      >
        <div className="grid gap-8 border-t border-zinc-200 pt-12 md:grid-cols-[1fr_2fr]">
          <div>
            <p className="eyebrow">From thought to text</p>
            <h2 id="how-title" className="mt-4 text-3xl tracking-tight">
              One shortcut.
              <br />
              Your everyday apps.
            </h2>
          </div>
          <ol className="grid gap-8 sm:grid-cols-3">
            {[
              [
                "Set up once",
                "Install BetterWispr, allow the needed permissions, and choose a local speech model.",
              ],
              [
                "Hold and speak",
                "Place your cursor in a text field. Hold Option + Space and say what you want to write.",
              ],
              [
                "Release to type",
                "Let go to transcribe. Your words arrive in the app you were using, ready to review.",
              ],
            ].map(([title, body], index) => (
              <li key={title}>
                <span className="font-mono text-sm text-zinc-400">
                  0{index + 1}
                </span>
                <h3 className="mt-4 text-base font-semibold">{title}</h3>
                <p className="mt-3 text-sm text-zinc-600">{body}</p>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="bg-paper py-20" aria-labelledby="local-title">
        <div className="page-shell grid items-start gap-12 md:grid-cols-2">
          <div>
            <p className="eyebrow">Local by design</p>
            <Tagline />
          </div>
          <div>
            <p className="mt-6 max-w-lg text-base text-zinc-600">
              Models run on your Mac. Downloads happen when you choose to
              install them. Your speech doesn’t need a round trip to a
              transcription server.
            </p>
            <Link
              to="/privacy"
              className="mt-6 inline-flex items-center gap-2 text-sm font-semibold hover:text-zinc-600"
            >
              How your data is handled
              <ArrowRightIcon />
            </Link>
          </div>
        </div>
      </section>

      <section className="page-shell py-24" aria-labelledby="compare-title">
        <div className="flex flex-col justify-between gap-6 sm:flex-row sm:items-end">
          <div>
            <p className="eyebrow">Choose with context</p>
            <h2
              id="compare-title"
              className="mt-4 text-3xl tracking-tight sm:text-4xl"
            >
              Your voice. Your call.
            </h2>
            <p className="mt-4 max-w-xl text-base text-zinc-600">
              There’s more than one good dictation app. Compare local
              processing, offline use and writing workflows before you choose.
            </p>
          </div>
          <Link
            to="/compare"
            className="inline-flex shrink-0 items-center gap-2 text-sm font-semibold hover:text-zinc-600"
          >
            All comparisons
            <ArrowRightIcon />
          </Link>
        </div>
        <div className="mt-8 border-t border-zinc-200">
          {comparisons.slice(0, 4).map((item) => (
            <Link
              key={item.slug}
              to="/compare/$slug"
              params={{ slug: item.slug }}
              className="group flex items-center justify-between gap-4 border-b border-zinc-200 py-6 transition-colors duration-700 ease-fluid hover:bg-zinc-50"
            >
              <div>
                <h3 className="text-lg font-medium">
                  BetterWispr vs {item.name}
                </h3>
                <p className="mt-2 text-sm text-zinc-600">{item.summary}</p>
              </div>
              <ArrowRightIcon className="size-5 shrink-0 transition-transform duration-700 ease-fluid group-hover:translate-x-1" />
            </Link>
          ))}
        </div>
      </section>

      <section className="page-shell pb-24" aria-labelledby="faq-title">
        <div className="grid gap-8 md:grid-cols-[1fr_2fr]">
          <div>
            <p className="eyebrow">Before you download</p>
            <h2 id="faq-title" className="mt-4 text-3xl tracking-tight">
              A few good questions.
            </h2>
          </div>
          <div className="border-t border-zinc-200">
            {FAQS.map(([question, answer]) => (
              <details
                key={question}
                className="group border-b border-zinc-200 py-6"
              >
                <summary className="cursor-pointer text-base font-medium marker:text-zinc-400 hover:text-zinc-600">
                  {question}
                </summary>
                <p className="mt-4 text-base text-zinc-600">{answer}</p>
              </details>
            ))}
          </div>
        </div>
      </section>
      <ClosingCTA />
    </>
  );
}

function Tagline() {
  const ref = useRef<HTMLHeadingElement>(null);
  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const words = ref.current?.querySelectorAll("span");
    const observer = new IntersectionObserver(
      (entries) => {
        if (!entries.some((entry) => entry.isIntersecting)) return;
        words?.forEach((word, index) => {
          word.style.transitionDelay = `${index * 90}ms`;
          word.style.opacity = "1";
        });
        observer.disconnect();
      },
      { threshold: 0.6 },
    );
    words?.forEach((word) => {
      word.style.opacity = "0.3";
    });
    if (ref.current) observer.observe(ref.current);
    return () => observer.disconnect();
  }, []);
  return (
    <h2
      id="local-title"
      ref={ref}
      className="mt-6 max-w-[680px] text-4xl tracking-tight sm:text-5xl"
    >
      {"Your words stay ".split(" ").map((word, index) => (
        <span
          key={index}
          className="transition-opacity duration-700 ease-fluid"
        >
          {word}{" "}
        </span>
      ))}
      <br />
      {"on your Mac.".split(" ").map((word, index) => (
        <span
          key={index}
          className="transition-opacity duration-700 ease-fluid"
        >
          {word}{" "}
        </span>
      ))}
    </h2>
  );
}
