// Mirrors tests/unit/snake/snake_logic_test.gd for the HTML5 port.  Run: node --test tests/web/snake_logic.test.js
const test = require("node:test");
const assert = require("node:assert/strict");
const { SnakeLogic, CONFIG, DIRS } = require("../../web/snake.js");

const make = () => { const s = new SnakeLogic({ ...CONFIG, gridCols: 10, gridRows: 10 }, () => 0.5); s.food = [0, 0]; return s; };

test("starts centered moving right", () => assert.deepEqual(make().body, [[5, 5], [4, 5], [3, 5]]));
test("eating grows and scores", () => { const s = make(); s.food = [6, 5]; assert.equal(s.step(), "ate"); assert.equal(s.body.length, 4); assert.equal(s.score, 1); });
test("reverse and repeat rejected", () => { const s = make(); assert.equal(s.queueDirection(DIRS.left), false); assert.equal(s.queueDirection(DIRS.right), false); assert.equal(s.queueDirection(DIRS.up), true); });
test("input buffer double turn", () => { const s = make(); s.queueDirection(DIRS.up); s.queueDirection(DIRS.left); assert.equal(s.queueDirection(DIRS.down), false); s.step(); s.step(); assert.deepEqual(s.body[0], [4, 4]); });
test("wall kills", () => { const s = make(); for (let i = 0; i < 4; i++) assert.equal(s.step(), "moved"); assert.equal(s.step(), "died"); });
test("self collision kills", () => { const s = make(); s.body = [[5, 5], [4, 5], [4, 4], [5, 4], [6, 4], [6, 5]]; s.dir = DIRS.up; assert.equal(s.step(), "died"); });
test("vacating tail allowed", () => { const s = make(); s.body = [[5, 5], [5, 4], [4, 4], [4, 5]]; s.dir = DIRS.left; assert.equal(s.step(), "moved"); });
test("speed curve clamps", () => { const s = make(); assert.equal(s.tickMs(), 150); s.score = 5; assert.equal(s.tickMs(), 140); s.score = 500; assert.equal(s.tickMs(), 60); });
test("full board wins", () => { const s = new SnakeLogic({ ...CONFIG, gridCols: 2, gridRows: 2, startLength: 1 }); s.body = [[0, 0], [0, 1], [1, 1]]; s.dir = DIRS.right; s.food = [1, 0]; assert.equal(s.step(), "won"); });
