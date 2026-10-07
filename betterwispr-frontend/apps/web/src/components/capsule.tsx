const BARS = Array.from({ length: 11 }, (_, index) => 1 - Math.abs(index - 5) / 7);

/** Hero visual: a dictated sentence landing in a notes window while the recording capsule listens. */
export default function Capsule() {
  return (
    <figure
      role="img"
      aria-label="The BetterWispr capsule listening while a dictated sentence appears in a notes window"
      className="mx-auto flex max-w-[880px] flex-col items-center gap-8 rounded-3xl bg-paper px-6 pt-12 pb-8 sm:px-16 sm:pt-16"
    >
      <div className="w-full max-w-xl overflow-hidden rounded-xl border border-zinc-200 bg-white shadow-sm">
        <div className="flex items-center gap-2 border-b border-zinc-100 px-4 py-3">
          <span className="size-3 rounded-full bg-zinc-200" />
          <span className="size-3 rounded-full bg-zinc-200" />
          <span className="size-3 rounded-full bg-zinc-200" />
          <span className="ml-2 text-xs text-zinc-400">Notes</span>
        </div>
        <div className="space-y-3 px-6 py-8 text-left">
          <p className="text-sm text-zinc-400">Design sync, Tuesday</p>
          <p className="text-base text-zinc-900">
            Can we move the design review to Thursday at 3? I want Priya to see the new capsule first.
            <span className="ml-1 inline-block h-5 w-0.5 translate-y-1 bg-ink" />
          </p>
        </div>
      </div>
      <div className="flex flex-col items-center gap-3">
        <div className="flex h-12 items-center gap-1 rounded-full border border-white/15 bg-[#121212] px-6 shadow-lg shadow-black/20">
          {BARS.map((envelope, index) => (
            <span
              key={index}
              className="w-1 origin-center animate-[wave_1.1s_var(--ease-fluid)_infinite] rounded-full bg-white/95 motion-reduce:animate-none"
              style={{ height: `${8 + 20 * envelope}px`, animationDelay: `${index * -0.1}s` }}
            />
          ))}
        </div>
        <p className="text-xs text-zinc-500">
          Holding <kbd className="rounded border border-zinc-300 bg-white px-1 font-sans text-zinc-700">⌥ Space</kbd>
        </p>
      </div>
    </figure>
  );
}
