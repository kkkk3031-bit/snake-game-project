// End-to-end input test: plays the real web build in Chromium using trusted
// browser key events (CDP Input.dispatchKeyEvent — the same pipeline as a
// physical keyboard) and checks the snake actually responds.
//
//   npm install && npm run test:e2e                     # serves web/ itself
//   GAME_URL=https://<tunnel> npm run test:e2e          # test a hosted copy
//   CHROME_PATH=/path/to/chrome npm run test:e2e        # custom browser
"use strict";
const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const { chromium } = require("playwright-core");

const WEB_DIR = path.join(__dirname, "../../web");
const DEFAULT_CHROME = path.join(os.homedir(),
  ".cache/ms-playwright/chromium_headless_shell-1248/chrome-headless-shell-linux64/chrome-headless-shell");
const UP = [0, -1], DOWN = [0, 1], LEFT = [-1, 0], RIGHT = [1, 0];

// How different browsers/keyboards fill KeyboardEvent fields.
const VARIANTS = {
  "key+code (desktop)": (key, code, kc) => ({ key, code, windowsVirtualKeyCode: kc }),
  "key only, no code": (key, _code, kc) => ({ key, windowsVirtualKeyCode: kc }),
  "keyCode only": (_key, _code, kc) => ({ key: "Unidentified", windowsVirtualKeyCode: kc }),
};
const ARROWS = {
  up: ["ArrowUp", "ArrowUp", 38], down: ["ArrowDown", "ArrowDown", 40],
  left: ["ArrowLeft", "ArrowLeft", 37], right: ["ArrowRight", "ArrowRight", 39],
};
const WASD = { up: ["w", "KeyW", 87], down: ["s", "KeyS", 83], left: ["a", "KeyA", 65], right: ["d", "KeyD", 68] };

function serve() {
  const types = { ".html": "text/html", ".js": "text/javascript" };
  const server = http.createServer((req, res) => {
    const file = path.join(WEB_DIR, req.url === "/" ? "index.html" : path.normalize(req.url));
    if (!file.startsWith(WEB_DIR) || !fs.existsSync(file)) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { "content-type": types[path.extname(file)] || "application/octet-stream" });
    fs.createReadStream(file).pipe(res);
  });
  return new Promise((ok) => server.listen(0, "127.0.0.1", () => ok(server)));
}

const results = [];
function check(name, cond, detail = "") {
  results.push(cond);
  console.log(`${cond ? "PASS" : "FAIL"}  ${name}${cond ? "" : "  " + detail}`);
}
const same = (a, b) => a[0] === b[0] && a[1] === b[1];

async function openGame(browser, url) {
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto(url);
  const cdp = await page.context().newCDPSession(page);
  const state = () => page.evaluate(() => window.snakeGame.state());
  const press = async (ev) => {
    await cdp.send("Input.dispatchKeyEvent", { type: "rawKeyDown", ...ev });
    await cdp.send("Input.dispatchKeyEvent", { type: "keyUp", ...ev });
  };
  const tick = () => page.waitForTimeout(220); // > one 150 ms game tick
  return { page, state, press, tick, errors };
}

(async () => {
  let server = null;
  let url = process.env.GAME_URL;
  if (!url) { server = await serve(); url = `http://127.0.0.1:${server.address().port}/`; }
  const args = process.env.HOST_RULES ? [`--host-resolver-rules=${process.env.HOST_RULES}`] : [];
  const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || DEFAULT_CHROME, args });
  console.log(`Testing ${url}\n`);

  const steerSequence = async (g, keys, make, label) => {
    // From the start (moving right): up, left, down, right — every direction once.
    for (const [dir, want] of [["up", UP], ["left", LEFT], ["down", DOWN], ["right", RIGHT]]) {
      await g.press(make(...keys[dir]));
      await g.tick();
      const s = await g.state();
      check(`${label}: ${dir} turns the snake`, s.started && s.alive && same(s.dir, want), JSON.stringify(s));
    }
  };

  for (const [label, make] of Object.entries(VARIANTS)) {
    const g = await openGame(browser, url);
    await steerSequence(g, ARROWS, make, `arrows, ${label}`);
    check(`arrows, ${label}: no page errors`, g.errors.length === 0, g.errors.join("; "));
    await g.page.close();
  }

  {
    const g = await openGame(browser, url);
    await steerSequence(g, WASD, VARIANTS["key+code (desktop)"], "WASD");
    await g.page.close();
  }

  {
    const g = await openGame(browser, url);
    await g.page.keyboard.press("ArrowUp"); // Playwright's high-level keyboard path too
    await g.tick();
    check("pause: game started", (await g.state()).started);
    await g.press({ key: "p", code: "KeyP", windowsVirtualKeyCode: 80 });
    const head = (await g.state()).head;
    await g.page.waitForTimeout(600);
    const s = await g.state();
    check("pause: P freezes the snake", s.paused && same(s.head, head), JSON.stringify(s));
    await g.press({ key: " ", code: "Space", windowsVirtualKeyCode: 32 });
    await g.tick();
    check("pause: Space resumes", !(await g.state()).paused);
    await g.page.waitForFunction(() => !window.snakeGame.state().alive, null, { timeout: 5000 });
    check("restart: snake dies at the wall", !(await g.state()).alive);
    await g.press({ key: "Enter", code: "Enter", windowsVirtualKeyCode: 13 });
    const r = await g.state();
    check("restart: Enter starts a fresh run", r.alive && !r.started && r.score === 0, JSON.stringify(r));
    await g.page.close();
  }

  {
    const g = await openGame(browser, url);
    await g.page.click('[data-action="up"]');
    await g.tick();
    const s = await g.state();
    check("on-screen ▲ button turns the snake", s.started && same(s.dir, UP), JSON.stringify(s));
    await g.page.close();
  }

  await browser.close();
  if (server) server.close();
  const failed = results.filter((r) => !r).length;
  console.log(`\n${results.length - failed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
})();
