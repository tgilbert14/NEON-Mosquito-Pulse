import crypto from "node:crypto";
import fs from "node:fs";

const cover = fs.readFileSync("docs/index.html", "utf8");
const ui = fs.readFileSync("ui.R", "utf8");
const requiredCover = [
  "mosquito-pulse-poster-v1",
  "What rises after rain?",
  "Follow mosquito activity through rainfall, warmth, and each sampled season.",
  "Choose a field site",
  "Desert Data Labs",
  "NEON-Driver-Cascade",
  "What am I looking at?",
  "assets/mosquito-living-poster-v1.webp",
];
const requiredApp = [
  "mosquito-pulse-v1",
  "living-poster",
  "What rises",
  "after rain?",
  "assets/mosquito-living-poster-v1.webp",
  "NEON-Driver-Cascade",
  "Skip to site picker",
];
for (const value of requiredCover) if (!cover.includes(value)) throw new Error(`cover missing ${value}`);
for (const value of requiredApp) if (!ui.includes(value)) throw new Error(`app poster missing ${value}`);
for (const [source, surface] of [[cover, "Pages"], [ui, "app"]]) {
  for (const label of [
    "Editorial illustration—not a field photograph or data record.",
    "Illustration · not a measurement",
  ]) {
    if (source.includes(label)) throw new Error(`${surface} poster must not restore the visible illustration disclaimer`);
  }
}
if (/<figcaption\b/i.test(cover)) throw new Error("Pages poster must not restore a visible art caption");
if (/tags\$figcaption\s*\(/.test(ui)) throw new Error("app poster must not restore a visible art caption");
const coverFace = cover.match(/<main id="main" class="poster"[^>]*>([\s\S]*?)<\/main>/)?.[1] ?? "";
if (!coverFace) throw new Error("cover face must be the main poster landmark");
if ((coverFace.match(/class="button"/g) ?? []).length !== 1) throw new Error("cover face must have exactly one contextual CTA");
if ((coverFace.match(/NEON-Driver-Cascade/g) ?? []).length !== 1) throw new Error("cover face must have exactly one Driver route");
if (/field-strip|field-stat/.test(coverFace)) throw new Error("cover face must not contain a metric strip");
if (/class="(?:method|truths|truth|boundary)"/.test(cover)) throw new Error("cover must move method detail into the app");
if ((cover.match(/<details class="honesty">/g) ?? []).length !== 1) throw new Error("cover needs one compact honesty disclosure");
if (/<script[^>]+src=["']https?:|<img[^>]+src=["']https?:|<link[^>]+rel=["']stylesheet["'][^>]+href=["']https?:/i.test(cover)) throw new Error("cover has remote runtime asset");
if (/tags\$(?:script|link|img)\([^\n]*https?:/i.test(ui)) throw new Error("app has remote runtime asset");
if (!/alt="Screenprint illustration[^"<>]+"/.test(cover)) throw new Error("cover art needs descriptive alt text");
if (!/alt = "Screenprint illustration[^"<>]+"/.test(ui)) throw new Error("app art needs descriptive alt text");

const expected = {
  "docs/assets/mosquito-living-poster-v1.png": "120e4397b5ab74c3b9c2d1636568e5904fe0268b1f4cad9a77f86941ecf14581",
  "docs/assets/mosquito-living-poster-v1.webp": "aa6098780e1029cf4beb1d3afe967ac42a102e05df1c1f0afbf752520138e110",
  "www/assets/mosquito-living-poster-v1.webp": "aa6098780e1029cf4beb1d3afe967ac42a102e05df1c1f0afbf752520138e110",
  "docs/og-image-v2.png": "3ac459d280f2703ba80ed92ed31a102781601ab15e85437476f4d2239598fd11",
};
for (const [path, digest] of Object.entries(expected)) {
  const actual = crypto.createHash("sha256").update(fs.readFileSync(path)).digest("hex");
  if (actual !== digest) throw new Error(`${path} digest mismatch`);
}
console.log("OK: static Pages and app Living Posters are local, accessible, and provenance-locked.");
