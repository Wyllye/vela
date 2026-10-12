extends SceneTree
## Roda todos os testes sem abrir o jogo:
##   godot --headless --path . -s res://tests/run_tests.gd
## Sai com código 1 se algum falhar (o CI usa isso).

const SUITES := [
	"res://tests/test_grid.gd",
	"res://tests/test_player.gd",
	"res://tests/test_rooms.gd",
	"res://tests/test_nen.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_game.gd",
	"res://tests/test_techniques.gd",
]


func _initialize() -> void:
	var total := 0
	var failed := 0
	for path: String in SUITES:
		if not ResourceLoader.exists(path):
			continue
		var script: GDScript = load(path)
		var suite_name := path.get_file().get_basename()
		for m in script.get_script_method_list():
			var method: String = m["name"]
			if not method.begins_with("test_"):
				continue
			var suite: Object = script.new()
			total += 1
			suite.call(method)
			var errs: Array = suite.get("_failures")
			suite.call("cleanup")
			if errs.is_empty():
				print("  ok      %s.%s" % [suite_name, method])
			else:
				failed += 1
				print("  FALHOU  %s.%s" % [suite_name, method])
				for e in errs:
					print("          - %s" % e)
	print("\n%d testes, %d falhas" % [total, failed])
	quit(1 if failed > 0 else 0)
