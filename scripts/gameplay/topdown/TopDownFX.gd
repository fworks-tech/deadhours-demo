# TopDownFX.gd
# Combat feedback layer: muzzle flashes, tracers, impact sparks, blood spray,
# blood pools and smears, glass break, explosions (with chain reactions and
# scorch decals), ambient fire, shell casings, and the red damage vignette.
#
# All effects are procedural: no audio or texture assets required, so they work
# on a fresh checkout and stay inside the neon-noir palette.
extends Node2D
class_name TopDownFX

const BLOOD := Color("#8f1220")
const BLOOD_DARK := Color("#4a0a11")
const SPARK := Color("#ffd08a")
const SMOKE := Color("#2a2d31")
const EMBER := Color("#ff8b3d")

var mission: Node = null

const SFX_DIR := "res://assets/audio/sfx/%s.wav"
static var _sfx_cache: Dictionary = {}
static var _soft: Texture2D = null

static func sfx(name: String) -> AudioStream:
	if _sfx_cache.has(name):
		return _sfx_cache[name]
	var path := SFX_DIR % name
	if not ResourceLoader.exists(path):
		_sfx_cache[name] = null
		return null
	var stream := load(path)
	_sfx_cache[name] = stream
	return stream

func play(name: String, pitch: float = 1.0) -> void:
	var stream := sfx(name)
	if stream != null:
		AudioManager.play_sfx(stream, pitch * randf_range(0.97, 1.04))
static var _shard: Texture2D = null

# ------------------------------------------------------------------ textures

static func soft_dot() -> Texture2D:
	if _soft != null:
		return _soft
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(16):
		for x in range(16):
			var d := Vector2(x - 7.5, y - 7.5).length() / 7.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, pow(a, 1.6)))
	_soft = ImageTexture.create_from_image(img)
	return _soft

static func shard_tex() -> Texture2D:
	if _shard != null:
		return _shard
	var img := Image.create(10, 10, false, Image.FORMAT_RGBA8)
	for y in range(10):
		for x in range(10):
			# triangular splinter
			var inside := x <= y and x < 8
			img.set_pixel(x, y, Color(1, 1, 1, 1.0 if inside else 0.0))
	_shard = ImageTexture.create_from_image(img)
	return _shard

# ------------------------------------------------------------------ plumbing

func _particles(pos: Vector2, cfg: Dictionary) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = int(cfg.get("amount", 12))
	p.lifetime = float(cfg.get("lifetime", 0.5))
	p.one_shot = true
	p.explosiveness = float(cfg.get("explosiveness", 0.95))
	p.direction = cfg.get("direction", Vector2.RIGHT)
	p.spread = float(cfg.get("spread", 45.0))
	p.gravity = cfg.get("gravity", Vector2(0, 260))
	p.initial_velocity_min = float(cfg.get("vmin", 60.0))
	p.initial_velocity_max = float(cfg.get("vmax", 280.0))
	p.damping_min = float(cfg.get("damping_min", 30.0))
	p.damping_max = float(cfg.get("damping_max", 90.0))
	p.scale_amount_min = float(cfg.get("smin", 1.0))
	p.scale_amount_max = float(cfg.get("smax", 2.6))
	p.angular_velocity_min = float(cfg.get("spin_min", -180.0))
	p.angular_velocity_max = float(cfg.get("spin_max", 180.0))
	p.color = cfg.get("color", BLOOD)
	p.texture = cfg.get("texture", soft_dot())
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(cfg.get("radius", 4.0))
	p.z_index = int(cfg.get("z", 6))
	p.emitting = true
	add_child(p)
	var ttl: float = p.lifetime + 0.5
	get_tree().create_timer(ttl, true, false, true).timeout.connect(p.queue_free)
	return p

# ------------------------------------------------------------------ gunfire

func muzzle_flash(pos: Vector2, dir: Vector2, size: float = 1.0, weapon: String = "pistol") -> void:
	play("shot_shotgun" if weapon == "shotgun" else "shot_pistol")
	var f := Flash.new()
	f.position = pos
	f.dir = dir
	f.size = size
	add_child(f)
	var tween := create_tween()
	tween.tween_property(f, "modulate:a", 0.0, 0.09)
	tween.tween_callback(f.queue_free)

	# unburnt powder puff
	_particles(pos, {
		"amount": 5, "lifetime": 0.28, "vmin": 30, "vmax": 90,
		"direction": dir, "spread": 30, "gravity": Vector2(0, -20),
		"color": Color(0.85, 0.82, 0.72, 0.35), "smin": 2.0, "smax": 4.5,
		"damping_min": 90, "damping_max": 140, "z": 5,
	})

func casing(pos: Vector2, dir: Vector2) -> void:
	play("shell_ping", randf_range(0.9, 1.2))
	_particles(pos, {
		"amount": 1, "lifetime": 0.55, "vmin": 90, "vmax": 170,
		"direction": -dir.rotated(-0.8), "spread": 18, "gravity": Vector2(0, 420),
		"color": Color("#c9a35a"), "smin": 1.2, "smax": 1.8,
		"radius": 1.0, "texture": shard_tex(), "z": 5,
	})

func tracer(from: Vector2, to: Vector2, color: Color = Color("#ffd9a0"), width: float = 2.2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = width
	line.default_color = color
	line.z_index = 7
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.10)
	tween.tween_callback(line.queue_free)

func impact(pos: Vector2, normal: Vector2, kind: String = "wall") -> void:
	if kind == "glass":
		glass_break(pos, normal)
		return
	play("impact_wall", randf_range(0.9, 1.15))
	_particles(pos, {
		"amount": 7, "lifetime": 0.3, "vmin": 80, "vmax": 240,
		"direction": normal, "spread": 55, "gravity": Vector2(0, 320),
		"color": SPARK, "smin": 0.8, "smax": 1.8, "radius": 2.0, "z": 6,
	})
	_particles(pos, {
		"amount": 4, "lifetime": 0.45, "vmin": 20, "vmax": 70,
		"direction": normal, "spread": 70, "gravity": Vector2(0, -30),
		"color": Color(0.6, 0.6, 0.58, 0.5), "smin": 3.0, "smax": 6.0, "z": 5,
	})
	var hole := Scorch.new()
	hole.position = pos
	hole.radius = randf_range(3.0, 5.5)
	hole.ink = Color(0.03, 0.03, 0.035, 0.75)
	add_child(hole)

func glass_break(pos: Vector2, normal: Vector2) -> void:
	_particles(pos, {
		"amount": 16, "lifetime": 0.7, "vmin": 90, "vmax": 320,
		"direction": normal, "spread": 80, "gravity": Vector2(0, 520),
		"color": Color(0.72, 0.88, 0.92, 0.9), "smin": 1.2, "smax": 2.6,
		"texture": shard_tex(), "radius": 3.0, "z": 6,
	})
	var crack := Scorch.new()
	crack.position = pos
	crack.radius = 14.0
	crack.ink = Color(0.75, 0.9, 0.95, 0.10)
	add_child(crack)

# ------------------------------------------------------------------ blood

func blood_spray(pos: Vector2, dir: Vector2, amount: int = 16) -> void:
	play("flesh_hit", randf_range(0.85, 1.1))
	_particles(pos, {
		"amount": amount, "lifetime": 0.6, "vmin": 90, "vmax": 330,
		"direction": dir, "spread": 40, "gravity": Vector2(0, 300),
		"color": BLOOD, "smin": 1.4, "smax": 3.8, "radius": 3.0, "z": 6,
		"damping_min": 40, "damping_max": 100,
	})
	# fine mist
	_particles(pos, {
		"amount": 8, "lifetime": 0.35, "vmin": 30, "vmax": 120,
		"direction": dir, "spread": 80, "gravity": Vector2(0, 60),
		"color": Color(0.45, 0.05, 0.08, 0.55), "smin": 3.0, "smax": 7.0, "z": 5,
	})

func blood_pool(pos: Vector2, radius: float = 26.0) -> void:
	var pool := Pool.new()
	pool.position = pos
	pool.radius = radius
	add_child(pool)
	var tween := create_tween()
	tween.tween_property(pool, "grow", 1.0, 0.8).from(0.25)

func blood_smear(from: Vector2, to: Vector2, width: float = 22.0) -> void:
	var smear := Smear.new()
	smear.a = from
	smear.b = to
	smear.width = width
	add_child(smear)

# ------------------------------------------------------------------ death

func corpse_fx(pos: Vector2, dir: Vector2) -> void:
	blood_pool(pos + dir * 6.0, 30.0)
	blood_spray(pos, dir, 22)

# ------------------------------------------------------------------ explosions

func explosion(pos: Vector2, radius: float = 160.0) -> void:
	play("explosion", randf_range(0.92, 1.02))
	# core flash
	var ring := Ring.new()
	ring.position = pos
	ring.max_radius = radius
	add_child(ring)

	var flash := Flash.new()
	flash.position = pos
	flash.dir = Vector2.RIGHT
	flash.size = radius / 26.0
	flash.warm = true
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.30)

	# fireball, smoke column, debris
	_particles(pos, {
		"amount": 26, "lifetime": 0.55, "vmin": 120, "vmax": 520,
		"direction": Vector2.UP, "spread": 180, "gravity": Vector2(0, -40),
		"color": EMBER, "smin": 4.0, "smax": 11.0, "radius": radius * 0.22, "z": 8,
	})
	_particles(pos, {
		"amount": 22, "lifetime": 1.5, "vmin": 40, "vmax": 210,
		"direction": Vector2.UP, "spread": 180, "gravity": Vector2(0, -70),
		"color": Color(0.16, 0.16, 0.18, 0.75), "smin": 8.0, "smax": 22.0,
		"radius": radius * 0.3, "z": 7, "damping_min": 20, "damping_max": 60,
	})
	_particles(pos, {
		"amount": 18, "lifetime": 0.9, "vmin": 200, "vmax": 620,
		"direction": Vector2.UP, "spread": 180, "gravity": Vector2(0, 620),
		"color": Color(0.22, 0.2, 0.2, 0.9), "smin": 1.4, "smax": 3.6,
		"radius": 6.0, "texture": shard_tex(), "z": 7,
	})

	var scorch := Scorch.new()
	scorch.position = pos
	scorch.radius = radius * 0.62
	scorch.ink = Color(0.02, 0.02, 0.025, 0.65)
	add_child(scorch)

func ambient_fire(pos: Vector2, size: float = 1.0) -> void:
	var fire := CPUParticles2D.new()
	fire.position = pos
	fire.amount = 18
	fire.lifetime = 0.9
	fire.explosiveness = 0.0
	fire.direction = Vector2.UP
	fire.spread = 22.0
	fire.gravity = Vector2(0, -60)
	fire.initial_velocity_min = 20.0 * size
	fire.initial_velocity_max = 70.0 * size
	fire.scale_amount_min = 3.0 * size
	fire.scale_amount_max = 8.0 * size
	fire.color = EMBER
	fire.texture = soft_dot()
	fire.z_index = 5
	fire.emitting = true
	add_child(fire)

	var smoke := CPUParticles2D.new()
	smoke.position = pos + Vector2(0, -10)
	smoke.amount = 10
	smoke.lifetime = 2.2
	smoke.explosiveness = 0.0
	smoke.direction = Vector2.UP
	smoke.spread = 18.0
	smoke.gravity = Vector2(0, -30)
	smoke.initial_velocity_min = 15.0
	smoke.initial_velocity_max = 45.0
	smoke.scale_amount_min = 8.0 * size
	smoke.scale_amount_max = 18.0 * size
	smoke.color = Color(0.14, 0.14, 0.16, 0.5)
	smoke.texture = soft_dot()
	smoke.z_index = 4
	smoke.emitting = true
	add_child(smoke)

func damage_flash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0.55, 0.02, 0.06, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 0.45, 0.06)
	tween.tween_property(rect, "color:a", 0.0, 0.45)
	tween.tween_callback(layer.queue_free)

# ------------------------------------------------------------------ draw nodes

class Flash extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var size: float = 1.0
	var warm: bool = false

	func _ready() -> void:
		z_index = 9

	func _draw() -> void:
		var s := size
		if warm:
			draw_circle(Vector2.ZERO, 46.0 * s, Color(1.0, 0.72, 0.32, 0.22))
			draw_circle(Vector2.ZERO, 24.0 * s, Color(1.0, 0.9, 0.62, 0.55))
			draw_circle(Vector2.ZERO, 12.0 * s, Color(1, 1, 0.95, 0.9))
			return
		# star burst along the barrel
		var fwd := dir.normalized()
		var side := fwd.rotated(PI * 0.5)
		var pts := PackedVector2Array([
			fwd * 26.0 * s,
			fwd * 8.0 * s + side * 5.0 * s,
			fwd * 10.0 * s - side * 5.0 * s,
		])
		draw_colored_polygon(pts, Color(1.0, 0.95, 0.75, 0.9))
		draw_circle(fwd * 6.0 * s, 7.0 * s, Color(1.0, 0.88, 0.55, 0.55))
		draw_circle(Vector2.ZERO, 3.6 * s, Color(1, 1, 1, 0.85))

class Ring extends Node2D:
	var max_radius: float = 160.0
	var _t: float = 0.0

	func _ready() -> void:
		z_index = 8

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.45:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k: float = clampf(_t / 0.45, 0.0, 1.0)
		var r: float = max_radius * (0.2 + k * 0.95)
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.7, 0.35, 0.10 * (1.0 - k)))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.85, 0.6, 0.55 * (1.0 - k)), 3.0)

class Scorch extends Node2D:
	var radius: float = 20.0
	var ink: Color = Color(0, 0, 0, 0.7)

	func _ready() -> void:
		z_index = 1

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x * 13.0 + position.y * 7.0)
		draw_circle(Vector2.ZERO, radius, ink)
		for i in range(5):
			var off := Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
			draw_circle(off, radius * rng.randf_range(0.18, 0.45), ink)

class Pool extends Node2D:
	var radius: float = 26.0
	var grow: float = 1.0

	func _ready() -> void:
		z_index = 1

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(position.x * 11.0 + position.y * 5.0)
		var r: float = radius * grow
		draw_circle(Vector2.ZERO, r, Color(0.22, 0.02, 0.04, 0.85))
		draw_circle(Vector2.ZERO, r * 0.7, Color(0.32, 0.03, 0.05, 0.9))
		for i in range(7):
			var off := Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))
			draw_circle(off, r * rng.randf_range(0.12, 0.34), Color(0.26, 0.02, 0.04, 0.8))

class Smear extends Node2D:
	var a: Vector2 = Vector2.ZERO
	var b: Vector2 = Vector2(0, 100)
	var width: float = 22.0

	func _ready() -> void:
		z_index = 1

	func _draw() -> void:
		var steps := 14
		for i in range(steps + 1):
			var t := float(i) / float(steps)
			var p: Vector2 = a.lerp(b, t)
			var w: float = width * (0.55 + 0.45 * sin(t * PI))
			draw_circle(p, w * 0.5, Color(0.24, 0.02, 0.045, 0.55))
