# bake_character_sheets.gd
# Turns the procedural blockout figures into real game-ready sprite sheets.
#
# For each character it renders the TopDownFigure into a transparent SubViewport
# at 8 directions x 8 walk frames, 128 px per frame (2x world density), and saves:
#   assets/images/sprites/topdown/<char>_sheet.png
#   assets/images/sprites/topdown/<char>_sheet.json  (frame grid + pivot + fps)
#
# The runtime loads the sheet automatically (TopDownFigure.sheet) and falls back
# to the procedural draw if it is missing, so painted frames can replace these
# later without touching gameplay code.
#
# Run with a real renderer (not --headless):
#   xvfb-run -a godot --path . res://tools/BakeCharacterSheets.tscn
extends Node

const OUT_DIR := "res://assets/images/sprites/topdown"
const FRAME := 128
const FRAMES := 8
const DIRS := 8
const BAKE_SCALE := 2.0

const SPECS := [
	{"file": "elena", "kind": "player", "variant": "", "weapon": "fists"},
	{"file": "shambler", "kind": "zombie", "variant": "shambler", "weapon": "fists"},
	{"file": "runner", "kind": "zombie", "variant": "runner", "weapon": "fists"},
	{"file": "bloated", "kind": "zombie", "variant": "bloated", "weapon": "fists"},
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var vp := SubViewport.new()
	vp.size = Vector2i(FRAME, FRAME)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)

	for spec in SPECS:
		await _bake(vp, spec)

	get_tree().quit()

func _bake(vp: SubViewport, spec: Dictionary) -> void:
	var fig := TopDownFigure.new()
	if spec["kind"] == "player":
		fig.setup(TopDownFigure.look_for("player"))
	else:
		var look := TopDownFigure.look_for("zombie", spec["variant"])
		fig.setup(look)
		fig.hunch = float(look.get("hunch", 0.85))
		fig.scale = Vector2.ONE * clampf(float(look.get("build", 1.0)), 0.85, 1.35)
	fig.weapon = str(spec["weapon"])
	fig.walk = 1.0
	fig.scale *= BAKE_SCALE
	fig.set_process(false)   # bake exact phases, no idle animation
	fig.position = Vector2(FRAME * 0.5, FRAME * 0.55)
	vp.add_child(fig)
	await get_tree().process_frame

	var sheet := Image.create(FRAME * FRAMES, FRAME * DIRS, false, Image.FORMAT_RGBA8)
	var painted := 0
	for d in range(DIRS):
		var dir: Vector2 = Vector2.UP.rotated(TAU * float(d) / float(DIRS))
		fig.view_dir = dir
		fig.rotation = dir.angle() + PI * 0.5
		for f in range(FRAMES):
			fig.phase = TAU * float(f) / float(FRAMES)
			fig.queue_redraw()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			if img == null:
				push_error("bake: no image for %s dir %d frame %d" % [spec["file"], d, f])
				continue
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, FRAME, FRAME), Vector2i(f * FRAME, d * FRAME))
			painted += 1

	var png_path := "%s/%s_sheet.png" % [OUT_DIR, spec["file"]]
	sheet.save_png(ProjectSettings.globalize_path(png_path))

	var meta := {
		"character": spec["file"],
		"frame_w": FRAME,
		"frame_h": FRAME,
		"frames": FRAMES,
		"directions": DIRS,
		"bake_scale": BAKE_SCALE,
		"fps": 10,
		"pivot": [FRAME * 0.5, FRAME * 0.55],
		"layout": "rows = directions starting at north, clockwise; columns = walk frames",
		"source": "res://scripts/gameplay/topdown/TopDownFigure.gd",
	}
	var meta_path := "%s/%s_sheet.json" % [OUT_DIR, spec["file"]]
	var f := FileAccess.open(meta_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta, "  "))
		f.close()
	print("bake: %s frames=%d -> %s" % [spec["file"], painted, png_path])
