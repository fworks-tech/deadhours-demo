extends Node
func _ready() -> void:
	var ok := true
	for key in ["elena", "shambler", "runner", "bloated"]:
		var data := TopDownFigure.sheet_data(key)
		var tex: Texture2D = data[0]
		var meta: Dictionary = data[1]
		if tex == null or meta.is_empty():
			ok = false
			print("SHEET MISSING ", key)
			continue
		print("SHEET ", key, " ", tex.get_width(), "x", tex.get_height(),
			" frames=", meta.get("frames"), " dirs=", meta.get("directions"))
	var f := TopDownFigure.new()
	f.setup(TopDownFigure.look_for("player"))
	print("SHEET runtime_sheet_loaded=", f.sheet != null)
	var z := TopDownFigure.new()
	z.setup(TopDownFigure.look_for("zombie", "runner"))
	print("SHEET zombie_sheet_loaded=", z.sheet != null)
	get_tree().quit()
