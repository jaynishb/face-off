// Face Off — browser playtest harness.
//
//   node tools/playtest.mjs [gameId ...]
//
// Serves build/web, drives the game with REAL touch events via the Chrome
// DevTools Protocol (Input.dispatchTouchEvent — not mouse emulation, which
// exercises a different Godot input path), and asserts on PIXELS.
//
// The rule this harness exists to enforce, learned twice the hard way in this
// project: a score changing is NOT proof that input worked. Unattended physics
// changes the score on its own, and a build with no controls at all once passed
// a "the score went up" check. So every assertion here is about the position of
// the thing the input is supposed to move, measured as the centroid of that
// player's own colour, and every drag test also asserts that the OTHER player's
// piece did NOT move. That second half is what catches an inverted ownership
// axis, which otherwise looks completely healthy.
//
// Requires: a Web export in build/web (see CLAUDE.md), and playwright.

import { chromium } from 'playwright';
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve('build/web');
const PORT = 8099;
const VIEWPORT = { width: 390, height: 844 }; // a portrait phone, ~19.5:9

// Palette.gd. The two player colours are the probe.
const P1 = [0xff, 0x5a, 0x5f]; // coral
const P2 = [0x22, 0xb8, 0xcf]; // teal

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json',
};

function serve() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const rel = decodeURIComponent(req.url.split('?')[0]);
      const file = path.join(ROOT, rel === '/' ? 'index.html' : rel);
      if (!file.startsWith(ROOT) || !fs.existsSync(file)) {
        res.writeHead(404); res.end('not found'); return;
      }
      // Godot's web export needs cross-origin isolation for SharedArrayBuffer.
      res.writeHead(200, {
        'Content-Type': MIME[path.extname(file)] || 'application/octet-stream',
        'Cross-Origin-Opener-Policy': 'same-origin',
        'Cross-Origin-Embedder-Policy': 'require-corp',
      });
      fs.createReadStream(file).pipe(res);
    });
    server.listen(PORT, () => resolve(server));
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Connected blobs of pixels close to `target`, as {x, y, w, h, n} in CSS pixels.
 *
 * A plain centroid over every matching pixel is NOT good enough here: each
 * player's colour also paints their goal mouth and their score pill, both of
 * which are large, static, and would drag the average toward the middle of the
 * screen no matter where the paddle actually went. Measuring per-blob keeps the
 * probe honest.
 */
async function blobs(page, target, region) {
  const shot = await page.screenshot({ type: 'png' });
  return await page.evaluate(async ({ b64, target, region }) => {
    const img = new Image();
    img.src = 'data:image/png;base64,' + b64;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const ctx = c.getContext('2d');
    ctx.drawImage(img, 0, 0);
    const { data } = ctx.getImageData(0, 0, c.width, c.height);
    const sx = c.width / window.innerWidth, sy = c.height / window.innerHeight;

    const y0 = region ? Math.max(0, Math.floor(region.top * sy)) : 0;
    const y1 = region ? Math.min(c.height, Math.ceil(region.bottom * sy)) : c.height;

    const hit = (x, y) => {
      const i = (y * c.width + x) * 4;
      return Math.abs(data[i] - target[0]) + Math.abs(data[i + 1] - target[1]) +
             Math.abs(data[i + 2] - target[2]) < 48;
    };
    const seen = new Uint8Array(c.width * c.height);
    const out = [];
    const STEP = 2;
    for (let y = y0; y < y1; y += STEP) {
      for (let x = 0; x < c.width; x += STEP) {
        const k = y * c.width + x;
        if (seen[k] || !hit(x, y)) continue;
        let minX = x, maxX = x, minY = y, maxY = y, n = 0, tx = 0, ty = 0;
        const stack = [[x, y]];
        seen[k] = 1;
        while (stack.length) {
          const [px, py] = stack.pop();
          n++; tx += px; ty += py;
          if (px < minX) minX = px; if (px > maxX) maxX = px;
          if (py < minY) minY = py; if (py > maxY) maxY = py;
          for (const [dx, dy] of [[STEP,0],[-STEP,0],[0,STEP],[0,-STEP]]) {
            const nx = px + dx, ny = py + dy;
            if (nx < 0 || nx >= c.width || ny < y0 || ny >= y1) continue;
            const nk = ny * c.width + nx;
            if (seen[nk] || !hit(nx, ny)) continue;
            seen[nk] = 1;
            stack.push([nx, ny]);
          }
        }
        if (n < 40) continue;
        out.push({
          x: (tx / n) / sx, y: (ty / n) / sy,
          w: (maxX - minX) / sx, h: (maxY - minY) / sy, n,
        });
      }
    }
    return out.sort((a, b) => b.n - a.n);
  }, { b64: shot.toString('base64'), target, region });
}

/**
 * The paddle: the biggest roughly-circular blob of that player's colour inside
 * their own half. Circularity is what separates it from the goal mouth (a wide
 * thin rectangle) and the score pill (a wide capsule), both painted in the same
 * colour.
 */
async function paddle(page, target, region) {
  const found = await blobs(page, target, region);
  const round = found.filter((b) => b.w > 8 && b.h > 8 && b.w / b.h > 0.65 && b.w / b.h < 1.55);
  return round[0] || null;
}

/** One finger: touchStart, a few touchMoves, touchEnd. */
async function drag(cdp, from, to, steps = 6, id = 1) {
  const pt = (p) => ({ x: p.x, y: p.y, id, radiusX: 8, radiusY: 8, force: 1 });
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [pt(from)] });
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: [pt({ x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t })],
    });
    await sleep(24);
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

/** Two fingers moving at the same time — the actual Day 1 exit criterion. */
async function dragBoth(cdp, aFrom, aTo, bFrom, bTo, steps = 6) {
  const pt = (p, id) => ({ x: p.x, y: p.y, id, radiusX: 8, radiusY: 8, force: 1 });
  await cdp.send('Input.dispatchTouchEvent', {
    type: 'touchStart', touchPoints: [pt(aFrom, 1), pt(bFrom, 2)],
  });
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchMove',
      touchPoints: [
        pt({ x: aFrom.x + (aTo.x - aFrom.x) * t, y: aFrom.y + (aTo.y - aFrom.y) * t }, 1),
        pt({ x: bFrom.x + (bTo.x - bFrom.x) * t, y: bFrom.y + (bTo.y - bFrom.y) * t }, 2),
      ],
    });
    await sleep(24);
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
}

async function tap(cdp, p, id = 1) {
  const pt = { x: p.x, y: p.y, id, radiusX: 8, radiusY: 8, force: 1 };
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [pt] });
  await sleep(40);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await sleep(60);
}


/**
 * Locate the gold ACCENT PLAY buttons on Game Select by scanning for runs of
 * that colour and clustering them into rectangles. Everything on these screens
 * is drawn into one canvas -- there is no DOM to query -- so the buttons have
 * to be found by pixel, and hardcoding their coordinates would silently rot the
 * moment the layout changes.
 */
async function findButtons(page) {
  return findButtonsGeneric(page, [0xff, 0xc8, 0x57]);
}

async function findButtonsGeneric(page, accent) {
  const shot = await page.screenshot({ type: 'png' });
  return await page.evaluate(async ({ b64, target }) => {
    const img = new Image();
    img.src = 'data:image/png;base64,' + b64;
    await img.decode();
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const ctx = c.getContext('2d');
    ctx.drawImage(img, 0, 0);
    const { data } = ctx.getImageData(0, 0, c.width, c.height);
    const sx = c.width / window.innerWidth, sy = c.height / window.innerHeight;

    const hit = (x, y) => {
      const i = (y * c.width + x) * 4;
      return Math.abs(data[i] - target[0]) + Math.abs(data[i + 1] - target[1]) +
             Math.abs(data[i + 2] - target[2]) < 40;
    };
    // Flood fill each blob of accent pixels into a bounding box.
    const seen = new Uint8Array(c.width * c.height);
    const boxes = [];
    for (let y = 0; y < c.height; y += 2) {
      for (let x = 0; x < c.width; x += 2) {
        const k = y * c.width + x;
        if (seen[k] || !hit(x, y)) continue;
        let minX = x, maxX = x, minY = y, maxY = y, n = 0;
        const stack = [[x, y]];
        seen[k] = 1;
        while (stack.length) {
          const [px, py] = stack.pop();
          n++;
          if (px < minX) minX = px; if (px > maxX) maxX = px;
          if (py < minY) minY = py; if (py > maxY) maxY = py;
          for (const [dx, dy] of [[2,0],[-2,0],[0,2],[0,-2]]) {
            const nx = px + dx, ny = py + dy;
            if (nx < 0 || ny < 0 || nx >= c.width || ny >= c.height) continue;
            const nk = ny * c.width + nx;
            if (seen[nk] || !hit(nx, ny)) continue;
            seen[nk] = 1;
            stack.push([nx, ny]);
          }
        }
        if (n < 200) continue; // ignore small accent flecks
        boxes.push({
          x: ((minX + maxX) / 2) / sx, y: ((minY + maxY) / 2) / sy,
          w: (maxX - minX) / sx, h: (maxY - minY) / sy,
        });
      }
    }
    return boxes.sort((a, b) => a.y - b.y || a.x - b.x);
  }, { b64: shot.toString('base64'), target: accent });
}


/** The single SUCCESS-green button (GOT IT! / CONTINUE PLAYING), if present. */
async function findGreen(page) {
  const boxes = await findButtonsOfColor(page, [0x4e, 0xcb, 0x8d]);
  return boxes[0] || null;
}

async function findButtonsOfColor(page, color) {
  const orig = color;
  return await findButtonsGeneric(page, orig);
}

const results = [];
function check(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? '  PASS' : '  FAIL'}  ${name}${detail ? '  — ' + detail : ''}`);
}

async function main() {
  const only = process.argv.slice(2);
  const server = await serve();
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--no-sandbox', '--enable-features=SharedArrayBuffer'],
  });
  const context = await browser.newContext({
    viewport: VIEWPORT, hasTouch: true, isMobile: true, deviceScaleFactor: 2,
  });
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  page.on('pageerror', (e) => console.log('  [pageerror]', e.message));

  await page.goto(`http://localhost:${PORT}/index.html`);
  await page.waitForSelector('canvas');
  await sleep(6000); // engine boot + main menu

  // Standing regression test: the canvas must never carry a CSS transform.
  // Rotating it scrambles every touch coordinate against Godot's untransformed
  // pixel buffer, and that has broken all input in this project once already.
  const transform = await page.evaluate(() =>
    getComputedStyle(document.querySelector('canvas')).transform);
  check('canvas has no CSS transform', transform === 'none' || transform === '', transform);

  const mid = VIEWPORT.height / 2;
  const topHalf = { top: 0, bottom: mid };
  const bottomHalf = { top: mid, bottom: VIEWPORT.height };

  // Main Menu -> Game Select. Buttons are Controls, so a tap is enough.
  await tap(cdp, { x: VIEWPORT.width / 2, y: VIEWPORT.height * 0.66 });
  await sleep(1500);
  const playButtons = await findButtons(page);
  check('reached Game Select', playButtons.length >= 6, `${playButtons.length} PLAY buttons`);

  const games = only.length ? only : ['air_hockey'];
  for (const gameId of games) {
    console.log(`\n== ${gameId} ==`);
    await runGame(page, cdp, gameId, { mid, topHalf, bottomHalf });
  }

  await browser.close();
  server.close();

  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
  process.exit(failed.length ? 1 : 0);
}

/**
 * Air Hockey is the probe game: both paddles are large, solid, in their own
 * player's colour, and confined to their own half — so a colour centroid is an
 * honest read of where each paddle is.
 */
async function runGame(page, cdp, gameId, geom) {
  // Launch via the card's actual PLAY button -- the card body is not clickable,
  // only the button is, so a tap on the card does nothing at all and every later
  // assertion would then be measuring the Game Select screen.
  const buttons = await findButtons(page);
  const target = buttons[geom.buttonIndex ?? 0];
  if (!target) { check(`${gameId}: found its PLAY button`, false); return; }
  await tap(cdp, { x: target.x, y: target.y });
  await sleep(1200);

  // First play of a game auto-opens the rules card; GOT IT! is the only SUCCESS
  // green button on screen, so find it the same way.
  const gotIt = await findGreen(page);
  if (gotIt) { await tap(cdp, { x: gotIt.x, y: gotIt.y }); }
  await sleep(4500);

  const before1 = await paddle(page, P1, geom.bottomHalf);
  const before2 = await paddle(page, P2, geom.topHalf);
  check('P1 paddle visible in the bottom half', before1 !== null, before1 ? `x=${before1.x.toFixed(0)}` : '');
  check('P2 paddle visible in the top half', before2 !== null, before2 ? `x=${before2.x.toFixed(0)}` : '');
  if (!before1 || !before2) return;

  // --- single finger, P1's half -------------------------------------------
  // The important half of this test is the SECOND assertion.
  const p1Target = { x: VIEWPORT.width * 0.78, y: geom.mid + 150 };
  await drag(cdp, { x: before1.x, y: before1.y }, p1Target);
  await sleep(250);

  const after1 = await paddle(page, P1, geom.bottomHalf);
  const after2 = await paddle(page, P2, geom.topHalf);
  check(
    'P1 drag moved the P1 paddle toward the touch',
    after1 !== null && Math.abs(after1.x - p1Target.x) < 60,
    after1 ? `paddle x=${after1.x.toFixed(0)} target x=${p1Target.x.toFixed(0)}` : 'not found',
  );
  check(
    'P1 drag did NOT move the P2 paddle',
    after2 !== null && Math.abs(after2.x - before2.x) < 18,
    after2 ? `moved ${Math.abs(after2.x - before2.x).toFixed(1)}px` : 'not found',
  );

  // --- single finger, P2's half -------------------------------------------
  const p2Target = { x: VIEWPORT.width * 0.22, y: geom.mid - 150 };
  const mid1 = await paddle(page, P1, geom.bottomHalf);
  await drag(cdp, { x: after2.x, y: after2.y }, p2Target);
  await sleep(250);

  const post1 = await paddle(page, P1, geom.bottomHalf);
  const post2 = await paddle(page, P2, geom.topHalf);
  check(
    'P2 drag moved the P2 paddle toward the touch',
    post2 !== null && Math.abs(post2.x - p2Target.x) < 60,
    post2 ? `paddle x=${post2.x.toFixed(0)} target x=${p2Target.x.toFixed(0)}` : 'not found',
  );
  check(
    'P2 drag did NOT move the P1 paddle',
    post1 !== null && mid1 !== null && Math.abs(post1.x - mid1.x) < 18,
    post1 && mid1 ? `moved ${Math.abs(post1.x - mid1.x).toFixed(1)}px` : 'not found',
  );

  // --- two fingers at once — the Day 1 exit criterion ----------------------
  const a = { x: VIEWPORT.width * 0.20, y: geom.mid + 160 };
  const b = { x: VIEWPORT.width * 0.80, y: geom.mid - 160 };
  await dragBoth(cdp, { x: post1.x, y: post1.y }, a, { x: post2.x, y: post2.y }, b);
  await sleep(250);

  const both1 = await paddle(page, P1, geom.bottomHalf);
  const both2 = await paddle(page, P2, geom.topHalf);
  check(
    'simultaneous two-finger: P1 paddle reached its own target',
    both1 !== null && Math.abs(both1.x - a.x) < 60,
    both1 ? `x=${both1.x.toFixed(0)} want ${a.x.toFixed(0)}` : 'not found',
  );
  check(
    'simultaneous two-finger: P2 paddle reached its own target',
    both2 !== null && Math.abs(both2.x - b.x) < 60,
    both2 ? `x=${both2.x.toFixed(0)} want ${b.x.toFixed(0)}` : 'not found',
  );
}

main().catch((e) => { console.error(e); process.exit(1); });
