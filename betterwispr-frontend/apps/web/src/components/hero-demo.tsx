import { useEffect, useState, type ReactNode } from "react";

const SENTENCE = "Can we move the design review to Thursday at 3?";
const WORDS = SENTENCE.length / 5;
const TYPING_WPM = 40;
const SPEAKING_WPM = 150;
const TRANSCRIBE_MS = 900;
const HOLD_MS = 3500;
const REDUCED_MOTION = "(prefers-reduced-motion: reduce)";

const TYPING_MS = (WORDS / TYPING_WPM) * 60_000;
const SPOKEN_AT = (WORDS / SPEAKING_WPM) * 60_000;
const PASTED_AT = SPOKEN_AT + TRANSCRIBE_MS;
const CYCLE_MS = TYPING_MS + HOLD_MS;
const DICTATION_WPM = Math.round(WORDS / (PASTED_AT / 60_000));

const fract = (value: number) => value - Math.floor(value);
const KEY_WEIGHTS = Array.from(SENTENCE, (_, index) => 0.5 + fract(Math.sin(index * 12.9898) * 43758.5453));
const WEIGHT_SUM = KEY_WEIGHTS.reduce((sum, weight) => sum + weight, 0);
let keyClock = 0;
const KEY_AT = KEY_WEIGHTS.map((weight) => (keyClock += (weight / WEIGHT_SUM) * TYPING_MS));

const BARS = Array.from({ length: 11 }, (_, index) => 1 - Math.abs(index - 5) / 7);

type Phase = "listening" | "transcribing" | "pasted";

const PHASE_LABEL: Record<Phase, string> = {
  listening: "Listening",
  transcribing: "Transcribing",
  pasted: `${DICTATION_WPM} wpm`,
};

/** Hero visual: one sentence typed by hand and dictated with BetterWispr, on a shared clock. */
export default function HeroDemo() {
  const [elapsed, setElapsed] = useState(() => (window.matchMedia(REDUCED_MOTION).matches ? CYCLE_MS - 1 : 0));

  useEffect(() => {
    if (window.matchMedia(REDUCED_MOTION).matches) return;
    const start = performance.now();
    const timer = window.setInterval(() => setElapsed((performance.now() - start) % CYCLE_MS), 50);
    return () => window.clearInterval(timer);
  }, []);

  const typed = KEY_AT.filter((at) => at <= elapsed).length;
  const typingClock = Math.min(elapsed, TYPING_MS);
  const typingWpm = typingClock < 1000 ? 0 : Math.round(typed / 5 / (typingClock / 60_000));
  const phase: Phase = elapsed < SPOKEN_AT ? "listening" : elapsed < PASTED_AT ? "transcribing" : "pasted";

  return (
    <figure
      role="img"
      aria-label={`The same sentence typed by hand at ${TYPING_WPM} words per minute and dictated with BetterWispr at ${DICTATION_WPM} words per minute`}
      className="mx-auto max-w-[880px] rounded-3xl bg-paper px-4 py-12 sm:px-16 sm:py-16"
    >
      <div className="mx-auto flex max-w-xl flex-col gap-6">
        <DemoWindow title="Typing" clock={typingClock} stat={`${typingWpm} wpm`}>
          <SentenceSlot>
            {SENTENCE.slice(0, typed)}
            <Caret />
          </SentenceSlot>
        </DemoWindow>
        <DemoWindow title="BetterWispr" clock={Math.min(elapsed, PASTED_AT)} stat={PHASE_LABEL[phase]}>
          <SentenceSlot>
            {phase === "pasted" && SENTENCE}
            <Caret />
          </SentenceSlot>
          <div className="mt-6 flex h-10 items-center justify-center">
            <Capsule phase={phase} />
          </div>
        </DemoWindow>
      </div>
      <figcaption className="mt-8 text-center text-xs text-zinc-500">
        Simulated at {TYPING_WPM} wpm typing and {SPEAKING_WPM} wpm speaking, with time for transcription.
      </figcaption>
    </figure>
  );
}

function DemoWindow({ title, clock, stat, children }: { title: string; clock: number; stat: string; children: ReactNode }) {
  return (
    <div className="overflow-hidden rounded-xl border border-zinc-200 bg-white text-left shadow-sm">
      <div className="flex items-center gap-2 border-b border-zinc-100 px-4 py-3">
        <span className="mr-2 hidden gap-2 sm:flex">
          <span className="size-3 rounded-full bg-zinc-200" />
          <span className="size-3 rounded-full bg-zinc-200" />
          <span className="size-3 rounded-full bg-zinc-200" />
        </span>
        <span className="text-xs text-zinc-500">{title}</span>
        <span className="ml-auto flex gap-3 font-mono text-xs tabular-nums">
          <span className="text-zinc-400">{(clock / 1000).toFixed(1)}s</span>
          <span className="text-zinc-900">{stat}</span>
        </span>
      </div>
      <div className="p-6">{children}</div>
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

export function Capsule({ phase }: { phase: Phase }) {
  if (phase === "pasted") {
    return <span className="h-2 w-10 rounded-full border border-white/50 bg-black/60" />;
  }
  return (
    <span
      className={`flex h-10 items-center gap-1 rounded-full border border-white/15 bg-[#121212] px-4 shadow-lg shadow-black/20 ${phase === "transcribing" ? "*:opacity-40" : ""}`}
    >
      {BARS.map((envelope, index) => (
        <span
          key={index}
          className="w-1 animate-[wave_1.1s_var(--ease-fluid)_infinite] rounded-full bg-white/95 transition-opacity duration-700 ease-fluid motion-reduce:animate-none"
          style={{ height: `${6 + 18 * envelope}px`, animationDelay: `${index * -0.1}s` }}
        />
      ))}
    </span>
  );
}
