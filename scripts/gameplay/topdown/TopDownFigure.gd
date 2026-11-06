# TopDownFigure.gd
# Layered 2D character renderer for the top-down layer.
#
# Draws a readable ~3/4 top-down figure out of shapes: shadow, legs with a walk
# cycle, jacket/torso, arms holding the current weapon, head with hair and face,
# blood and damage overlays, and a collapsed corpse. No sprite sheet required,
# but the look is data-driven (assets/data/characters.json) so a real sheet can
# replace it later without touching gameplay code.
#
# Local space convention: -Y is forward (the parent rotates the figure to aim).
extends Node2D
class_name TopDownFigure

var look: Dictionary = {}
var walk: float = 0.0          # 0 idle .. 1 full sprint
var phase: float = 0.0         # walk cycle phase (radians)
var swing: float = 0.0         # 0..1 attack swing amount
var dead: bool = false
var covered: bool = false
var hurt: float = 0.0          # 0..1 hit flash
var weapon: String = "bat"
var hunch: float = 0.0         # 0 human .. 1 heavy zombie stoop
# World-space direction the character is looking/aiming. The head is drawn in
# screen space from this, so facing north shows the back of the head.
var view_dir: Vector2 = Vector2.DOWN
# Optional baked sprite sheet (see tools/bake_character_sheets.gd). When present
# the blockout draw is replaced by real frames; everything else is unchanged.
var sheet: Texture2D = null
var sheet_meta: Dictionary = {}
var _breath: float = 0.0

static var _library: Dictionary = {}
static var _sheets: Dictionary = {}

static func sheet_data(key: String) -> Array:
	if _sheets.has(key):
		return _sheets[key]
	var base := "res://assets/images/sprites/topdown/%s_sheet" % key
	var tex: Texture2D = null
	var meta: Dictionary = {}
	if ResourceLoader.exists(base + ".png"):
		tex = load(base + ".png")
	if FileAccess.file_exists(base + ".json"):
		var f := FileAccess.open(base + ".json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				meta = parsed
	if tex == null:
		meta = {}
	_sheets[key] = [tex, meta]
	return _sheets[key]

static func library() -> Dictionary:
	if not _library.is_empty():
		return _library
	var path := "res://assets/data/characters.json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		_library = data
	return _library

static func look_for(kind: String, variant: String = "") -> Dictionary:
	var lib := library()
	if lib.is_empty():
		return {}
	if kind == "player":
		return lib.get("player", {}).duplicate(true)
	var zombies: Dictionary = lib.get("zombies", {})
	return zombies.get(variant, zombies.get("shambler", {})).duplicate(true)

func _ready() -> void:
	z_index = 1

func setup(l: Dictionary) -> void:
	look = l.duplicate(true)
	sheet = null
	sheet_meta = {}
	var key := str(look.get("sheet", ""))
	if not key.is_empty() and OS.get_environment("TD_NO_SHEET") != "1":
		var data := sheet_data(key)
		sheet = data[0]
		sheet_meta = data[1]
	queue_redraw()

func _process(delta: float) -> void:
	var speed := 9.5 if hunch < 0.5 else 6.2
	if walk > 0.02:
		phase += delta * speed * (0.55 + walk)
	_breath += delta * 1.8
	queue_redraw()

# ---------------------------------------------------------------- palette helpers

func _c(key: String, fallback: String) -> Color:
	return Color(str(look.get(key, fallback)))

func skin() -> Color: return _c("skin", "#d8a98a")
func hair() -> Color: return _c("hair", "#3a2118")
func top() -> Color: return _c("top", "#2f4a4a")
func top_dark() -> Color: return _c("top_dark", "#22383a")
func pants() -> Color: return _c("pants", "#2a2f3a")
func boots() -> Color: return _c("boots", "#191b20")
func accent() -> Color: return _c("accent", "#c8553d")
func blood() -> Color: return _c("blood", "#5a1418")

func is_zombie() -> bool:
	return bool(look.get("zombie", false))

func build() -> float:
	return float(look.get("build", 1.0))

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if sheet != null and not sheet_meta.is_empty():
		if dead:
			_draw_sheet_corpse()
		else:
			_draw_sheet()
		return
	if dead:
		_draw_corpse()
		return

	var b := build()
	var stoop := hunch * 3.0

	# ground shadow (squashed ellipse)
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.52))
	draw_circle(Vector2.ZERO, 13.0 * b, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# hair / ponytail behind the body
	_draw_hair_back()

	# legs
	var stride := 6.2 if hunch < 0.5 else 4.6
	var hip_y := 2.0
	var foot_y := 13.5 - hunch * 1.0
	for side in [-1.0, 1.0]:
		var ph: float = phase + (0.0 if side < 0.0 else PI)
		var s: float = sin(ph) * stride * walk
		var lift: float = maxf(0.0, sin(ph)) * 2.4 * walk
		var hip := Vector2(4.4 * side * b, hip_y)
		var foot := Vector2(4.4 * side * b + s * 0.6, foot_y - lift)
		draw_line(hip, foot, pants().darkened(0.18), 6.2 * b)
		draw_line(hip.lerp(foot, 0.25), foot, pants().lightened(0.10), 2.2 * b)
		draw_circle(foot, 3.3 * b, boots())
		# dragging foot for the shamblers: scuff mark
		if hunch > 0.5 and side > 0.0 and walk > 0.3:
			draw_line(foot, foot + Vector2(-4, 2), Color(0, 0, 0, 0.25), 2.0)

	# torso
	_draw_torso(b, stoop)

	# arms + weapon, forward of the torso
	_draw_arms(b, stoop)
	_draw_weapon(b)

	# head
	_draw_head(b, stoop)

	# damage overlays
	if hurt > 0.0:
		_draw_flash(b, stoop)
	if covered:
		draw_circle(Vector2(0, -2), 15.0 * b, Color(0.02, 0.03, 0.04, 0.45))

# ------------------------------------------------------------- baked sheet

func _sheet_indices() -> Vector2i:
	var frames := int(sheet_meta.get("frames", 8))
	var dirs := int(sheet_meta.get("directions", 8))
	var ang: float = view_dir.angle() if view_dir.length() > 0.01 else PI * 0.5
	var d := int(round(fposmod(ang + PI * 0.5, TAU) / TAU * float(dirs))) % dirs
	var f := 0
	if walk > 0.05:
		f = int(fposmod(phase, TAU) / TAU * float(frames)) % frames
	return Vector2i(f, d)

func _sheet_rect() -> Rect2:
	var fw := float(sheet_meta.get("frame_w", 128))
	var fh := float(sheet_meta.get("frame_h", 128))
	var idx := _sheet_indices()
	return Rect2(idx.x * fw, idx.y * fh, fw, fh)

func _sheet_world_size() -> Vector2:
	var fw := float(sheet_meta.get("frame_w", 128))
	var fh := float(sheet_meta.get("frame_h", 128))
	var scale_factor := maxf(0.2, float(sheet_meta.get("bake_scale", 2.0)))
	return Vector2(fw, fh) / scale_factor

func _draw_sheet() -> void:
	var size := _sheet_world_size()
	var tint := Color(1, 1, 1, 1)
	if hurt > 0.0:
		tint = tint.lerp(Color(2.4, 1.5, 1.5, 1.0), clampf(hurt, 0.0, 1.0))
	# the frames are baked per direction, so the node rotation is cancelled
	draw_set_transform(Vector2.ZERO, -global_rotation, Vector2.ONE)
	draw_texture_rect_region(sheet, Rect2(-size * 0.5, size), _sheet_rect(), tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# held weapon still comes from the live layer, so pickups read instantly
	_draw_weapon(build())
	if covered:
		draw_circle(Vector2(0, -2), 15.0 * build(), Color(0.02, 0.03, 0.04, 0.45))

func _draw_sheet_corpse() -> void:
	var size := _sheet_world_size()
	var fw := float(sheet_meta.get("frame_w", 128))
	var fh := float(sheet_meta.get("frame_h", 128))
	# south-facing frame laid on its side reads as a body on the floor
	var rect := Rect2(0, fh * 4.0, fw, fh)
	draw_set_transform(Vector2.ZERO, PI * 0.5, Vector2(1.0, 0.72))
	draw_texture_rect_region(sheet, Rect2(-size * 0.5, size), rect, Color(0.55, 0.5, 0.52, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_torso(b: float, stoop: float) -> void:
	var w := 11.0 * b
	var pts := PackedVector2Array([
		Vector2(-w, -7 - stoop), Vector2(-w * 0.86, 4 - stoop),
		Vector2(-w * 0.68, 11), Vector2(w * 0.68, 11),
		Vector2(w * 0.86, 4 - stoop), Vector2(w, -7 - stoop),
		Vector2(w * 0.62, -11 - stoop), Vector2(-w * 0.62, -11 - stoop),
	])
	draw_colored_polygon(pts, top())
	# left-side shading
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w, -7 - stoop), Vector2(-w * 0.86, 4 - stoop),
		Vector2(-w * 0.68, 11), Vector2(0, 11), Vector2(0, -11 - stoop),
	]), Color(top_dark(), 0.55))
	# collar
	draw_line(Vector2(-w * 0.55, -10 - stoop), Vector2(0, -6.5 - stoop), top_dark(), 2.4)
	draw_line(Vector2(w * 0.55, -10 - stoop), Vector2(0, -6.5 - stoop), top_dark(), 2.4)
	# belt + zipper
	draw_line(Vector2(-w * 0.7, 8.2), Vector2(w * 0.7, 8.2), pants().darkened(0.35), 2.6)
	draw_line(Vector2(0, -7), Vector2(0, 8), top_dark().darkened(0.15), 1.2)

	if is_zombie():
		_draw_zombie_damage(b, stoop)

func _draw_zombie_damage(b: float, stoop: float) -> void:
	# torn shirt: patches of exposed skin
	var wounds: Array = look.get("wounds", [])
	var i := 0
	for p in wounds:
		var v := Vector2(float(p[0]) * b, float(p[1]) + stoop * 0.4)
		draw_circle(v, float(p[2]), skin().darkened(0.18))
		draw_circle(v + Vector2(0, 1), float(p[2]) * 0.45, blood())
		i += 1
	# exposed ribs on one side
	if bool(look.get("ribs", false)):
		var base := Vector2(-6.0 * b, 2.0)
		for r in range(3):
			draw_line(base + Vector2(0, r * 3.0), base + Vector2(5.0, r * 3.0 - 1.0), Color("#cfc4a8"), 1.3)
	# dried blood down the chest
	draw_circle(Vector2(2.5 * b, -1.0), 3.4, Color(blood(), 0.85))
	draw_line(Vector2(2.5 * b, -1.0), Vector2(3.2 * b, 7.0), Color(blood(), 0.7), 2.0)

func _draw_arms(b: float, stoop: float) -> void:
	var shoulder_y := -6.0 - stoop
	var hand_front := Vector2(2.0, -15.0 - stoop * 0.6)
	var sleeve := top_dark().lightened(0.06)
	var flesh := skin()

	if is_zombie():
		# one arm reaching forward, one hanging broken
		var reach_side: float = 1.0 if float(look.get("reach", 1.0)) >= 0.0 else -1.0
		var reach := Vector2(3.0 * reach_side, -21.0 - stoop)
		draw_line(Vector2(9.0 * b * reach_side, shoulder_y), reach, sleeve, 6.0 * b)
		draw_circle(reach, 3.0 * b, flesh.darkened(0.1))
		# fingers
		for f in range(3):
			draw_line(reach, reach + Vector2(-2.5 + f * 2.0, -3.0), flesh.darkened(0.25), 1.4)
		var hang := Vector2(-10.0 * b, 7.0 + stoop)
		draw_line(Vector2(-9.5 * b, shoulder_y), hang, sleeve, 5.4 * b)
		draw_circle(hang, 2.8 * b, flesh.darkened(0.2))
	else:
		# both hands on the weapon, turning with the swing
		var off := Vector2(sin(swing * 2.2) * 5.0, 0.0)
		var left_hand := hand_front + Vector2(-2.6, 2.0) + off
		var right_hand := hand_front + Vector2(2.6, 0.0) + off
		draw_line(Vector2(-9.0 * b, shoulder_y), left_hand, sleeve, 5.6 * b)
		draw_line(Vector2(9.0 * b, shoulder_y), right_hand, sleeve, 5.6 * b)
		draw_circle(left_hand, 2.7 * b, flesh)
		draw_circle(right_hand, 2.7 * b, flesh)
		# jacket cuffs
		draw_circle(left_hand.lerp(Vector2(-9.0 * b, shoulder_y), 0.18), 3.0 * b, accent().darkened(0.25))
		draw_circle(right_hand.lerp(Vector2(9.0 * b, shoulder_y), 0.18), 3.0 * b, accent().darkened(0.25))

func _draw_weapon(b: float) -> void:
	var hand := Vector2(2.0, -15.0) + Vector2(sin(swing * 2.2) * 5.0, 0.0)
	var ang := swing * 1.5
	draw_set_transform(hand, ang, Vector2.ONE)
	match weapon:
		"bat":
			draw_line(Vector2.ZERO, Vector2(0, 4.0), Color("#2a2f33"), 3.4)
			draw_line(Vector2(0, 1.0), Vector2(0, -19.0), Color("#b9bec4"), 4.2)
			draw_line(Vector2(0, -8.0), Vector2(0, -18.0), Color("#d7dbe0"), 1.6)
		"knife":
			draw_line(Vector2.ZERO, Vector2(0, -11.0), Color("#cfd6dc"), 2.2)
			draw_line(Vector2(0, -6.0), Vector2(0, -11.0), Color(1, 1, 1, 0.65), 1.0)
		"pistol":
			draw_rect(Rect2(-1.4, -11.0, 2.8, 7.0), Color("#22262b"))
			draw_rect(Rect2(-1.0, 3.0, 2.0, 3.4), Color("#191d21"))
			draw_rect(Rect2(-1.4, -11.0, 2.8, 1.6), Color("#7f8890"))
		"shotgun":
			draw_rect(Rect2(-1.8, -24.0, 3.6, 19.0), Color("#2b2f33"))
			draw_rect(Rect2(-1.8, -24.0, 3.6, 5.0), Color("#43312a"))
			draw_line(Vector2(-2.2, -8.0), Vector2(2.2, -8.0), Color("#3a3f44"), 2.0)
		_:
			draw_circle(Vector2.ZERO, 2.4, skin().lightened(0.05))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_head(b: float, stoop: float) -> void:
	# The body rotates with the character, but a head should not: from a top-down
	# camera you only see the face when the character is turned toward the screen
	# (south). Draw the head screen-aligned at its rotated position instead.
	var head_pos := Vector2(0, -9.6 - stoop)
	var vd := view_dir
	if vd.length() < 0.01:
		vd = Vector2.DOWN
	vd = vd.normalized()
	var facing_camera: float = clampf(vd.y, 0.0, 1.0)   # 1 = south, 0 = side, 0 = north
	var back_view: bool = vd.y < -0.35
	var face_alpha: float = 0.0
	if not back_view:
		# profiles keep the face readable; full frontal only when looking south
		face_alpha = clampf(0.88 + 0.12 * vd.y, 0.88, 1.0)

	draw_set_transform(head_pos, -global_rotation, Vector2.ONE)

	# hair / skull mass
	draw_circle(Vector2.ZERO, 8.0 * b, hair())
	if bool(look.get("bald", false)):
		draw_circle(Vector2.ZERO, 7.4 * b, skin().darkened(0.08))
		draw_circle(Vector2(-2.2, -1.2), 2.2 * b, Color(blood(), 0.55))
		draw_circle(Vector2(2.6, 1.4), 1.7 * b, skin().darkened(0.22))
	elif is_zombie():
		var clumps: Array = look.get("clumps", [[-5, -1, 2.2], [5, 1, 2.0], [-2, -4, 1.8], [4, 3, 1.6]])
		for c in clumps:
			draw_circle(Vector2(float(c[0]) * b, float(c[1]) * b), float(c[2]) * b, hair().lightened(0.12))

	if back_view:
		# back of the head: hair sheen and the nape of the neck at the bottom
		draw_arc(Vector2(0, -1.0), 6.4 * b, PI * 1.15, PI * 1.85, 12, hair().lightened(0.18), 1.8)
		draw_circle(Vector2(0, 6.4) * b, 2.6 * b, skin().darkened(0.12))
		draw_circle(Vector2(0, 5.2) * b, 3.4 * b, Color(hair(), 0.9))
		# ears peek from the sides even from behind
		draw_circle(Vector2(-7.4, 0.6) * b, 1.7 * b, skin().darkened(0.15))
		draw_circle(Vector2(7.4, 0.6) * b, 1.7 * b, skin().darkened(0.15))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# face patch, pushed toward the camera side so side views read as a profile
	var face_center := vd * (1.5 * b)
	var face_radius: float = 5.4 * b * (0.74 + 0.26 * facing_camera)
	draw_circle(face_center, face_radius, Color(skin(), face_alpha))
	# ears
	var perp := Vector2(-vd.y, vd.x)
	draw_circle(face_center + perp * (7.2 * b), 1.8 * b, Color(skin().darkened(0.12), face_alpha))
	draw_circle(face_center - perp * (7.2 * b), 1.8 * b, Color(skin().darkened(0.12), face_alpha))

	_draw_face_screen(b, vd, perp, face_alpha, facing_camera)

	# fringe over the forehead: a hair crescent between the face and the crown
	draw_arc(face_center, 5.6 * b, PI * 1.05, PI * 1.95, 12, Color(hair(), face_alpha), 2.6 * b)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_face_screen(b: float, vd: Vector2, perp: Vector2, face_alpha: float, facing_camera: float) -> void:
	var eye_color := Color(str(look.get("eye", "#1b1512")))
	if is_zombie():
		eye_color = Color(str(look.get("eye", "#b7ff7a")))
		var glow := Color(eye_color.r, eye_color.g, eye_color.b, 0.30 * face_alpha)
		draw_circle(vd * (2.8 * b), 3.2 * b, glow)
		draw_circle(vd * (2.8 * b) + perp * (2.3 * b), 3.2 * b, glow)
		draw_circle(vd * (2.8 * b) - perp * (2.3 * b), 3.2 * b, glow)
	# eyes converge on the profile as the character turns away from the camera
	var sep: float = 2.2 * b * facing_camera
	var eye_pos := vd * (3.1 * b)
	for s in [-1.0, 1.0]:
		draw_circle(eye_pos + perp * (sep * s), 1.15 * b, Color(eye_color, face_alpha))
	# brow / brow ridge
	draw_line(eye_pos + perp * (sep + 1.2 * b) - vd * (1.0 * b),
		eye_pos + perp * (sep + 1.2 * b) + vd * (0.4 * b), Color(hair().darkened(0.2), face_alpha * 0.8), 1.1)
	draw_line(eye_pos - perp * (sep + 1.2 * b) - vd * (1.0 * b),
		eye_pos - perp * (sep + 1.2 * b) + vd * (0.4 * b), Color(hair().darkened(0.2), face_alpha * 0.8), 1.1)

	if is_zombie():
		# slack jaw, wider when it is looking at you
		var jaw := vd * (5.0 * b)
		var w := (2.2 + 0.8 * facing_camera) * b
		draw_colored_polygon(PackedVector2Array([
			jaw + perp * w + vd * (1.0 * b), jaw - perp * w + vd * (1.0 * b),
			jaw - perp * (w * 0.6), jaw + perp * (w * 0.6),
		]), Color("#1a0d10", face_alpha))
	else:
		draw_line(vd * (4.9 * b) + perp * (1.3 * b), vd * (4.9 * b) - perp * (1.3 * b),
			Color(0.25, 0.12, 0.12, 0.85 * face_alpha), 1.2)

func _draw_hair_back() -> void:
	if is_zombie() or bool(look.get("bald", false)):
		return
	match str(look.get("hairstyle", "short")):
		"ponytail":
			var sway := sin(phase * 0.5) * 1.2
			draw_line(Vector2(0, -3.0), Vector2(sway, 7.0), hair().darkened(0.12), 4.4)
			draw_circle(Vector2(0, -3.4), 2.6, accent().darkened(0.2))
		"bun":
			draw_circle(Vector2(0, -4.0), 4.2, hair().darkened(0.1))
		_:
			draw_circle(Vector2(0, -5.0), 6.2, hair().darkened(0.18))

func _draw_flash(b: float, stoop: float) -> void:
	var a: float = clampf(hurt, 0.0, 1.0) * 0.75
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11 * b, -7 - stoop), Vector2(-9, 11), Vector2(9, 11), Vector2(11 * b, -7 - stoop),
	]), Color(1, 1, 1, a))
	draw_circle(Vector2(0, -10 - stoop), 7.6 * b, Color(1, 1, 1, a * 0.9))

func _draw_corpse() -> void:
	var b := build()
	draw_set_transform(Vector2(2, 6), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 20.0 * b, Color(0.30, 0.02, 0.04, 0.55))
	draw_circle(Vector2.ZERO, 10.0 * b, Color(0.36, 0.03, 0.05, 0.75))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# sprawled torso
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.18, 0.62))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -7), Vector2(-9, 4), Vector2(-7, 11),
		Vector2(7, 11), Vector2(9, 4), Vector2(11, -7),
	]), top().darkened(0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(-2, -5), 6.6 * b, hair())
	draw_circle(Vector2(-2, -6.4), 4.6 * b, skin().darkened(0.2))
	# limp arm
	draw_line(Vector2(9, 1), Vector2(16, 6), top_dark().darkened(0.2), 4.4)
	draw_circle(Vector2(16, 6), 2.4, skin().darkened(0.25))
