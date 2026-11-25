// Baut die Website aus src/page.html.
//
//   node build.mjs            schreibt index.html (für echtes Hosting, Schrift und Bilder als Dateien)
//   node build.mjs <datei>    schreibt zusätzlich eine Vorschau-Fassung ohne Dokument-Rahmen,
//                             mit eingebetteter Schrift (für die Vorschau auf claude.ai)
//
// Symbole: {{i:name}} wird durch das Phosphor-Symbol "name" (Schnitt bold) ersetzt.
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const iconDir = join(here, 'node_modules/@phosphor-icons/core/assets');

function icon(name, weight = 'bold') {
  const file = join(iconDir, weight, weight === 'regular' ? `${name}.svg` : `${name}-${weight}.svg`);
  let svg;
  try {
    svg = readFileSync(file, 'utf8');
  } catch {
    throw new Error(`Symbol fehlt: ${name} (${weight})`);
  }
  const inner = svg.replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
  return `<svg class="ic" viewBox="0 0 256 256" fill="currentColor" aria-hidden="true" focusable="false">${inner}</svg>`;
}

const src = readFileSync(join(here, 'src/page.html'), 'utf8')
  .replace(/\{\{i:([a-z0-9-]+)(?::([a-z]+))?\}\}/g, (_, n, w) => icon(n, w));

const [head, body] = src.split('<!--BODY-->');
if (!body) throw new Error('Marke <!--BODY--> fehlt in src/page.html');

const full = `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<link rel="icon" href="img/favicon.svg" type="image/svg+xml">
<link rel="preload" href="fonts/Figtree-ExtraBold.woff2" as="font" type="font/woff2" crossorigin>
${head.trim()}
</head>
<body>
${body.trim()}
</body>
</html>
`;
writeFileSync(join(here, 'index.html'), full);
console.log('index.html', full.length);

const out = process.argv[2];
if (out) {
  const inlined = (head + body).replace(/url\("fonts\/([^"]+\.woff2)"\)/g, (_, f) => {
    const b64 = readFileSync(join(here, 'fonts', f)).toString('base64');
    return `url("data:font/woff2;base64,${b64}")`;
  });
  writeFileSync(out, inlined);
  console.log(out, inlined.length);
}
