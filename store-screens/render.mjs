// Renders every screen in screens.json at every store size into out/<format>/<id>.png
// Usage: node store-screens/render.mjs [screen-id ...]
import { createRequire } from 'node:module';
import { readFileSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

// require() so a globally installed playwright is found too (ESM import ignores NODE_PATH)
const { chromium } = createRequire(import.meta.url)('playwright');
const dir = dirname(fileURLToPath(import.meta.url));
const cfg = JSON.parse(readFileSync(join(dir, 'screens.json'), 'utf8'));
const only = process.argv.slice(2);
const screens = cfg.screens.filter(s => !only.length || only.includes(s.id));

const browser = await chromium.launch();
for (const [name, format] of Object.entries(cfg.formats)) {
  mkdirSync(join(dir, 'out', name), { recursive: true });
  const page = await browser.newPage({ viewport: { width: format.width, height: format.height }, deviceScaleFactor: 1 });
  for (const screen of screens) {
    await page.goto(pathToFileURL(join(dir, 'template.html')).href);
    await page.evaluate(args => window.render(args), {
      screen, format, text: cfg.text[format.text],
      imageUrl: pathToFileURL(resolve(dir, screen.screenshot)).href,
    });
    const file = join(dir, 'out', name, `${screen.id}.png`);
    await page.screenshot({ path: file, omitBackground: false });
    console.log(file);
  }
  await page.close();
}
await browser.close();
