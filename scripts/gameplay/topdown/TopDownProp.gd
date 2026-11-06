# TopDownProp.gd
# Flat, high-contrast furniture for the top-down layer: the kind of read you get
# in Hotline Miami, where every room is a coloured floor, a hard outline and a
# handful of chunky objects you can read at a glance (and shoot around).
#
# Local origin is the centre of the object's footprint.
extends Node2D
class_name TopDownProp

const OUTLINE := Color("#080a0c")
const WOOD := Color("#4b3a2b")
const WOOD_LIGHT := Color("#6a5340")
const FABRIC := Color("#3b4048")
const FABRIC_LIGHT := Color("#4d535c")
const METAL := Color("#5a6169")
const PORCELAIN := Color("#b9b4a6")
const SCREEN := Color("#2a3f46")

var ptype: String = "crate"
var size: Vector2 = Vector2(60, 40)
var seed: int = 0

func setup(t: String, s: Vector2, sd: int = 0) -> void:
	ptype = t
	size = s
	seed = sd
	queue_redraw()

func _draw() -> void:
	var r := Rect2(-size * 0.5, size)
	match ptype:
		"sofa": _sofa(r)
		"bed": _bed(r)
		"table": _table(r)
		"chair": _chair(r)
		"bench": _bench(r)
		"counter": _counter(r)
		"fridge": _fridge(r)
		"tv": _tv(r)
		"shelf": _shelf(r)
		"cabinet": _cabinet(r)
		"desk": _desk(r)
		"dumpster": _dumpster(r)
		"car": _car(r)
		"plant": _plant(r)
		"rug": _rug(r)
		"trash": _trash(r)
		"streetlight": _streetlight(r)
		_: _crate(r)

# ---------------------------------------------------------------- helpers

func _box(r: Rect2, fill: Color, thickness: float = 2.0) -> void:
	draw_rect(r, fill)
	draw_rect(r, OUTLINE, false, thickness)

func _gloss(r: Rect2, color: Color = Color(1, 1, 1, 0.06)) -> void:
	draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, maxf(3.0, r.size.y * 0.18))), color)

# ---------------------------------------------------------------- objects

func _sofa(r: Rect2) -> void:
	draw_rect(r, FABRIC)
	draw_rect(r, OUTLINE, false, 2.4)
	# backrest along the long side
	if r.size.x >= r.size.y:
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.34)), FABRIC.darkened(0.18))
		# cushions
		var n: int = max(2, int(r.size.x / 52.0))
		var w: float = r.size.x / float(n)
		for i in range(n):
			draw_rect(Rect2(r.position + Vector2(i * w + 3, r.size.y * 0.36), Vector2(w - 6, r.size.y * 0.58)), FABRIC_LIGHT)
			draw_rect(Rect2(r.position + Vector2(i * w + 3, r.size.y * 0.36), Vector2(w - 6, r.size.y * 0.58)), OUTLINE, false, 1.2)
		# armrests
		draw_rect(Rect2(r.position, Vector2(8, r.size.y)), FABRIC.darkened(0.28))
		draw_rect(Rect2(r.position + Vector2(r.size.x - 8, 0), Vector2(8, r.size.y)), FABRIC.darkened(0.28))
	else:
		draw_rect(Rect2(r.position, Vector2(r.size.x * 0.34, r.size.y)), FABRIC.darkened(0.18))
		draw_rect(Rect2(r.position + Vector2(r.size.x * 0.36, 4), r.size - Vector2(10, 8)), FABRIC_LIGHT)
		draw_rect(Rect2(r.position + Vector2(r.size.x * 0.36, 4), r.size - Vector2(10, 8)), OUTLINE, false, 1.2)

func _bed(r: Rect2) -> void:
	_box(r, Color("#4a4048"))
	# blanket
	draw_rect(Rect2(r.position + Vector2(4, r.size.y * 0.34), Vector2(r.size.x - 8, r.size.y * 0.62)), Color("#6d2f38"))
	draw_rect(Rect2(r.position + Vector2(4, r.size.y * 0.34), Vector2(r.size.x - 8, r.size.y * 0.62)), OUTLINE, false, 1.4)
	# pillow
	draw_rect(Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, maxf(12.0, r.size.y * 0.2))), Color("#c9c2b2"))
	draw_rect(Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, maxf(12.0, r.size.y * 0.2))), OUTLINE, false, 1.2)
	# headboard
	draw_rect(Rect2(r.position, Vector2(r.size.x, 7)), WOOD.darkened(0.25))

func _table(r: Rect2) -> void:
	_box(r, WOOD)
	draw_rect(Rect2(r.position + Vector2(5, 5), r.size - Vector2(10, 10)), WOOD_LIGHT)
	draw_rect(Rect2(r.position + Vector2(5, 5), r.size - Vector2(10, 10)), OUTLINE, false, 1.0)
	# a cup
	draw_circle(r.position + r.size * 0.68, 4.2, PORCELAIN)

func _chair(r: Rect2) -> void:
	_box(r, WOOD.darkened(0.1), 1.8)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 6)), WOOD_LIGHT)

func _bench(r: Rect2) -> void:
	_box(r, WOOD, 2.0)
	var slats: int = 3
	for i in range(slats):
		var y: float = r.position.y + 5 + i * (r.size.y - 10) / float(slats)
		draw_line(Vector2(r.position.x + 5, y), Vector2(r.end.x - 5, y), WOOD_LIGHT, 2.0)
	# legs
	draw_circle(r.position + Vector2(7, r.size.y - 6), 3.0, METAL.darkened(0.3))
	draw_circle(Vector2(r.end.x - 7, r.end.y - 6), 3.0, METAL.darkened(0.3))

func _counter(r: Rect2) -> void:
	_box(r, Color("#3a3f3a"))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 10)), Color("#8d8677"))
	# register
	var reg := Rect2(r.position + Vector2(r.size.x * 0.55, 14), Vector2(30, 24))
	draw_rect(reg, Color("#22262a"))
	draw_rect(reg, OUTLINE, false, 1.6)
	draw_rect(Rect2(reg.position + Vector2(4, 4), Vector2(22, 9)), SCREEN)
	# underside shadow
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 6), Vector2(r.size.x, 6)), Color(0, 0, 0, 0.35))

func _fridge(r: Rect2) -> void:
	_box(r, Color("#b6b1a3"))
	draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, r.size.y - 8)), Color("#d6d1c2"))
	draw_line(Vector2(r.position.x + r.size.x - 12, r.position.y + 10),
		Vector2(r.position.x + r.size.x - 12, r.end.y - 10), METAL.darkened(0.2), 3.0)
	draw_line(r.position + Vector2(8, r.size.y * 0.45), Vector2(r.end.x - 8, r.position.y + r.size.y * 0.45), OUTLINE, 1.4)

func _tv(r: Rect2) -> void:
	_box(r, Color("#1c1f22"), 1.8)
	draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(r.size.x - 10, r.size.y * 0.6)), SCREEN)
	# scanline glow
	draw_rect(Rect2(r.position + Vector2(5, 5), Vector2(r.size.x - 10, 3)), Color(0.55, 0.85, 0.9, 0.35))
	draw_circle(r.position + r.size * 0.5, maxf(r.size.x, r.size.y) * 0.42, Color(0.3, 0.8, 0.9, 0.05))

func _shelf(r: Rect2) -> void:
	_box(r, Color("#2f3338"), 2.0)
	var rows: int = 3
	for i in range(rows):
		var y: float = r.position.y + (i + 1) * r.size.y / float(rows + 1)
		draw_line(Vector2(r.position.x + 3, y), Vector2(r.end.x - 3, y), METAL.darkened(0.25), 3.0)
		# goods
		var rng := RandomNumberGenerator.new()
		rng.seed = seed + i * 17
		var x: float = r.position.x + 8
		while x < r.end.x - 10:
			var w: float = rng.randf_range(5.0, 12.0)
			var c: Color = [Color("#8d4a3a"), Color("#3f6a58"), Color("#8a7a3a"), Color("#4a5a7a")][rng.randi_range(0, 3)]
			draw_rect(Rect2(x, y - 9, w, 8), c)
			x += w + 4

func _cabinet(r: Rect2) -> void:
	_box(r, Color("#3b4250"))
	draw_line(Vector2(r.position.x + r.size.x * 0.5, r.position.y + 4),
		Vector2(r.position.x + r.size.x * 0.5, r.end.y - 4), OUTLINE, 1.6)
	for side in [0.32, 0.68]:
		draw_circle(Vector2(r.position.x + r.size.x * side, r.position.y + r.size.y * 0.5), 2.4, PORCELAIN)

func _desk(r: Rect2) -> void:
	_box(r, Color("#4a3b2e"))
	draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), Color("#5c4a39"))
	# papers
	draw_rect(Rect2(r.position + Vector2(12, 10), Vector2(26, 18)), Color("#d8d2c2"))
	draw_line(r.position + Vector2(15, 16), r.position + Vector2(34, 16), Color("#7a7365"), 1.0)
	# monitor
	draw_rect(Rect2(r.position + Vector2(r.size.x - 44, 10), Vector2(34, 22)), Color("#1b1e21"))
	draw_rect(Rect2(r.position + Vector2(r.size.x - 41, 13), Vector2(28, 15)), SCREEN)

func _dumpster(r: Rect2) -> void:
	_box(r, Color("#2e4a3a"), 2.4)
	draw_rect(Rect2(r.position + Vector2(-4, -6), Vector2(r.size.x + 8, 10)), Color("#3a5a46"))
	draw_rect(Rect2(r.position + Vector2(-4, -6), Vector2(r.size.x + 8, 10)), OUTLINE, false, 1.6)
	draw_circle(r.position + Vector2(12, r.size.y), 5.0, Color("#141618"))
	draw_circle(Vector2(r.end.x - 12, r.end.y), 5.0, Color("#141618"))

func _car(r: Rect2) -> void:
	var body := Rect2(r.position, r.size)
	draw_rect(body, Color("#3b2f36"))
	draw_rect(body, OUTLINE, false, 2.6)
	# roof + windshield
	var roof := Rect2(r.position + Vector2(r.size.x * 0.26, r.size.y * 0.16), Vector2(r.size.x * 0.44, r.size.y * 0.68))
	draw_rect(roof, Color("#242a30"))
	draw_rect(roof, OUTLINE, false, 1.8)
	draw_rect(Rect2(roof.position + Vector2(0, -r.size.y * 0.1), Vector2(roof.size.x, r.size.y * 0.18)), Color("#5f7c86"))
	# headlights
	draw_circle(Vector2(r.end.x - 4, r.position.y + 8), 3.0, Color("#ffe9b0"))
	draw_circle(Vector2(r.end.x - 4, r.end.y - 8), 3.0, Color("#ffe9b0"))

func _plant(r: Rect2) -> void:
	var c := r.position + r.size * 0.5
	draw_circle(c, minf(r.size.x, r.size.y) * 0.5, Color("#2c3a2c"))
	draw_circle(c, minf(r.size.x, r.size.y) * 0.42, Color("#3f5c3f"))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in range(6):
		var a: float = rng.randf_range(0.0, TAU)
		var d: float = rng.randf_range(0.1, 0.42) * minf(r.size.x, r.size.y)
		draw_circle(c + Vector2(cos(a), sin(a)) * d, rng.randf_range(4.0, 8.0), Color("#4d7048"))
	draw_circle(c, minf(r.size.x, r.size.y) * 0.22, Color("#26302a"))

func _rug(r: Rect2) -> void:
	draw_rect(r, Color("#3a2330"))
	draw_rect(r, Color("#5a3446"), false, 3.0)
	var inner := r.grow(-9)
	draw_rect(inner, Color("#4a2b3a"), false, 2.0)
	# pattern
	var step := 18.0
	var y := inner.position.y + 6
	while y < inner.end.y - 6:
		draw_line(Vector2(inner.position.x + 6, y), Vector2(inner.end.x - 6, y), Color(0, 0, 0, 0.16), 2.0)
		y += step

func _trash(r: Rect2) -> void:
	var c := r.position + r.size * 0.5
	draw_circle(c, minf(r.size.x, r.size.y) * 0.5, Color("#24282b"))
	draw_circle(c + Vector2(4, -3), minf(r.size.x, r.size.y) * 0.32, Color("#3a4045"))
	draw_rect(r, OUTLINE, false, 2.0)

func _streetlight(r: Rect2) -> void:
	var c := r.position + r.size * 0.5
	draw_circle(c, 120.0, Color(1.0, 0.86, 0.55, 0.045))
	draw_circle(c, 64.0, Color(1.0, 0.86, 0.55, 0.05))
	draw_circle(c, 9.0, Color("#1a1d20"))
	draw_circle(c, 6.0, Color("#ffe6a8"))
	draw_circle(c, 3.0, Color(1, 1, 0.9, 0.9))

func _crate(r: Rect2) -> void:
	_box(r, Color("#2f3338"))
	draw_rect(Rect2(r.position + Vector2(6, 6), r.size - Vector2(12, 12)), Color("#383d43"), false, 2.0)
	draw_line(r.position + Vector2(6, 6), r.end - Vector2(6, 6), Color("#454b52"), 2.0)
	draw_line(Vector2(r.end.x - 6, r.position.y + 6), Vector2(r.position.x + 6, r.end.y - 6), Color("#454b52"), 2.0)
