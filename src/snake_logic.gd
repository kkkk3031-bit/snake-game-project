class_name SnakeLogic
extends RefCounted
## Engine-independent snake rules: grid movement, growth, collision and the
## input buffer. Holds no nodes, so the unit tests can drive it step by step.

## Result of one [method step] call.
enum StepResult { MOVED, ATE, DIED, WON }

const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)

var cols: int
var rows: int
var start_length: int
var base_tick_ms: int
var min_tick_ms: int
var tick_step_ms: int
var foods_per_speedup: int
var input_buffer_size: int

## Snake segments, head first.
var body: Array[Vector2i] = []
var direction: Vector2i = RIGHT
var food: Vector2i = Vector2i(-1, -1)
var score: int = 0
var alive: bool = true
var won: bool = false

var _queued: Array[Vector2i] = []
var _rng: RandomNumberGenerator


## [param config] uses the keys of assets/data/snake_config.json. Pass a seeded
## [param rng] for deterministic food placement.
func _init(config: Dictionary, rng: RandomNumberGenerator = null) -> void:
	cols = int(config.get("grid_cols", 20))
	rows = int(config.get("grid_rows", 20))
	start_length = int(config.get("start_length", 3))
	base_tick_ms = int(config.get("base_tick_ms", 150))
	min_tick_ms = int(config.get("min_tick_ms", 60))
	tick_step_ms = int(config.get("tick_step_ms", 10))
	foods_per_speedup = maxi(1, int(config.get("foods_per_speedup", 5)))
	input_buffer_size = maxi(1, int(config.get("input_buffer_size", 2)))
	_rng = rng if rng != null else RandomNumberGenerator.new()
	reset()


## Starts a new run: the snake sits mid-board facing right, with fresh food.
func reset() -> void:
	body.clear()
	var head := Vector2i(cols / 2, rows / 2)
	for i in start_length:
		body.append(head - Vector2i(i, 0))
	direction = RIGHT
	_queued.clear()
	score = 0
	alive = true
	won = false
	spawn_food()


## Queues a turn for an upcoming tick. Turns that repeat or reverse the
## direction in effect at that tick, or that overflow the buffer, are rejected.
func queue_direction(dir: Vector2i) -> bool:
	if not alive or _queued.size() >= input_buffer_size:
		return false
	var last: Vector2i = _queued.back() if not _queued.is_empty() else direction
	if dir == last or dir == -last:
		return false
	_queued.append(dir)
	return true


## Advances the snake one cell and returns what happened.
func step() -> StepResult:
	if not alive:
		return StepResult.DIED
	if not _queued.is_empty():
		direction = _queued.pop_front()
	var next: Vector2i = body[0] + direction
	var eating := next == food
	if next.x < 0 or next.y < 0 or next.x >= cols or next.y >= rows:
		alive = false
		return StepResult.DIED
	# The tail cell is vacated this tick unless the snake is growing.
	var blocking := body.slice(0, body.size() if eating else body.size() - 1)
	if next in blocking:
		alive = false
		return StepResult.DIED
	body.push_front(next)
	if not eating:
		body.pop_back()
		return StepResult.MOVED
	score += 1
	if not spawn_food():
		won = true
		alive = false
		return StepResult.WON
	return StepResult.ATE


## Places food on a random free cell. Returns false when the board is full.
func spawn_food() -> bool:
	var free: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			if cell not in body:
				free.append(cell)
	if free.is_empty():
		food = Vector2i(-1, -1)
		return false
	food = free[_rng.randi_range(0, free.size() - 1)]
	return true


## Current tick length in milliseconds; it shrinks every [member foods_per_speedup] points.
func tick_ms() -> int:
	return maxi(min_tick_ms, base_tick_ms - (score / foods_per_speedup) * tick_step_ms)
