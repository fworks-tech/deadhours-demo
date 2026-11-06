# FacingPreview.gd
# Art check: the same character rendered facing north, east, south and west, plus
# a zombie facing north. Verifies that the face only shows when the character is
# turned toward the camera.
extends Node2D

const DIRS := [
	{"name": "NORTH (back of head)", "dir": Vector2(0, -1)},
	{"name": "EAST (profile)", "dir": Vector2(1, 0)},
	{"name": "SOUTH (face)", "dir": Vector2(0, 1)},
	{"name": "WEST (profile)", "dir": Vector2(-1, 0)},
	{"name": "ZOMBIE / NORTH", "dir": Vector2(0, -1)},
]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0b0e11"))
	var bg := ColorRect.new()
	bg.color = Color("#0b0e11")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := CanvasLayer.new()
	layer.layer = -1
	layer.add_child(bg)
	add_child(layer)

	var x := 160.0
	for item in DIRS:
		var holder := Node2D.new()
		holder.position = Vector2(x, 300)
		var dir: Vector2 = item["dir"]
		holder.rotation = dir.angle() + PI * 0.5
		add_child(holder)

		var fig := TopDownFigure.new()
		if String(item["name"]).begins_with("ZOMBIE"):
			var look := TopDownFigure.look_for("zombie", "shambler")
			fig.setup(look)
			fig.hunch = float(look.get("hunch", 0.85))
		else:
			fig.setup(TopDownFigure.look_for("player"))
			fig.weapon = "knife"
		fig.view_dir = dir
		fig.walk = 0.0
		fig.scale = Vector2.ONE * 3.4
		holder.add_child(fig)

		var label := Label.new()
		label.text = item["name"]
		label.add_theme_color_override("font_color", Color("#e6e1d5"))
		label.add_theme_font_size_override("font_size", 16)
		label.position = Vector2(x - 130, 470)
		label.size = Vector2(260, 24)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)

		x += 255.0
