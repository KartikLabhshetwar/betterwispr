/** The BetterWispr "w" tile, traced from BrandGlyph in the macOS app. */
export default function BrandMark({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" className={className} aria-hidden>
      <rect x="0.5" y="0.5" width="99" height="99" rx="22.5" fill="#f1efeb" stroke="#14141619" />
      <path
        d="M27.7 37.7C27.5 54.7 32.4 63 38.4 63C45.4 63 51 52.3 50 45.4M72.3 37.7C72.5 54.7 67.6 63 61.6 63C54.6 63 49 52.3 50 45.4"
        fill="none"
        stroke="#141416"
        strokeWidth="8.2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
