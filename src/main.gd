extends Node2D
## Snake game scene: loads config, drives [SnakeLogic] on a timer, reads
## input and draws the board and HUD with immediate-mode drawing.

const CONFIG_PATH := "res://assets/data/snake_config.json"
const SAVE_PATH := "user://snake_save.json"
const HUD_HEIGHT := 60
const COLOR_BG := Color("#14161f")
const COLOR_BOARD := Color("#1c1f2b")
const COLOR_GRID := Color("#232737")
const COLOR_HEAD := Color("#7dff8a")
const COLOR_BODY := Color("#3ddc5a")
const COLOR_FOOD := Color("#ff6b6b")
const COLOR_TEXT := Color("#e8eaf2")

var logic: SnakeLogic
var cell_px: int = 28
var best: int = 0
var paused: bool = false
var started: bool = false

var _timer: Timer


func _ready() -> void:
	var config := _load_config()
	cell_px = int(config.get("cell_px", 28))
	logic = SnakeLogic.new(config)
	best = _load_best()
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	_restart_timer()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_UP, KEY_W:
			_steer(SnakeLogic.UP)
		KEY_DOWN, KEY_S:
			_steer(SnakeLogic.DOWN)
		KEY_LEFT, KEY_A:
			_steer(SnakeLogic.LEFT)
		KEY_RIGHT, KEY_D:
			_steer(SnakeLogic.RIGHT)
		KEY_P, KEY_SPACE:
			if started and logic.alive:
				paused = not paused
		KEY_R, KEY_ENTER:
			if not logic.alive:
				logic.reset()
				started = false
				paused = false
				_restart_timer()
	queue_redraw()


func _steer(dir: Vector2i) -> void:
	if paused:
		return
	started = true
	logic.queue_direction(dir)


func _on_tick() -> void:
	if not started or paused or not logic.alive:
		return
	var before := logic.tick_ms()
	logic.step()
	if logic.score > best:
		best = logic.score
		_save_best()
	if logic.tick_ms() != before:
		_restart_timer()
	queue_redraw()


func _restart_timer() -> void:
	_timer.start(logic.tick_ms() / 1000.0)


func _draw() -> void:
	var w := logic.cols * cell_px
	var h := logic.rows * cell_px
	draw_rect(Rect2(0, 0, w, h + HUD_HEIGHT), COLOR_BG)
	var origin := Vector2(0, HUD_HEIGHT)
	draw_rect(Rect2(origin, Vector2(w, h)), COLOR_BOARD)
	for x in range(1, logic.cols):
		draw_line(origin + Vector2(x * cell_px, 0), origin + Vector2(x * cell_px, h), COLOR_GRID)
	for y in range(1, logic.rows):
		draw_line(origin + Vector2(0, y * cell_px), origin + Vector2(w, y * cell_px), COLOR_GRID)
	if logic.food.x >= 0:
		var c := origin + (Vector2(logic.food) + Vector2(0.5, 0.5)) * cell_px
		draw_circle(c, cell_px * 0.38, COLOR_FOOD)
	for i in logic.body.size():
		var p := origin + Vector2(logic.body[i]) * cell_px
		draw_rect(Rect2(p + Vector2(2, 2), Vector2(cell_px - 4, cell_px - 4)), COLOR_HEAD if i == 0 else COLOR_BODY)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(16, 38), "Score: %d" % logic.score, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, COLOR_TEXT)
	draw_string(font, Vector2(16, 38), "Best: %d" % best, HORIZONTAL_ALIGNMENT_RIGHT, w - 32, 24, COLOR_TEXT)
	var msg := ""
	if logic.won:
		msg = "You win!  Press R"
	elif not logic.alive:
		msg = "Game over  -  press R"
	elif paused:
		msg = "Paused"
	elif not started:
		msg = "Arrow keys / WASD to start"
	if msg != "":
		var band_y := HUD_HEIGHT + h * 0.75
		draw_rect(Rect2(0, band_y - 40, w, 80), Color(0, 0, 0, 0.6))
		draw_string(font, Vector2(0, band_y + 10), msg, HORIZONTAL_ALIGNMENT_CENTER, w, 28, COLOR_TEXT)


func _load_config() -> Dictionary:
	var text := FileAccess.get_file_as_string(CONFIG_PATH)
	var data = JSON.parse_string(text)
	if data is Dictionary:
		return data
	push_error("Could not parse %s; using defaults" % CONFIG_PATH)
	return {}


func _load_best() -> int:
	if not FileAccess.file_exists(SAVE_PATH):
		return 0
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return int(data.get("best", 0)) if data is Dictionary else 0


func _save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"best": best}))
