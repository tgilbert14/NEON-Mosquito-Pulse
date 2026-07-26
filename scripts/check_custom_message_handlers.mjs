import fs from "node:fs";

const files = ["www/app.js", "www/pincards.js"];
const pattern = /Shiny\.addCustomMessageHandler\(\s*["'][^"']+["']\s*,\s*function\s*\(([^)]*)\)/g;
let seen = 0;
const invalid = [];
for (const file of files) {
  const source = fs.readFileSync(file, "utf8");
  for (const match of source.matchAll(pattern)) {
    seen += 1;
    const params = match[1].split(",").map((value) => value.trim()).filter(Boolean);
    if (params.length !== 1) invalid.push(`${file}: ${match[0]}`);
  }
}
if (seen < 1) throw new Error("no Shiny custom message handlers found");
if (invalid.length) throw new Error(`handlers must accept exactly one payload argument:\n${invalid.join("\n")}`);
console.log(`OK: ${seen} custom message handlers accept exactly one payload argument.`);
