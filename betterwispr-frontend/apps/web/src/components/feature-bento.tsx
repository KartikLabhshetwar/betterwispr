import {
  ArrowCounterClockwiseIcon,
  ArrowRightIcon,
  CheckSquareIcon,
  ClipboardTextIcon,
  CloudSlashIcon,
  CpuIcon,
  CursorTextIcon,
  FlameIcon,
  GithubLogoIcon,
  MicrophoneIcon,
  SealCheckIcon,
  SquareIcon,
  type Icon,
} from "@phosphor-icons/react";
import type { ReactNode } from "react";

import BrandMark from "@/components/brand-mark";

type Tile = { title: string; body: string; span: string; visual: ReactNode };

const MODELS = [
  { name: "Apple speech", detail: "Built in" },
  { name: "Parakeet TDT v3", detail: "25 languages", selected: true },
  { name: "Parakeet Japanese", detail: "Japanese" },
  { name: "Whisper Large v3 Turbo", detail: "WhisperKit" },
  { name: "Sarvam AI", detail: "Your API key" },
];

const REPLACEMENTS = [
  { heard: "better whisper", written: "BetterWispr" },
  { heard: "post gress", written: "Postgres", learned: true },
  { heard: "type script", written: "TypeScript" },
];

const MEETING = [
  { speaker: "Me", line: "Can we ship the export on Friday?" },
  { speaker: "Them", line: "Friday works if QA signs off Thursday." },
  { speaker: "Me", line: "Great, I'll tell support today." },
];

const ACTIONS = [
  { task: "QA sign off by Thursday", done: true },
  { task: "Ship the export Friday" },
  { task: "Tell support today" },
];

const STYLE_TABS = ["Personal", "Work", "Email", "Other"];

const COMMANDS = [
  { said: "question mark", typed: "?" },
  { said: "new paragraph", typed: "¶" },
  { said: "scratch that", typed: "⌫" },
];

const STATS = [
  { value: "4,218", label: "words" },
  { value: "137", label: "wpm" },
  { value: "312", label: "words cleaned" },
];

const HEATMAP_DAYS = 7 * 21;
const STREAK_DAYS = 6;
const HEATMAP = Array.from({ length: HEATMAP_DAYS }, (_, day) => {
  if (day >= HEATMAP_DAYS - STREAK_DAYS) return 3 + (day % 2);
  if (day === HEATMAP_DAYS - STREAK_DAYS - 1) return 0;
  return ((day * 1103515245 + 12345) >>> 16) % 5;
});
const HEAT_SHADES = ["bg-zinc-200", "bg-zinc-300", "bg-zinc-400", "bg-zinc-600", "bg-ink"];

const PANEL = "rounded-lg bg-white ring-1 ring-zinc-200";

const TILES: Tile[] = [
  {
    title: "Stays on your Mac",
    body: "Built in models transcribe your speech on your Mac, with no account and no cloud fallback. Models download once, then work offline.",
    span: "sm:col-span-2 lg:col-span-4",
    visual: (
      <div className="flex flex-col items-center gap-4">
        <div className="flex items-center gap-2">
          <FlowStep icon={MicrophoneIcon} label="Your voice" />
          <ArrowRightIcon className="size-4 text-zinc-400" />
          <FlowStep icon={CpuIcon} label="Model on your Mac" />
          <ArrowRightIcon className="size-4 text-zinc-400" />
          <FlowStep icon={CursorTextIcon} label="Text" />
        </div>
        <span className="flex items-center gap-2 text-xs text-zinc-500">
          <CloudSlashIcon className="size-4" />
          Nothing is uploaded
        </span>
      </div>
    ),
  },
  {
    title: "Hold to talk",
    body: "Hold ⌥ Space while you speak and let go to finish. Switch to press to toggle, or record any shortcut with ⌘, ⌥ or ⌃, or an F key.",
    span: "lg:col-span-2",
    visual: (
      <div className="flex flex-col items-center gap-4">
        <div className="flex items-center gap-2 font-mono text-sm text-zinc-900">
          <kbd className="animate-[keypress_2.4s_var(--ease-fluid)_infinite] rounded-lg border border-zinc-200 bg-white px-3 py-2 motion-reduce:animate-none">
            ⌥
          </kbd>
          <span className="text-zinc-400">+</span>
          <kbd className="w-24 animate-[keypress_2.4s_var(--ease-fluid)_infinite] rounded-lg border border-zinc-200 bg-white px-3 py-2 text-center motion-reduce:animate-none">
            Space
          </kbd>
        </div>
        <div className={`flex p-1 text-xs ${PANEL}`}>
          <span className="rounded-md bg-ink px-2 py-1 text-white">Hold to talk</span>
          <span className="px-2 py-1 text-zinc-500">Press to toggle</span>
        </div>
      </div>
    ),
  },
  {
    title: "Pick your model",
    body: "Nine built in models from Apple speech, Parakeet and Whisper. Parakeet covers English, Japanese and 25 European languages, and Whisper covers more. Or choose your own Sarvam AI, Smallest AI or OpenAI compatible API.",
    span: "lg:col-span-2",
    visual: (
      <ul className="w-full max-w-64 space-y-1 text-xs">
        {MODELS.map(({ name, detail, selected }) => (
          <li
            key={name}
            className={`flex items-center justify-between gap-2 rounded-md px-2 py-1 ${selected ? "bg-white text-zinc-900 ring-1 ring-zinc-200" : "text-zinc-500"}`}
          >
            {name}
            <span className="text-zinc-400">{detail}</span>
          </li>
        ))}
      </ul>
    ),
  },
  {
    title: "Meeting notes",
    body: "Notetaker transcribes your mic as Me and other apps as Them, next to your own notes. Apple Intelligence or Ollama then writes the summary, decisions and action items on your Mac.",
    span: "sm:col-span-2 lg:col-span-4",
    visual: (
      <div className="flex w-full max-w-lg items-center gap-3">
        <ul className="flex-1 space-y-2 text-xs">
          {MEETING.map(({ speaker, line }) => (
            <li key={line} className="flex gap-2">
              <span className={`w-10 shrink-0 font-medium ${speaker === "Me" ? "text-zinc-900" : "text-zinc-500"}`}>{speaker}</span>
              <span className="text-zinc-600">{line}</span>
            </li>
          ))}
        </ul>
        <div className={`hidden w-48 shrink-0 p-3 text-xs sm:block ${PANEL}`}>
          <p className="font-medium text-zinc-900">Action items</p>
          <ul className="mt-2 space-y-1 text-zinc-600">
            {ACTIONS.map(({ task, done }) => (
              <li key={task} className="flex items-center gap-1">
                {done ? <CheckSquareIcon weight="fill" className="size-4 text-zinc-900" /> : <SquareIcon className="size-4 text-zinc-400" />}
                {task}
              </li>
            ))}
          </ul>
        </div>
      </div>
    ),
  },
  {
    title: "A style for every app",
    body: "Set a tone for personal chats, work apps, email and everything else. Casual drops the final period, very casual drops capitals too, and formal leaves your words alone. Tones apply to English.",
    span: "lg:col-span-3",
    visual: (
      <div className="flex w-full max-w-72 flex-col gap-3">
        <div className={`flex p-1 text-xs ${PANEL}`}>
          {STYLE_TABS.map((tab, index) => (
            <span key={tab} className={`flex-1 rounded-md px-2 py-1 text-center ${index === 0 ? "bg-ink text-white" : "text-zinc-500"}`}>
              {tab}
            </span>
          ))}
        </div>
        <p className={`p-3 text-sm text-zinc-900 ${PANEL}`}>
          hey are you around for dinner tonight? let's do 7 if that works for you
        </p>
        <span className="text-xs text-zinc-500">Very casual in Messages</span>
      </div>
    ),
  },
  {
    title: "Cleanup you choose",
    body: "Light, the default, drops English ums, repeats and false starts. Medium also edits for clarity with your notes model, on your Mac with Apple Intelligence or Ollama. None keeps every word.",
    span: "lg:col-span-3",
    visual: (
      <div className="flex flex-col items-center gap-4">
        <div className={`flex p-1 text-xs ${PANEL}`}>
          {["None", "Light", "Medium"].map((level) => (
            <span key={level} className={`rounded-md px-2 py-1 ${level === "Light" ? "bg-ink text-white" : "text-zinc-500"}`}>
              {level}
            </span>
          ))}
        </div>
        <div className="space-y-2 text-sm text-zinc-900">
          <p>
            and <Removed>uh uh</Removed> we can build <Removed>um</Removed> the export
          </p>
          <p>
            Then we can <Removed>we can</Removed> deploy the app
          </p>
        </div>
      </div>
    ),
  },
  {
    title: "Voice commands",
    body: "Say comma, question mark or new paragraph as you talk. Say scratch that to delete the last sentence. Works in English.",
    span: "lg:col-span-2",
    visual: (
      <ul className="space-y-2 text-xs">
        {COMMANDS.map(({ said, typed }) => (
          <li key={said} className="flex items-center gap-2">
            <span className="w-28 rounded-md px-2 py-1 text-zinc-500 ring-1 ring-zinc-200 ring-inset">{said}</span>
            <ArrowRightIcon className="size-4 text-zinc-400" />
            <span className={`w-8 py-1 text-center font-mono font-medium text-zinc-900 ${PANEL}`}>{typed}</span>
          </li>
        ))}
      </ul>
    ),
  },
  {
    title: "Learns your words",
    body: "Add names and terms as hints and replacements. Fix a word in History, or right after a paste, and BetterWispr learns it.",
    span: "lg:col-span-2",
    visual: (
      <ul className="space-y-2 text-xs">
        {REPLACEMENTS.map(({ heard, written, learned }) => (
          <li key={heard} className="flex items-center gap-2">
            <span className="w-28 rounded-md px-2 py-1 text-zinc-500 ring-1 ring-zinc-200 ring-inset">{heard}</span>
            <ArrowRightIcon className="size-4 text-zinc-400" />
            <span className={`px-2 py-1 font-medium text-zinc-900 ${PANEL}`}>{written}</span>
            {learned && <span className="rounded-full bg-ink px-2 py-0.5 text-white">Learned</span>}
          </li>
        ))}
      </ul>
    ),
  },
  {
    title: "Types where you were",
    body: "The text lands in the app you were using. If paste is blocked, it is copied to your clipboard so nothing is lost.",
    span: "lg:col-span-2",
    visual: (
      <div className="flex w-full max-w-64 flex-col items-start gap-2">
        <p className={`w-full p-3 text-xs text-zinc-900 ${PANEL}`}>
          Shipping the export on Friday.
          <span className="ml-0.5 inline-block h-3 w-0.5 translate-y-0.5 bg-ink" />
        </p>
        <span className="flex items-center gap-1 text-xs text-zinc-500">
          <ClipboardTextIcon className="size-4" />
          Copied if paste is blocked
        </span>
      </div>
    ),
  },
  {
    title: "History you control",
    body: "Dictations stay on your Mac with the raw and the corrected text. Use Original brings back exactly what you said, and history turns off whenever you like.",
    span: "lg:col-span-2",
    visual: (
      <div className={`w-full max-w-72 p-3 text-xs ${PANEL}`}>
        <div className="flex justify-between gap-2 text-zinc-400">
          <span>Today, 9:41</span>
          <span>Parakeet TDT v3</span>
        </div>
        <p className="mt-2 text-sm text-zinc-900">Then we can deploy the app</p>
        <p className="mt-1 text-zinc-400">Raw: Then we can we can deploy the app</p>
        <span className="mt-3 inline-flex items-center gap-1 rounded-md px-2 py-1 text-zinc-900 ring-1 ring-zinc-200 ring-inset">
          <ArrowCounterClockwiseIcon className="size-4" />
          Use Original
        </span>
      </div>
    ),
  },
  {
    title: "Insights",
    body: "See how many words you have spoken, your pace, the words cleanup saved you, which apps you dictate into and your daily streak. All of it is counted from history on your Mac.",
    span: "sm:col-span-2 lg:col-span-4",
    visual: (
      <div className="flex w-full max-w-lg flex-col gap-4">
        <div className="flex items-end justify-between gap-4">
          {STATS.map(({ value, label }) => (
            <p key={label} className="text-xs text-zinc-500">
              <span className="block font-mono text-xl text-zinc-900">{value}</span>
              {label}
            </p>
          ))}
          <p className="flex items-center gap-1 text-xs text-zinc-900">
            <FlameIcon weight="fill" className="size-4 text-orange-500" />
            {STREAK_DAYS} day streak
          </p>
        </div>
        <div className="grid grid-flow-col grid-rows-7 gap-0.5 self-start">
          {HEATMAP.map((level, day) => (
            <span key={day} className={`size-2 rounded-sm ${HEAT_SHADES[level]}`} />
          ))}
        </div>
      </div>
    ),
  },
  {
    title: "Updates you can trust",
    body: "New versions arrive from GitHub Releases through Sparkle and install only when their EdDSA signature matches.",
    span: "lg:col-span-3",
    visual: (
      <div className={`flex w-full max-w-64 items-center gap-3 p-3 text-xs ${PANEL}`}>
        <BrandMark className="size-8" />
        <div>
          <p className="font-medium text-zinc-900">Update available</p>
          <p className="mt-1 flex items-center gap-1 text-zinc-500">
            <SealCheckIcon weight="fill" className="size-4 text-emerald-600" />
            Signature verified
          </p>
        </div>
      </div>
    ),
  },
  {
    title: "Free and open source",
    body: "Apache 2.0 licensed. Read every line on GitHub, report an issue, or build it yourself with make dev.",
    span: "lg:col-span-3",
    visual: (
      <div className="flex flex-col items-center gap-2 text-zinc-900">
        <GithubLogoIcon className="size-10" />
        <span className="font-mono text-sm">Apache 2.0</span>
      </div>
    ),
  },
];

/** Feature grid for the home page, one tile per shipped capability. */
export default function FeatureBento() {
  return (
    <div className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-6">
      {TILES.map(({ title, body, span, visual }) => (
        <article key={title} className={`flex flex-col rounded-2xl border border-zinc-200 bg-white p-2 ${span}`}>
          <div aria-hidden className="flex h-44 items-center justify-center overflow-hidden rounded-lg bg-paper px-4">
            {visual}
          </div>
          <div className="p-4">
            <h3 className="text-base font-medium text-zinc-900">{title}</h3>
            <p className="mt-2 text-sm text-pretty text-zinc-500">{body}</p>
          </div>
        </article>
      ))}
    </div>
  );
}

function FlowStep({ icon: StepIcon, label }: { icon: Icon; label: string }) {
  return (
    <span className="flex items-center gap-2 rounded-full bg-white p-3 text-xs text-zinc-900 ring-1 ring-zinc-200 sm:px-3 sm:py-2">
      <StepIcon className="size-4" />
      <span className="hidden sm:inline">{label}</span>
    </span>
  );
}

function Removed({ children }: { children: ReactNode }) {
  return <del className="text-zinc-400 decoration-zinc-400">{children}</del>;
}
