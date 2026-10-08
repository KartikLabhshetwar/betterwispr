/*!
 * Adapted from https://chanhdai.com/components/github-stars
 * MIT License
 * Copyright (c) 2026 Chánh Đại
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import { Button } from "@betterwispr-frontend/ui/components/button";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@betterwispr-frontend/ui/components/tooltip";

export type GitHubStarsProps = {
  /** GitHub repository in `owner/repo` format. */
  repo: string;
  /** Number of stars to display, or undefined while unknown. */
  stargazersCount?: number;
  /**
   * Optional locales for number formatting.
   * See [MDN - Intl - locales argument](https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Intl#locales_argument).
   * @defaultValue "en-US"
   */
  locales?: Intl.LocalesArgument;
};

export function GitHubStars({
  repo,
  stargazersCount,
  locales = "en-US",
}: GitHubStarsProps) {
  const starLabel =
    stargazersCount === undefined
      ? undefined
      : `${new Intl.NumberFormat(locales).format(stargazersCount)} ${stargazersCount === 1 ? "star" : "stars"}`;

  return (
    <TooltipProvider>
      <Tooltip>
        <TooltipTrigger
          render={
            <Button
              className="gap-1.5 pr-1.5 pl-2"
              variant="ghost"
              nativeButton={false}
              role="link"
              render={
                <a
                  href={`https://github.com/${repo}`}
                  target="_blank"
                  rel="noopener"
                  aria-label={
                    starLabel
                      ? `Star ${repo} on GitHub (${starLabel})`
                      : `Star ${repo} on GitHub`
                  }
                />
              }
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path
                  d="M12 0C5.37 0 0 5.372 0 11.997 0 17.3 3.438 21.795 8.205 23.38c.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.725-4.042-1.609-4.042-1.609C4.422 17.77 3.633 17.4 3.633 17.4c-1.087-.744.084-.73.084-.73 1.205.085 1.838 1.237 1.838 1.237 1.07 1.834 2.809 1.304 3.495.997.108-.775.417-1.304.76-1.604-2.665-.3-5.466-1.332-5.466-5.929 0-1.31.465-2.38 1.235-3.219-.135-.303-.54-1.523.105-3.175 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.4 3-.405 1.02.006 2.04.138 3 .404 2.28-1.551 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.608-2.805 5.623-5.475 5.918.42.36.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.284 0 .315.21.69.825.57C20.565 21.79 24 17.291 24 11.997 24 5.372 18.627 0 12 0"
                  fill="currentColor"
                />
              </svg>

              <span
                className="text-[0.8125rem]/none text-muted-foreground tabular-nums"
                style={{ textBox: "trim-end cap alphabetic" }}
              >
                {stargazersCount !== undefined &&
                  new Intl.NumberFormat(locales, {
                    notation: "compact",
                    compactDisplay: "short",
                  })
                    .format(stargazersCount)
                    .toLowerCase()}
              </span>
            </Button>
          }
        />

        <TooltipContent className="tabular-nums">
          {starLabel ?? "Star on GitHub"}
        </TooltipContent>
      </Tooltip>
    </TooltipProvider>
  );
}
