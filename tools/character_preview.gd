# CharacterPreview.gd
# QA / art-check scene: renders the player figure and the three infected
# archetypes side by side, at 3x, on the mission backdrop. Used to review the
# character read before touching a level.
extends Node2D

const ITEMS := [
	{"kind": "player", "variant": "", "label": "PLAYER / ELENA", "weapon": "bat"},
	{"kind": "zombie", "variant": "shambler", "label": "SHAMBLER", "weapon": "fists"},
	{"kind": "zombie", "variant": "runner", "label": "RUNNER", "weapon": "fists"},
	{"kind": "zombie", "variant": "bloated", "label": "BLOATED", "weapon": "fists"},
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

	var x := 210.0
	for item in ITEMS:
		var holder := Node2D.new()
		holder.position = Vector2(x, 380)
		add_child(holder)

		var fig := TopDownFigure.new()
		if item["kind"] == "player":
			fig.setup(TopDownFigure.look_for("player"))
		else:
			var look := TopDownFigure.look_for("zombie", item["variant"])
			fig.setup(look)
			fig.hunch = float(look.get("hunch", 0.85))
			fig.scale = Vector2.ONE * clampf(float(look.get("build", 1.0)), 0.85, 1.35)
		fig.weapon = item["weapon"]
		fig.walk = 0.55
		fig.phase = x * 0.05
		fig.scale *= 3.0
		holder.add_child(fig)

		var name_label := Label.new()
		name_label.text = item["label"]
		name_label.add_theme_color_override("font_color", Color("#e6e1d5"))
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.position = Vector2(x - 170, 560)
		name_label.size = Vector2(340, 30)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(name_label)

		var size_label := Label.new()
		size_label.text = "%s  ·  %s" % [item["kind"].to_upper(), str(item["variant"]).to_upper() if item["variant"] != "" else "BOSS"]
		size_label.add_theme_color_override("font_color", Color("#6f7d75"))
		size_label.add_theme_font_size_override("font_size", 13)
		size_label.position = Vector2(x - 170, 592)
		size_label.size = Vector2(340, 22)
		size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(size_label)

		x += 300.0
