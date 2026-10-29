// HTML5 port of src/snake_logic.gd + src/main.gd. Same rules; tuning values
// mirror assets/data/snake_config.json.
"use strict";

const CONFIG = {
  gridCols: 20, gridRows: 20, startLength: 3,
  baseTickMs: 150, minTickMs: 60, tickStepMs: 10,
  foodsPerSpeedup: 5, inputBufferSize: 2,
};
const DIRS = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
const KEYS = {
  ArrowUp: "up", KeyW: "up", ArrowDown: "down", KeyS: "down",
  ArrowLeft: "left", KeyA: "left", ArrowRight: "right", KeyD: "right",
};
const COLORS = { grid: "#232737", head: "#7dff8a", body: "#3ddc5a", food: "#ff6b6b" };

/** Pure snake rules; no DOM access. */
class SnakeLogic {
  constructor(cfg, rand = Math.random) {
    this.cfg = cfg;
    this.rand = rand;
    this.reset();
  }

  /** Starts a new run mid-board, facing right. */
  reset() {
    const { gridCols, gridRows, startLength } = this.cfg;
    const hx = Math.floor(gridCols / 2), hy = Math.floor(gridRows / 2);
    this.body = Array.from({ length: startLength }, (_, i) => [hx - i, hy]);
    this.dir = DIRS.right;
    this.queue = [];
    this.score = 0;
    this.alive = true;
    this.won = false;
    this.spawnFood();
  }

  /** Queues a turn; rejects repeats, reversals and buffer overflow. */
  queueDirection(d) {
    if (!this.alive || this.queue.length >= this.cfg.inputBufferSize) return false;
    const last = this.queue.length ? this.queue[this.queue.length - 1] : this.dir;
    if ((d[0] === last[0] && d[1] === last[1]) || (d[0] === -last[0] && d[1] === -last[1])) return false;
    this.queue.push(d);
    return true;
  }

  /** Advances one cell. Returns "moved" | "ate" | "died" | "won". */
  step() {
    if (!this.alive) return "died";
    if (this.queue.length) this.dir = this.queue.shift();
    const [hx, hy] = this.body[0];
    const next = [hx + this.dir[0], hy + this.dir[1]];
    const eating = this.food && next[0] === this.food[0] && next[1] === this.food[1];
    const { gridCols, gridRows } = this.cfg;
    const blocking = eating ? this.body : this.body.slice(0, -1); // tail vacates unless growing
    if (next[0] < 0 || next[1] < 0 || next[0] >= gridCols || next[1] >= gridRows ||
        blocking.some(([x, y]) => x === next[0] && y === next[1])) {
      this.alive = false;
      return "died";
    }
    this.body.unshift(next);
    if (!eating) { this.body.pop(); return "moved"; }
    this.score += 1;
    if (!this.spawnFood()) { this.won = true; this.alive = false; return "won"; }
    return "ate";
  }

  /** Places food on a random free cell; false when the board is full. */
  spawnFood() {
    const taken = new Set(this.body.map(([x, y]) => `${x},${y}`));
    const free = [];
    for (let y = 0; y < this.cfg.gridRows; y++)
      for (let x = 0; x < this.cfg.gridCols; x++)
        if (!taken.has(`${x},${y}`)) free.push([x, y]);
    this.food = free.length ? free[Math.floor(this.rand() * free.length)] : null;
    return this.food !== null;
  }

  /** Tick length in ms, shrinking every foodsPerSpeedup points. */
  tickMs() {
    const c = this.cfg;
    return Math.max(c.minTickMs, c.baseTickMs - Math.floor(this.score / c.foodsPerSpeedup) * c.tickStepMs);
  }
}

if (typeof module !== "undefined") module.exports = { SnakeLogic, CONFIG, DIRS };

if (typeof document !== "undefined") {
  const canvas = document.getElementById("board");
  const ctx = canvas.getContext("2d");
  const scoreEl = document.getElementById("score");
  const bestEl = document.getElementById("best");
  const game = new SnakeLogic(CONFIG);
  let best = Number(localStorage.getItem("snake-best") || 0);
  let started = false, paused = false, timer = null;

  const steer = (name) => {
    if (paused) return;
    started = true;
    game.queueDirection(DIRS[name]);
  };
  const restart = () => {
    game.reset(); started = false; paused = false; schedule(); draw();
  };
  const schedule = () => { clearTimeout(timer); timer = setTimeout(tick, game.tickMs()); };

  function tick() {
    if (started && !paused && game.alive) {
      game.step();
      if (game.score > best) { best = game.score; localStorage.setItem("snake-best", best); }
      draw();
    }
    schedule();
  }

  function draw() {
    const cs = canvas.width / CONFIG.gridCols;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.strokeStyle = COLORS.grid;
    for (let i = 1; i < CONFIG.gridCols; i++) {
      ctx.beginPath(); ctx.moveTo(i * cs, 0); ctx.lineTo(i * cs, canvas.height); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(0, i * cs); ctx.lineTo(canvas.width, i * cs); ctx.stroke();
    }
    if (game.food) {
      ctx.fillStyle = COLORS.food;
      ctx.beginPath();
      ctx.arc((game.food[0] + 0.5) * cs, (game.food[1] + 0.5) * cs, cs * 0.38, 0, Math.PI * 2);
      ctx.fill();
    }
    game.body.forEach(([x, y], i) => {
      ctx.fillStyle = i === 0 ? COLORS.head : COLORS.body;
      ctx.fillRect(x * cs + 2, y * cs + 2, cs - 4, cs - 4);
    });
    scoreEl.textContent = `Score: ${game.score}`;
    bestEl.textContent = `Best: ${best}`;
    const msg = game.won ? "You win! Press R" : !game.alive ? "Game over — press R / tap"
      : paused ? "Paused" : !started ? "Arrow keys / WASD / swipe to start" : "";
    if (msg) {
      ctx.fillStyle = "rgba(0,0,0,.6)";
      ctx.fillRect(0, canvas.height * 0.75 - 40, canvas.width, 80);
      ctx.fillStyle = "#e8eaf2";
      ctx.font = "600 26px system-ui, sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(msg, canvas.width / 2, canvas.height * 0.75);
    }
  }

  document.addEventListener("keydown", (e) => {
    if (KEYS[e.code]) { e.preventDefault(); steer(KEYS[e.code]); }
    else if ((e.code === "KeyP" || e.code === "Space") && started && game.alive) { e.preventDefault(); paused = !paused; }
    else if ((e.code === "KeyR" || e.code === "Enter") && !game.alive) restart();
    draw();
  });

  let touch = null;
  canvas.addEventListener("pointerdown", (e) => { touch = [e.clientX, e.clientY]; });
  canvas.addEventListener("pointerup", (e) => {
    if (!touch) return;
    const dx = e.clientX - touch[0], dy = e.clientY - touch[1];
    touch = null;
    if (Math.max(Math.abs(dx), Math.abs(dy)) < 20) { if (!game.alive) restart(); return; }
    steer(Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? "right" : "left") : (dy > 0 ? "down" : "up"));
    draw();
  });

  schedule();
  draw();
}
