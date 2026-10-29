extends SceneTree
## Minimal headless test runner (no gdUnit4 dependency):
##   godot --headless --path . -s res://tests/run_tests.gd
## Runs every test_* method in the suites below and exits non-zero on failure.

const SUITES := ["res://tests/unit/snake/snake_logic_test.gd"]


func _initialize() -> void:
	var passed := 0
	var failed := 0
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL could not load ", path)
			continue
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var suite = script.new()
			suite.call(name)
			if suite.failures.is_empty():
				passed += 1
				print("PASS ", name)
			else:
				failed += 1
				print("FAIL ", name, ": ", ", ".join(suite.failures))
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
