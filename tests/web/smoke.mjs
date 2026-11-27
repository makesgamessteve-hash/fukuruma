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
for (const scenario of ['boot', 'simulation', 'showcase_materials', 'showcase_skinning', 'feel', 'audio', 'save', 'first_person', 'scale_ladder', 'orbits', 'physics', 'systems', 'navigation']) {
  await test(`${scenario} scenario passes in the browser`, async (page) => {
    await page.goto(`${base}?scenario=${scenario}`);
    // the sandbox scenes draw the world's ground: slow on the software renderer the tests run on
    await page.waitForFunction(() => window.fukurumaResult, null, { timeout: 300000 });
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

await test('the game opens a sound device', async (page) => {
  await page.addInitScript(() => { // counts the audio contexts SDL creates
    const Real = window.AudioContext;
    window.fkAudio = [];
    window.AudioContext = function (...args) { const c = new Real(...args); window.fkAudio.push(c); return c; };
    window.AudioContext.prototype = Real.prototype;
  });
  await page.goto(base);
  await page.waitForFunction(() => document.getElementById('message').hidden, null, { timeout: 60000 });
  await page.mouse.click(10, 10); // browsers start sound after a gesture; SDL resumes the context then
  await page.waitForFunction(() => window.fkAudio.some((c) => c.state === 'running'), null, { timeout: 10000 });
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

// A stored value as IndexedDB holds it (Emscripten's IDBFS keeps files in FILE_DATA).
const storedFile = (page, file) => page.evaluate((file) => new Promise((resolve) => {
  const open = indexedDB.open('/libsdl');
  open.onerror = () => resolve(null);
  open.onsuccess = () => {
    const db = open.result;
    if (!db.objectStoreNames.contains('FILE_DATA')) return resolve(null);
    const all = db.transaction('FILE_DATA').objectStore('FILE_DATA').openCursor();
    let text = null;
    all.onsuccess = () => {
      const cursor = all.result;
      if (!cursor) return resolve(text);
      if (String(cursor.key).endsWith('/' + file)) text = new TextDecoder().decode(cursor.value.contents);
      cursor.continue();
    };
  };
}), file);
const storedGraphics = (page) => storedFile(page, 'graphics.txt');
const waitForStored = async (page, pattern) => {
  for (let i = 0; i < 100; i++) {
    const text = await storedGraphics(page);
    if (text && pattern.test(text)) return text;
    await page.waitForTimeout(100);
  }
  throw new Error(`stored settings never matched ${pattern}: ${await storedGraphics(page)}`);
};

await test('the menu opens with a tap and stored settings survive a reload', async (page) => {
  await page.goto(base);
  await page.waitForFunction(() => document.getElementById('message').hidden, null, { timeout: 60000 });
  await waitForStored(page, /level=low/); // SwiftShader is a software renderer: Low, stored on the first start
  const box = await page.locator('canvas').boundingBox();
  await page.touchscreen.tap(box.x + box.width * 0.94, box.y + box.height * 0.1); // the touch menu button
  await page.waitForTimeout(300);
  await page.keyboard.down('ArrowRight'); // Detail level: Low -> Medium
  await page.waitForTimeout(200);
  await page.keyboard.up('ArrowRight');
  await waitForStored(page, /level=medium/);
  // The game keeps showing new frames after the renderer was rebuilt for the new level (the software renderer
  // compiles the new level's shaders slowly).
  const first = await page.locator('canvas').screenshot({ timeout: 120000 });
  await page.waitForTimeout(500);
  assert(!first.equals(await page.locator('canvas').screenshot({ timeout: 120000 })), 'the picture froze after the settings changed');
  await page.reload({ timeout: 120000 }); // the page is slow at Medium on the software renderer
  await page.waitForFunction(() => document.getElementById('message').hidden, null, { timeout: 60000 });
  await page.waitForTimeout(1000); // a failed load would store the defaults again by now
  const text = await storedGraphics(page);
  assert(/level=medium/.test(text), `after the reload: ${text}`);
}, { viewport: { width: 844, height: 390 }, hasTouch: true, isMobile: true });

const tap = async (page, key, ms = 150) => {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  await page.keyboard.up(key);
};

await test('a saved game survives a reload', async (page) => {
  const dialogs = [];
  page.on('dialog', (d) => { dialogs.push(d.message()); d.dismiss(); }); // script errors would show a message box
  await page.goto(base);
  await page.waitForFunction(() => document.getElementById('message').hidden, null, { timeout: 60000 });
  await tap(page, 'KeyW', 600);
  await tap(page, 'F5'); // quick save (the game keeps the key from the browser: no page reload)
  let saved = null;
  for (let i = 0; i < 50 && !(saved && saved.startsWith('-- fukuruma save')); i++) {
    await page.waitForTimeout(100);
    saved = await storedFile(page, 'save_quick.txt');
  }
  assert(saved && saved.includes('suit'), `no save was stored: ${saved}`);
  await page.reload();
  await page.waitForFunction(() => document.getElementById('message').hidden, null, { timeout: 60000 });
  await tap(page, 'F9'); // quick load
  await page.waitForTimeout(500);
  assert((await storedFile(page, 'save_quick.txt')) === saved, 'the save is unchanged after the reload');
  assert(dialogs.length === 0, `errors: ${dialogs.join(' | ')}`);
});

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
