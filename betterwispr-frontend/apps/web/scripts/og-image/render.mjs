import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const chrome =
  process.env.CHROME ??
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const output = fileURLToPath(new URL("../../public/og-image.png", import.meta.url));

execFileSync(chrome, [
  "--headless=new",
  "--disable-gpu",
  "--hide-scrollbars",
  "--allow-file-access-from-files",
  "--force-device-scale-factor=1",
  "--window-size=1730,909",
  "--virtual-time-budget=4000",
  `--screenshot=${output}`,
  new URL("template.html", import.meta.url).href,
], { stdio: "ignore" });

const png = readFileSync(output);
const [width, height] = [png.readUInt32BE(16), png.readUInt32BE(20)];
if (width !== 1730 || height !== 909) {
  throw new Error(`Expected a 1730x909 OG image, got ${width}x${height}`);
}
console.log(`Wrote ${output}`);
