extends RefCounted
## Unit tests for SnakeLogic. Every method named test_* is run by tests/run_tests.gd.

const CONFIG := {
	"grid_cols": 10, "grid_rows": 10, "start_length": 3,
	"base_tick_ms": 150, "min_tick_ms": 60, "tick_step_ms": 10,
	"foods_per_speedup": 5, "input_buffer_size": 2,
}

var failures: Array[String] = []


func _make() -> SnakeLogic:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	return SnakeLogic.new(CONFIG, rng)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func test_starts_centered_moving_right() -> void:
	var s := _make()
	var expected: Array[Vector2i] = [Vector2i(5, 5), Vector2i(4, 5), Vector2i(3, 5)]
	_check(s.body == expected, "start body %s" % [s.body])
	_check(s.direction == SnakeLogic.RIGHT, "start direction")
	_check(s.food not in s.body, "food not on snake")


func test_step_moves_head_and_keeps_length() -> void:
	var s := _make()
	s.food = Vector2i(0, 0)
	_check(s.step() == SnakeLogic.StepResult.MOVED, "moved")
	_check(s.body[0] == Vector2i(6, 5) and s.body.size() == 3, "head moved, length kept")


func test_eating_grows_and_scores() -> void:
	var s := _make()
	s.food = Vector2i(6, 5)
	_check(s.step() == SnakeLogic.StepResult.ATE, "ate")
	_check(s.body.size() == 4 and s.score == 1, "grew and scored")
	_check(s.food not in s.body, "new food on a free cell")


func test_reverse_and_repeat_turns_rejected() -> void:
	var s := _make()
	_check(not s.queue_direction(SnakeLogic.LEFT), "reverse rejected")
	_check(not s.queue_direction(SnakeLogic.RIGHT), "same direction rejected")
	_check(s.queue_direction(SnakeLogic.UP), "perpendicular accepted")


func test_input_buffer_quick_double_turn() -> void:
	var s := _make()
	s.food = Vector2i(0, 0)
	_check(s.queue_direction(SnakeLogic.UP), "up queued")
	_check(s.queue_direction(SnakeLogic.LEFT), "left after up queued")
	_check(not s.queue_direction(SnakeLogic.DOWN), "buffer full")
	s.step()
	s.step()
	_check(s.body[0] == Vector2i(4, 4), "up then left: head %s" % [s.body[0]])


func test_wall_collision_kills() -> void:
	var s := _make()
	s.food = Vector2i(0, 0)
	for i in 4:
		_check(s.step() == SnakeLogic.StepResult.MOVED, "move %d" % i)
	_check(s.step() == SnakeLogic.StepResult.DIED and not s.alive, "hit right wall")


func test_self_collision_kills() -> void:
	var s := _make()
	s.food = Vector2i(0, 0)
	s.body = [Vector2i(5, 5), Vector2i(4, 5), Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 5)] as Array[Vector2i]
	s.direction = SnakeLogic.UP
	_check(s.step() == SnakeLogic.StepResult.DIED, "bit own body")


func test_moving_into_vacating_tail_is_allowed() -> void:
	var s := _make()
	s.food = Vector2i(0, 0)
	s.body = [Vector2i(5, 5), Vector2i(5, 4), Vector2i(4, 4), Vector2i(4, 5)] as Array[Vector2i]
	s.direction = SnakeLogic.LEFT
	_check(s.step() == SnakeLogic.StepResult.MOVED, "chased own tail safely")


func test_speed_curve_clamps_at_minimum() -> void:
	var s := _make()
	_check(s.tick_ms() == 150, "base speed")
	s.score = 5
	_check(s.tick_ms() == 140, "first speedup")
	s.score = 500
	_check(s.tick_ms() == 60, "clamped to minimum")


func test_filling_board_wins() -> void:
	var s := SnakeLogic.new({"grid_cols": 2, "grid_rows": 2, "start_length": 1})
	s.body = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i]
	s.direction = SnakeLogic.RIGHT
	s.food = Vector2i(1, 0)
	_check(s.step() == SnakeLogic.StepResult.WON and s.won, "win on full board")
