import {
  ArrowRightIcon,
  ClipboardTextIcon,
  CloudSlashIcon,
  CpuIcon,
  CursorTextIcon,
  GithubLogoIcon,
  MicrophoneIcon,
  SealCheckIcon,
  type Icon,
} from "@phosphor-icons/react";
import type { ReactNode } from "react";

import BrandMark from "@/components/brand-mark";
import { Capsule } from "@/components/hero-demo";

type Tile = { title: string; body: string; span: string; visual: ReactNode };

const MODELS = [
  { name: "Apple speech", detail: "Built in" },
  { name: "Parakeet TDT v3", detail: "25 languages", selected: true },
  { name: "Parakeet v2", detail: "English" },
  { name: "Whisper Large v3 Turbo", detail: "WhisperKit" },
];

const REPLACEMENTS = [
  { heard: "better whisper", written: "BetterWispr" },
  { heard: "post gress", written: "Postgres" },
  { heard: "type script", written: "TypeScript" },
];

const PANEL = "rounded-lg bg-white ring-1 ring-zinc-200";

const TILES: Tile[] = [
  {
    title: "Stays on your Mac",
    body: "Speech is transcribed by a model running on your Mac. There is no account, no API key and no cloud fallback. Models download once, then work offline.",
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
    body: "Hold ⌥ Space while you speak and let go to finish. Prefer a toggle? Switch to press to toggle in Settings.",
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
    body: "Apple speech, Parakeet for 25 European languages or English, and Whisper Large v3 Turbo. Switch whenever you like.",
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
    title: "Types where you were",
    body: "The text lands in the app you were using. If paste is blocked, it stays on your clipboard so nothing is lost.",
    span: "lg:col-span-2",
    visual: (
      <div className="flex w-full max-w-64 flex-col items-start gap-2">
        <p className={`w-full p-3 text-xs text-zinc-900 ${PANEL}`}>
          Shipping the export on Friday.
          <span className="ml-0.5 inline-block h-3 w-0.5 translate-y-0.5 bg-ink" />
        </p>
        <span className="flex items-center gap-1 text-xs text-zinc-500">
          <ClipboardTextIcon className="size-4" />
          Also on your clipboard
        </span>
      </div>
    ),
  },
  {
    title: "Drops the ums",
    body: "English uh, um, er and hmm are removed, along with stutters. Other languages are left as spoken, and history keeps every word.",
    span: "lg:col-span-2",
    visual: (
      <div className="space-y-2 text-sm text-zinc-900">
        <p>
          and <Removed>uh uh</Removed> we can build <Removed>um</Removed> the export
        </p>
        <p>
          Then we can <Removed>we can</Removed> deploy the app
        </p>
      </div>
    ),
  },
  {
    title: "Your vocabulary",
    body: "Add names and terms as hints, and set replacements so the words you use come out the way you spell them.",
    span: "lg:col-span-3",
    visual: (
      <ul className="space-y-2 text-xs">
        {REPLACEMENTS.map(({ heard, written }) => (
          <li key={heard} className="flex items-center gap-2">
            <span className="w-28 rounded-md px-2 py-1 text-zinc-500 ring-1 ring-zinc-200 ring-inset">{heard}</span>
            <ArrowRightIcon className="size-4 text-zinc-400" />
            <span className={`px-2 py-1 font-medium text-zinc-900 ${PANEL}`}>{written}</span>
          </li>
        ))}
      </ul>
    ),
  },
  {
    title: "History you control",
    body: "Dictations are kept on your Mac with both the raw and the corrected text. Turn history off whenever you like.",
    span: "lg:col-span-3",
    visual: (
      <div className={`w-full max-w-72 p-3 text-xs ${PANEL}`}>
        <div className="flex justify-between gap-2 text-zinc-400">
          <span>Today, 9:41</span>
          <span>Parakeet TDT v3</span>
        </div>
        <p className="mt-2 text-sm text-zinc-900">Then we can deploy the app</p>
        <p className="mt-1 text-zinc-400">Raw: Then we can we can deploy the app</p>
      </div>
    ),
  },
  {
    title: "A waveform that fits your voice",
    body: "It learns the room's noise floor and your loudness, so quiet voices fill the bars and steady background noise stays flat.",
    span: "lg:col-span-2",
    visual: <Capsule phase="listening" />,
  },
  {
    title: "Updates you can trust",
    body: "New versions arrive from GitHub Releases through Sparkle and install only when their EdDSA signature matches.",
    span: "lg:col-span-2",
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
    span: "sm:col-span-2 lg:col-span-2",
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
            <p className="mt-2 text-sm text-zinc-500">{body}</p>
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
