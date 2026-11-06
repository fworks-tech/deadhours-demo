# TopDownObjectArt.gd
# Shared art for interactive objects: doors, lockers, weapon pickups, exit marker.
#
# One drawing routine per object, used by BOTH the live nodes and
# tools/bake_object_sprites.gd, so the shipped PNGs and the in-game fallback can
# never drift apart. Nodes prefer the baked sprite when it exists.
extends RefCounted
class_name TopDownObjectArt

const OUTLINE := Color("#080a0c")
const PAD := 8.0          # transparent margin baked around every object
const BAKE_SCALE := 2.0

static var _tex: Dictionary = {}

# Sprite key -> Texture2D (null when the asset has not been baked yet).
static func tex(key: String) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var path := "res://assets/images/sprites/objects/%s.png" % key
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[key] = t
	return t

# World-space size a baked sprite should be drawn at (footprint + baked padding).
static func draw_size(size: Vector2) -> Vector2:
	return size + Vector2(PAD, PAD) * 2.0

static func draw_sprite(ci: CanvasItem, key: String, size: Vector2) -> bool:
	var t := tex(key)
	if t == null:
		return false
	var d := draw_size(size)
	ci.draw_texture_rect(t, Rect2(-d * 0.5, d), false)
	return true

# ---------------------------------------------------------------- door

static func door(ci: CanvasItem, size: Vector2, open: bool, horizontal: bool) -> void:
	var r := Rect2(-size * 0.5, size)
	if open:
		ci.draw_rect(r, Color("#15191c"))
		ci.draw_rect(r.grow(-1.0), Color("#0a0d0f"), false, 2.0)
		# light bleeding in from the other side
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 3.0)), Color(0.45, 0.78, 0.62, 0.55))
		if not horizontal:
			ci.draw_rect(Rect2(r.position, Vector2(3.0, r.size.y)), Color(0.45, 0.78, 0.62, 0.45))
		return

	ci.draw_rect(r, Color("#3c2a20"))
	ci.draw_rect(r, OUTLINE, false, 2.2)
	ci.draw_rect(r.grow(-4.0), Color("#54392a"), false, 2.0)
	# panel split
	if horizontal:
		ci.draw_line(Vector2(r.position.x + 8, 0), Vector2(r.end.x - 8, 0), Color("#2b1e17"), 2.0)
	else:
		ci.draw_line(Vector2(0, r.position.y + 8), Vector2(0, r.end.y - 8), Color("#2b1e17"), 2.0)
	# hinges
	ci.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(4, 8)), Color("#6d6a5e"))
	ci.draw_rect(Rect2(Vector2(r.position.x + 2, r.end.y - 10), Vector2(4, 8)), Color("#6d6a5e"))
	# handle
	var handle := Vector2(r.position.x + r.size.x * 0.32, 0)
	if not horizontal:
		handle = Vector2(0, r.position.y + r.size.y * 0.32)
	ci.draw_circle(handle, 3.4, Color("#c9a86a"))
	ci.draw_circle(handle, 1.6, Color("#f2dfae"))

# ---------------------------------------------------------------- locker

static func locker(ci: CanvasItem, size: Vector2, open: bool = false) -> void:
	var r := Rect2(-size * 0.5, size)
	ci.draw_rect(r, Color("#252c30"))
	ci.draw_rect(r, OUTLINE, false, 2.2)
	ci.draw_rect(r.grow(-4.0), Color("#39454b"), false, 2.0)
	if open:
		# dark interior with the door swung to the side
		ci.draw_rect(r.grow(-5.0), Color("#0c1012"))
		var flap := Rect2(Vector2(r.position.x + r.size.x * 0.58, r.position.y + 3.0),
			Vector2(r.size.x * 0.38, r.size.y - 6.0))
		ci.draw_rect(flap, Color("#39454b"))
		ci.draw_rect(flap, OUTLINE, false, 1.8)
		ci.draw_line(flap.position + Vector2(4, 4), Vector2(flap.end.x - 4, flap.end.y - 4), Color("#2a3438"), 2.0)
		return
	# vents
	for i in range(3):
		var y: float = r.position.y + 14 + i * 9
		ci.draw_line(Vector2(r.position.x + 7, y), Vector2(r.end.x - 7, y), Color("#161c1f"), 3.0)
	ci.draw_line(Vector2(0, r.position.y + 5), Vector2(0, r.end.y - 5), Color("#141a1d"), 2.0)
	ci.draw_rect(Rect2(-2, r.size.y * 0.1, 4, 10), Color("#8f9a9e"))

# ---------------------------------------------------------------- pickups

static func pickup(ci: CanvasItem, kind: String) -> void:
	# soft pool of light under the weapon so it reads on a dark floor
	ci.draw_circle(Vector2(0, 5), 14.0, Color(0, 0, 0, 0.35))
	ci.draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.82, 0.45, 0.10))
	match kind:
		"bat":
			ci.draw_line(Vector2(-8, 9), Vector2(9, -8), Color("#7a5433"), 5.0)
			ci.draw_line(Vector2(-8, 9), Vector2(9, -8), OUTLINE, 1.4)
			ci.draw_line(Vector2(-3, 4), Vector2(0, 1), Color("#2b2018"), 6.0)
			ci.draw_circle(Vector2(-9, 10), 3.6, Color("#3a2a1e"))
		"knife":
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-9, 6), Vector2(6, -9), Vector2(9, -6), Vector2(-6, 9)]), Color("#c8cdd2"))
			ci.draw_polyline(PackedVector2Array([Vector2(-9, 6), Vector2(6, -9), Vector2(9, -6), Vector2(-6, 9), Vector2(-9, 6)]), OUTLINE, 1.2)
			ci.draw_line(Vector2(-9, 9), Vector2(-4, 4), Color("#2a2f34"), 4.0)
		"pistol":
			ci.draw_rect(Rect2(-10, -6, 20, 6), Color("#3b4148"))
			ci.draw_rect(Rect2(-10, -6, 20, 6), OUTLINE, false, 1.2)
			ci.draw_rect(Rect2(-7, 0, 7, 9), Color("#2d3238"))
			ci.draw_rect(Rect2(-7, 0, 7, 9), OUTLINE, false, 1.2)
			ci.draw_rect(Rect2(9, -5, 3, 3), Color("#8f9aa2"))
		"shotgun":
			ci.draw_rect(Rect2(-13, -4, 26, 5), Color("#454c52"))
			ci.draw_rect(Rect2(-13, -4, 26, 5), OUTLINE, false, 1.2)
			ci.draw_rect(Rect2(-13, -6, 8, 9), Color("#5a3a24"))
			ci.draw_rect(Rect2(-13, -6, 8, 9), OUTLINE, false, 1.2)
			ci.draw_rect(Rect2(2, -3, 6, 3), Color("#2a3035"))
			ci.draw_rect(Rect2(11, -3, 3, 3), Color("#8f9aa2"))
		_:
			ci.draw_circle(Vector2.ZERO, 8.0, Color("#d9c07a"))
			ci.draw_circle(Vector2.ZERO, 3.0, Color("#2a2620"))

# ---------------------------------------------------------------- exit

static func exit_marker(ci: CanvasItem, size: Vector2, label: String = "EXIT") -> void:
	var r := Rect2(Vector2.ZERO, size)
	# floor glow
	for i in range(5):
		var t := float(i) / 5.0
		ci.draw_rect(r.grow(-t * 12.0), Color(0.35, 0.95, 0.7, 0.05 + t * 0.03))
	# threshold posts
	ci.draw_rect(Rect2(r.position.x, r.position.y, 5, r.size.y), Color(0.45, 0.95, 0.68, 0.75))
	ci.draw_rect(Rect2(r.end.x - 5, r.position.y, 5, r.size.y), Color(0.45, 0.95, 0.68, 0.75))
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5), Color(0.45, 0.95, 0.68, 0.85))
	# chevrons pointing in
	for i in range(3):
		var y: float = r.position.y + 20 + i * 12
		ci.draw_polyline(PackedVector2Array([
			Vector2(r.position.x + 12, y + 6), Vector2(r.position.x + 20, y), Vector2(r.position.x + 12, y - 6)
		]), Color(0.6, 1.0, 0.8, 0.55), 2.0)
	ci.draw_string(ThemeDB.fallback_font, Vector2(10, 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 1.0, 0.85, 0.8))
