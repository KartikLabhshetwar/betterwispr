import { SparkleIcon, StarIcon } from "@phosphor-icons/react";
import { useEffect, useState } from "react";

import { GITHUB_API_URL, GITHUB_URL } from "@/lib/links";

const COUNT_UP_MS = 1200;
const REDUCED_MOTION = "(prefers-reduced-motion: reduce)";
const COMPACT = new Intl.NumberFormat("en", { notation: "compact", maximumFractionDigits: 1 });
const SPARKLES = [
  { position: "-top-2 -right-2", delay: "0s" },
  { position: "-bottom-1 -left-2", delay: "0.2s" },
  { position: "-top-2 -left-1", delay: "0.4s" },
];

type Stars = { status: "loading" } | { status: "ready"; count: number } | { status: "failed" };

/** Secondary hero action: a twinkling star and the live GitHub star count. */
export default function StarOnGithub() {
  const [stars, setStars] = useState<Stars>({ status: "loading" });
  const [shown, setShown] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    fetch(GITHUB_API_URL, { signal: controller.signal, headers: { Accept: "application/vnd.github+json" } })
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error(`GitHub ${response.status}`))))
      .then(({ stargazers_count }: { stargazers_count?: unknown }) =>
        setStars(
          typeof stargazers_count === "number" ? { status: "ready", count: stargazers_count } : { status: "failed" },
        ),
      )
      .catch(() => {
        if (!controller.signal.aborted) setStars({ status: "failed" });
      });
    return () => controller.abort();
  }, []);

  useEffect(() => {
    if (stars.status !== "ready") return;
    if (window.matchMedia(REDUCED_MOTION).matches) {
      setShown(stars.count);
      return;
    }
    const start = performance.now();
    let frame = requestAnimationFrame(function tick(now) {
      const progress = Math.min((now - start) / COUNT_UP_MS, 1);
      setShown(Math.round(stars.count * (1 - (1 - progress) ** 3)));
      if (progress < 1) frame = requestAnimationFrame(tick);
    });
    return () => cancelAnimationFrame(frame);
  }, [stars]);

  return (
    <a
      href={GITHUB_URL}
      className="group flex items-center gap-2 rounded-lg bg-white px-3 py-2 text-base font-semibold text-zinc-900 ring-1 ring-zinc-200 transition-all duration-700 ease-fluid ring-inset hover:bg-zinc-50 hover:ring-zinc-300 active:scale-[0.98]"
    >
      <span className="relative grid size-5 place-items-center transition-transform duration-700 ease-fluid group-hover:scale-125 group-hover:-rotate-12">
        <StarIcon
          weight="fill"
          className="size-5 animate-[twinkle_4s_var(--ease-fluid)_infinite] text-amber-400 motion-reduce:animate-none"
        />
        {SPARKLES.map(({ position, delay }) => (
          <SparkleIcon
            key={position}
            weight="fill"
            className={`absolute size-2.5 animate-[sparkle_4s_var(--ease-fluid)_infinite] text-amber-300 opacity-0 motion-reduce:animate-none ${position}`}
            style={{ animationDelay: delay }}
          />
        ))}
      </span>
      Star on GitHub
      {stars.status === "loading" && <span className="h-6 w-12 animate-pulse rounded-md bg-zinc-100 motion-reduce:animate-none" />}
      {stars.status === "ready" && (
        <span className="min-w-12 rounded-md bg-zinc-100 px-2 text-center font-mono text-sm text-zinc-600 tabular-nums">
          {COMPACT.format(shown)}
          <span className="sr-only"> stars</span>
        </span>
      )}
    </a>
  );
}
