extends SceneTree
## Run-and-observe capture: plays a short scripted run through real key events
## and saves screenshots to production/qa/evidence/. Needs a display (e.g. Xvfb):
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tests/capture/capture_gameplay.gd

const OUT_DIR := "res://production/qa/evidence/"

var _main: Node2D


func _initialize() -> void:
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	_run.call_deferred()


func _run() -> void:
	await _frames(5)
	_shot("godot-start")
	# Steer toward the food each tick until a few have been eaten.
	for i in 400:
		var logic: SnakeLogic = _main.logic
		if not logic.alive or logic.score >= 2:
			break
		var head := logic.body[0]
		var want := logic.direction
		if logic.food.x != head.x and logic.direction.x == 0:
			want = SnakeLogic.RIGHT if logic.food.x > head.x else SnakeLogic.LEFT
		elif logic.food.y != head.y and logic.direction.y == 0:
			want = SnakeLogic.DOWN if logic.food.y > head.y else SnakeLogic.UP
		if want != logic.direction or not _main.started:
			_press(_key_for(want if want != logic.direction else SnakeLogic.UP))
		await create_timer(logic.tick_ms() / 1000.0).timeout
	_shot("godot-playing")
	_press(KEY_P)
	await _frames(3)
	_shot("godot-paused")
	_press(KEY_P)
	_press(KEY_UP)
	while _main.logic.alive:
		await create_timer(0.05).timeout
	await _frames(3)
	_shot("godot-game-over")
	quit(0)


func _key_for(dir: Vector2i) -> Key:
	match dir:
		SnakeLogic.UP: return KEY_UP
		SnakeLogic.DOWN: return KEY_DOWN
		SnakeLogic.LEFT: return KEY_LEFT
	return KEY_RIGHT


func _press(key: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = key
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + name + ".png")
	img.save_png(path)
	print("saved ", path, " score=", _main.logic.score)
