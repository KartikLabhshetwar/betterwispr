export const SITE_URL = "https://betterwispr.com";

export function pageHead(title: string, description: string, path: string) {
  return {
    meta: [
      { title },
      { name: "description", content: description },
      { property: "og:title", content: title },
      { property: "og:description", content: description },
      { property: "og:url", content: `${SITE_URL}${path}` },
    ],
    links: [{ rel: "canonical", href: `${SITE_URL}${path}` }],
  };
}
