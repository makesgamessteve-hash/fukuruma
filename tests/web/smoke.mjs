// Browser tests for the web build (web-distribution spec).
// usage: node tests/web/smoke.mjs build/web
import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] ?? 'build/web');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.data': 'application/octet-stream' };
const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(new URL(req.url, 'http://x').pathname));
  if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404).end();
    return;
  }
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] ?? 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}/index.html`;
// SwiftShader gives headless Chromium a software WebGL 2.
const browser = await chromium.launch({ args: ['--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--ignore-gpu-blocklist'] });

let failures = 0;
async function test(name, fn, options = {}) {
  const page = await browser.newPage({ viewport: { width: 960, height: 540 }, ...options });
  const log = [];
  page.on('console', (m) => log.push(m.text()));
  page.on('pageerror', (e) => log.push(String(e)));
  try {
    await fn(page);
    console.log(`PASS ${name}`);
  } catch (e) {
    failures++;
    console.log(`FAIL ${name}: ${e.message}\n  ${log.join('\n  ')}`);
  }
  await page.close();
}

const assert = (cond, msg) => { if (!cond) throw new Error(msg); };

// simulation: the recorded state hash must match in WebAssembly too (determinism across platforms).
for (const scenario of ['boot', 'simulation']) {
  await test(`${scenario} scenario passes in the browser`, async (page) => {
    await page.goto(`${base}?scenario=${scenario}`);
    await page.waitForFunction(() => window.fukurumaResult, null, { timeout: 60000 });
    const result = await page.evaluate(() => window.fukurumaResult);
    assert(result.status === 'passed', `scenario ${result.status}: ${result.message}`);
  });
}

await test('the game renders the placeholder scene', async (page) => {
  await page.goto(base);
  await page.waitForFunction(() => document.getElementById('message').hidden, null, { timeout: 60000 });
  await page.waitForTimeout(1000);
  const png = await page.locator('canvas').screenshot();
  const colours = await page.evaluate(async (b64) => {
    const img = new Image();
    img.src = `data:image/png;base64,${b64}`;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width;
    c.height = img.height;
    const ctx = c.getContext('2d');
    ctx.drawImage(img, 0, 0);
    const d = ctx.getImageData(0, 0, c.width, c.height).data;
    const seen = new Set();
    for (let i = 0; i < d.length; i += 4) seen.add((d[i] << 16) | (d[i + 1] << 8) | d[i + 2]);
    return seen.size;
  }, png.toString('base64'));
  assert(colours > 16, `the canvas shows only ${colours} colours`);
});

await test('touch input reaches the game on a phone', async (page) => {
  await page.goto(`${base}?scenario=touch`);
  await page.waitForFunction(() => document.getElementById('message').hidden, null, { timeout: 60000 });
  const box = await page.locator('canvas').boundingBox();
  for (let i = 0; i < 30 && !(await page.evaluate(() => window.fukurumaResult)); i++) {
    await page.touchscreen.tap(box.x + box.width * 0.2, box.y + box.height * 0.7);
    await page.waitForTimeout(300);
  }
  const result = await page.evaluate(() => window.fukurumaResult);
  assert(result && result.status === 'passed', `touch scenario: ${JSON.stringify(result)}`);
}, { viewport: { width: 844, height: 390 }, hasTouch: true, isMobile: true });

await test('browsers without WebGL 2 get a message', async (page) => {
  await page.addInitScript(() => {
    const getContext = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (type, ...args) {
      return type === 'webgl2' ? null : getContext.call(this, type, ...args);
    };
  });
  await page.goto(base);
  const text = await page.locator('#message').textContent();
  assert(text.includes('WebGL 2'), `message was: ${text}`);
});

await browser.close();
server.close();
process.exit(failures ? 1 : 0);
