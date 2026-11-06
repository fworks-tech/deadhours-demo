# TopDownPlayer.gd
# Hotline Miami-style top-down player: 8-direction movement, dash, aim,
# one-hit-kill melee and hitscan firearms. Works with mouse, keyboard and
# dual-stick touch input (the mission feeds touch_move / touch_aim / touch_fire).
extends CharacterBody2D
class_name TopDownPlayer

signal died()

# One-hit-kill weapon table. Melee uses an arc check, firearms use hitscan.
const WEAPONS := {
	"fists": {"label": "FISTS", "melee": true, "range": 46.0, "arc": 70.0, "cooldown": 0.26, "noise": 0.0, "ammo": 0, "pellets": 1, "spread": 0.0},
	"bat": {"label": "BAT", "melee": true, "range": 62.0, "arc": 85.0, "cooldown": 0.40, "noise": 90.0, "ammo": 0, "pellets": 1, "spread": 0.0},
	"knife": {"label": "KNIFE", "melee": true, "range": 48.0, "arc": 60.0, "cooldown": 0.26, "noise": 40.0, "ammo": 0, "pellets": 1, "spread": 0.0},
	"pistol": {"label": "PISTOL", "melee": false, "range": 900.0, "arc": 0.0, "cooldown": 0.26, "noise": 900.0, "ammo": 7, "pellets": 1, "spread": 2.2},
	"shotgun": {"label": "SHOTGUN", "melee": false, "range": 520.0, "arc": 0.0, "cooldown": 0.62, "noise": 1100.0, "ammo": 4, "pellets": 5, "spread": 13.0},
}

@export var speed: float = 268.0
@export var accel: float = 2400.0
@export var friction: float = 2800.0
@export var dash_speed: float = 720.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.85

var mission: Node = null
var alive: bool = true
var in_cover: bool = false
var can_act: bool = true

var aim_dir: Vector2 = Vector2.RIGHT
var facing: Vector2 = Vector2.RIGHT
var weapon_id: String = "bat"
var ammo: int = 0
var move_input: Vector2 = Vector2.ZERO

var _attack_cd: float = 0.0
var _dash_left: float = 0.0
var _dash_cd_left: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _swing_t: float = 0.0
var _muzzle_t: float = 0.0
var _hit_flash_t: float = 0.0
var figure: TopDownFigure = null

func _ready() -> void:
	collision_layer = 1 << 1  # player
	collision_mask = (1 << 0) | (1 << 3)  # walls + props
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 3
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	shape.shape = circle
	add_child(shape)

	figure = TopDownFigure.new()
	figure.name = "Figure"
	figure.setup(TopDownFigure.look_for("player"))
	add_child(figure)

	set_weapon(weapon_id, -1)

func set_weapon(id: String, ammo_override: int = -1) -> void:
	if not WEAPONS.has(id):
		id = "fists"
	weapon_id = id
	var w: Dictionary = WEAPONS[id]
	ammo = ammo_override if ammo_override >= 0 else int(w.get("ammo", 0))
	if mission:
		mission.update_weapon_hud()

func weapon() -> Dictionary:
	return WEAPONS.get(weapon_id, WEAPONS["fists"])

func weapon_label() -> String:
	var w := weapon()
	if bool(w.get("melee", false)):
		return str(w.get("label", "MELEE"))
	return "%s %d" % [str(w.get("label", "GUN")), ammo]

func _physics_process(delta: float) -> void:
	if _attack_cd > 0.0:
		_attack_cd -= delta
	if _dash_cd_left > 0.0:
		_dash_cd_left -= delta
	if _swing_t > 0.0:
		_swing_t -= delta
	if _muzzle_t > 0.0:
		_muzzle_t -= delta
	if _hit_flash_t > 0.0:
		_hit_flash_t -= delta

	if not alive or in_cover or not can_act:
		velocity = Vector2.ZERO
		move_and_slide()
		_sync_figure()
		queue_redraw()
		return

	# --- movement input (keyboard first, then touch from the mission) ---
	var kb := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	var dir := Vector2.ZERO
	if kb.length() > 0.15:
		dir = kb.normalized()
	elif mission and mission.touch_move.length() > 0.12:
		dir = mission.touch_move.normalized()

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_dir * dash_speed
	else:
		var target := dir * speed
		if dir.length() > 0.05:
			velocity = velocity.move_toward(target, accel * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if dir.length() > 0.05:
			facing = dir

	# --- dash ---
	if _dash_left <= 0.0 and _dash_cd_left <= 0.0 and dir.length() > 0.05 and _dash_pressed():
		_dash_left = dash_duration
		_dash_cd_left = dash_cooldown
		_dash_dir = dir
		velocity = _dash_dir * dash_speed
		if mission:
			mission.shake_camera(2.0)

	move_and_slide()
	_update_aim(dir)

	if _fire_pressed():
		_attack()
	if _interact_pressed() and mission:
		mission.try_interact(global_position)

	_sync_figure()
	queue_redraw()

func _sync_figure() -> void:
	if figure == null:
		return
	figure.walk = clampf(velocity.length() / maxf(speed, 1.0), 0.0, 1.0)
	figure.swing = clampf(_swing_t * 3.4, 0.0, 1.0)
	figure.hurt = clampf(_hit_flash_t * 6.0, 0.0, 1.0)
	figure.dead = not alive
	figure.covered = in_cover
	figure.weapon = weapon_id
	figure.view_dir = aim_dir

func _update_aim(move_dir: Vector2) -> void:
	var touch_aim := Vector2.ZERO
	if mission:
		touch_aim = mission.touch_aim
	if touch_aim.length() > 0.18:
		aim_dir = touch_aim.normalized()
	elif mission and mission.touch_mode:
		var target := _nearest_target()
		if target:
			aim_dir = global_position.direction_to(target.global_position)
		elif aim_dir == Vector2.ZERO:
			aim_dir = move_dir if move_dir.length() > 0.05 else Vector2.DOWN
	else:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 6.0:
			aim_dir = to_mouse.normalized()
		elif move_dir.length() > 0.05:
			aim_dir = move_dir
	if aim_dir == Vector2.ZERO:
		aim_dir = Vector2.RIGHT
	rotation = aim_dir.angle() + PI * 0.5

func _nearest_target() -> Node2D:
	if mission == null:
		return null
	var best: Node2D = null
	var best_d := 640.0
	for e in mission.enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d > best_d:
			continue
		var to_e: Vector2 = global_position.direction_to(e.global_position)
		if to_e.dot(aim_dir if aim_dir != Vector2.ZERO else facing) < 0.35:
			continue
		if mission.is_wall_between(global_position, e.global_position):
			continue
		best = e
		best_d = d
	return best

func _dash_pressed() -> bool:
	if mission and mission.has_method("consume_dash") and mission.consume_dash():
		return true
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT)

func _fire_pressed() -> bool:
	if mission and mission.touch_fire:
		return true
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_J)

func _interact_pressed() -> bool:
	if mission and mission.has_method("consume_interact") and mission.consume_interact():
		return true
	return Input.is_key_pressed(KEY_E)

func _attack() -> void:
	if _attack_cd > 0.0:
		return
	var w := weapon()
	_attack_cd = float(w.get("cooldown", 0.3))
	if bool(w.get("melee", false)):
		_melee_attack(w)
	else:
		_firearm_attack(w)

func _melee_attack(w: Dictionary) -> void:
	_swing_t = 0.16
	var reach: float = float(w.get("range", 50.0))
	var half_arc: float = deg_to_rad(float(w.get("arc", 70.0)) * 0.5)
	var hit_any := false
	if mission:
		for e in mission.enemies.duplicate():
			if not is_instance_valid(e) or not e.alive:
				continue
			var to_e: Vector2 = global_position.direction_to(e.global_position)
			if to_e.angle_to(aim_dir) > half_arc:
				continue
			if global_position.distance_to(e.global_position) > reach + 14.0:
				continue
			if mission.is_wall_between(global_position, e.global_position):
				continue
			e.die(aim_dir)
			hit_any = true
		if float(w.get("noise", 0.0)) > 0.0:
			mission.emit_noise(global_position, float(w.get("noise", 0.0)), self)
	if hit_any and mission:
		mission.shake_camera(2.5)

func _firearm_attack(w: Dictionary) -> void:
	if ammo <= 0:
		weapon_id = "fists"
		ammo = 0
		if mission:
			mission.flash_message("OUT OF AMMO")
			mission.update_weapon_hud()
		return
	ammo -= 1
	_muzzle_t = 0.06
	var pellets := int(w.get("pellets", 1))
	var spread := deg_to_rad(float(w.get("spread", 0.0)))
	var max_range := float(w.get("range", 900.0))
	for i in range(pellets):
		var dir := aim_dir.rotated(randf_range(-spread, spread) * 0.5)
		var hit: Dictionary = _cast_shot(dir, max_range)
		if not hit.is_empty():
			var col = hit.get("collider")
			if col and col.has_method("die") and col != self:
				col.die(dir)
		if mission:
			mission.spawn_tracer(global_position + dir * 16.0, hit.get("position", global_position + dir * max_range), Color("#ffd9a0"))
	if mission:
		mission.emit_noise(global_position, float(w.get("noise", 800.0)), self)
		mission.shake_camera(4.0)
		mission.update_weapon_hud()
	if ammo <= 0:
		weapon_id = "fists"
		if mission:
			mission.flash_message("OUT OF AMMO")

func _cast_shot(dir: Vector2, max_range: float) -> Dictionary:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * max_range, (1 << 0) | (1 << 2) | (1 << 3))
	q.exclude = [get_rid()]
	return space.intersect_ray(q)

func kill() -> void:
	if not alive:
		return
	alive = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	aim_dir = Vector2.ZERO
	if figure:
		figure.dead = true
	died.emit()
	if mission:
		mission.on_player_died()
	queue_redraw()

func _draw() -> void:
	# The figure child draws the body. Here we only add the read-at-a-glance
	# combat feedback that must sit in the same rotated space.
	var w := weapon()
	if not alive:
		return
	if _muzzle_t > 0.0:
		draw_circle(Vector2(2, -30), 7.0, Color(1.0, 0.85, 0.45, 0.9))
		draw_circle(Vector2(2, -30), 13.0, Color(1.0, 0.7, 0.3, 0.22))
	if _swing_t > 0.0 and bool(w.get("melee", false)):
		var alpha: float = clampf(_swing_t * 5.0, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 42.0, -PI * 0.5 - 0.95, -PI * 0.5 + 0.95, 16, Color(1, 1, 1, alpha * 0.28), 5.0, true)
