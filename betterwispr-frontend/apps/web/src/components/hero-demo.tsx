import { useEffect, useState, type ReactNode } from "react";

const SENTENCE = "Can we move the design review to Thursday at 3? I want Priya to see the new capsule first.";
const TYPING_WPM = 40;
const SPEAKING_WPM = 150;
const TRANSCRIBE_MS = 900;
const HOLD_MS = 3500;

const minutesFor = (wpm: number) => SENTENCE.length / 5 / wpm;
const SPOKEN_AT = minutesFor(SPEAKING_WPM) * 60_000;
const PASTED_AT = SPOKEN_AT + TRANSCRIBE_MS;
const CYCLE_MS = PASTED_AT + HOLD_MS;
const DICTATION_WPM = Math.round(SENTENCE.length / 5 / (PASTED_AT / 60_000));

const jitter = (index: number) => {
  const x = Math.sin(index * 12.9898) * 43758.5453;
  return x - Math.floor(x);
};
const MS_PER_CHAR = (minutesFor(TYPING_WPM) * 60_000) / SENTENCE.length;
let typedTotal = 0;
const TYPED_AT = Array.from(SENTENCE, (_, index) => (typedTotal += MS_PER_CHAR * (0.5 + jitter(index))));

const BARS = Array.from({ length: 11 }, (_, index) => 1 - Math.abs(index - 5) / 7);

type Phase = "listening" | "transcribing" | "pasted";

/** Hero visual: the same sentence typed by hand and dictated with BetterWispr, on one shared clock. */
export default function HeroDemo() {
  const [elapsed, setElapsed] = useState(() =>
    window.matchMedia("(prefers-reduced-motion: reduce)").matches ? CYCLE_MS - 1 : 0,
  );

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const start = performance.now();
    const timer = window.setInterval(() => setElapsed((performance.now() - start) % CYCLE_MS), 50);
    return () => window.clearInterval(timer);
  }, []);

  const typed = TYPED_AT.filter((at) => at <= elapsed).length;
  const typingWpm = elapsed < 1000 ? 0 : Math.round(typed / 5 / (elapsed / 60_000));
  const phase: Phase = elapsed < SPOKEN_AT ? "listening" : elapsed < PASTED_AT ? "transcribing" : "pasted";

  return (
    <figure
      role="img"
      aria-label={`The same sentence typed by hand at about ${TYPING_WPM} words per minute and dictated with BetterWispr at about ${DICTATION_WPM} words per minute`}
      className="mx-auto max-w-[880px] rounded-3xl bg-paper px-6 py-12 sm:px-16 sm:py-16"
    >
      <div className="mx-auto flex max-w-xl flex-col gap-6">
        <DemoWindow label="Typing by hand" stat={`${typingWpm} wpm`}>
          <SentenceSlot>
            {SENTENCE.slice(0, typed)}
            <Caret />
          </SentenceSlot>
        </DemoWindow>
        <DemoWindow
          label="Dictating with BetterWispr"
          stat={phase === "listening" ? "Listening" : phase === "transcribing" ? "Transcribing" : `${DICTATION_WPM} wpm`}
        >
          <SentenceSlot>
            {phase === "pasted" && SENTENCE}
            <Caret />
          </SentenceSlot>
          <div className="mt-6 flex h-12 items-center justify-center">
            <Capsule phase={phase} />
          </div>
        </DemoWindow>
      </div>
      <figcaption className="mt-8 text-center text-xs text-zinc-500">
        Simulated at {TYPING_WPM} wpm typing and {SPEAKING_WPM} wpm speaking, including transcription time.
      </figcaption>
    </figure>
  );
}

function DemoWindow({ label, stat, children }: { label: string; stat: string; children: ReactNode }) {
  return (
    <div className="overflow-hidden rounded-xl border border-zinc-200 bg-white text-left shadow-sm">
      <div className="flex items-center gap-2 border-b border-zinc-100 px-4 py-3">
        <span className="size-3 rounded-full bg-zinc-200" />
        <span className="size-3 rounded-full bg-zinc-200" />
        <span className="size-3 rounded-full bg-zinc-200" />
        <span className="ml-2 text-xs text-zinc-500">{label}</span>
        <span className="ml-auto font-mono text-xs text-zinc-900 tabular-nums">{stat}</span>
      </div>
      <div className="px-6 py-6">{children}</div>
    </div>
  );
}

function SentenceSlot({ children }: { children: ReactNode }) {
  return (
    <p className="grid text-base text-zinc-900">
      <span className="invisible col-start-1 row-start-1">
        {SENTENCE}
        <Caret />
      </span>
      <span className="col-start-1 row-start-1">{children}</span>
    </p>
  );
}

function Caret() {
  return <span className="ml-0.5 inline-block h-5 w-0.5 translate-y-1 bg-ink" />;
}

function Capsule({ phase }: { phase: Phase }) {
  if (phase === "pasted") {
    return <span className="h-3 w-14 rounded-full border border-white/50 bg-black/60" />;
  }
  return (
    <span className="flex h-12 items-center gap-1 rounded-full border border-white/15 bg-[#121212] px-6 shadow-lg shadow-black/20">
      {BARS.map((envelope, index) => (
        <span
          key={index}
          className={`w-1 animate-[wave_1.1s_var(--ease-fluid)_infinite] rounded-full motion-reduce:animate-none ${phase === "listening" ? "bg-white/95" : "bg-white/40"}`}
          style={{ height: `${8 + 20 * envelope}px`, animationDelay: `${index * -0.1}s` }}
        />
      ))}
    </span>
  );
}
