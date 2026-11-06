# TopDownEnemy.gd
# Top-down infected: patrols waypoints, detects the player with a vision cone
# and line-of-sight, reacts to noise, chases, and kills in one hit.
# Dying is also one hit. Every kill is permanent for the mission.
extends CharacterBody2D
class_name TopDownEnemy

enum State { PATROL, ALERT, CHASE, ATTACK, DEAD }

const ALERT_COLOR := Color("#ff2f4f")

@export var patrol_speed: float = 104.0
@export var chase_speed: float = 178.0
@export var view_range: float = 340.0
@export var view_angle: float = 96.0
@export var hearing_range: float = 320.0
@export var zombie_type: String = "shambler"

var mission: Node = null
var alive: bool = true
var state: int = State.PATROL
var patrol_points: Array = []
var patrol_index: int = 0
var wait_timer: float = 0.0
var facing: Vector2 = Vector2.DOWN
var weapon_id: String = "fists"
var last_seen: Vector2 = Vector2.ZERO
var idle_phase: float = 0.0

var _cone: Polygon2D
var _see_timer: float = 0.0
var _los_timer: float = 0.0
var _shoot_cd: float = 0.0
var _windup: float = 0.0
var _lost_timer: float = 0.0
var _cone_tick: int = 0
var _lunge_left: float = 0.0
var _lunge_cd: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO
var figure: TopDownFigure = null

func _ready() -> void:
	collision_layer = 1 << 2  # enemy
	collision_mask = (1 << 0) | (1 << 2) | (1 << 3)  # walls, other enemies, props
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	shape.shape = circle
	add_child(shape)

	_cone = Polygon2D.new()
	_cone.color = Color(1.0, 0.24, 0.33, 0.07)
	_cone.z_as_relative = false
	_cone.z_index = 1
	_cone.polygon = PackedVector2Array([Vector2.ZERO])
	add_child(_cone)

	var look := TopDownFigure.look_for("zombie", zombie_type)
	figure = TopDownFigure.new()
	figure.name = "Figure"
	figure.setup(look)
	figure.hunch = float(look.get("hunch", 0.85))
	figure.weapon = weapon_id
	# infected read bigger/smaller by archetype without changing hitboxes much
	figure.scale = Vector2.ONE * clampf(float(look.get("build", 1.0)), 0.85, 1.35)
	add_child(figure)

	idle_phase = randf() * TAU
	_update_cone()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if _shoot_cd > 0.0:
		_shoot_cd -= delta
	if mission == null or mission.player == null:
		return
	if not mission.player.alive:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_cone()
		return

	if _lunge_cd > 0.0:
		_lunge_cd -= delta
	if _lunge_left > 0.0:
		_lunge_left -= delta

	_see_timer -= delta
	if _see_timer <= 0.0:
		_see_timer = 0.08
		if _can_see_player():
			last_seen = mission.player.global_position
			_lost_timer = 3.0
			if state != State.CHASE and state != State.ATTACK:
				_become_alert()
		else:
			if state == State.CHASE or state == State.ATTACK:
				_lost_timer -= 0.08
				if _lost_timer <= 0.0:
					state = State.PATROL

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.ALERT:
			_do_alert(delta)
		State.CHASE, State.ATTACK:
			_do_chase(delta)

	move_and_slide()
	_update_cone()
	_sync_figure(delta)
	queue_redraw()

func _sync_figure(_delta: float) -> void:
	if figure == null:
		return
	figure.dead = not alive
	if alive:
		figure.rotation = facing.angle() + PI * 0.5
		figure.view_dir = facing
	figure.walk = clampf(velocity.length() / maxf(chase_speed, 1.0), 0.0, 1.0)
	figure.hunch = clampf(float(TopDownFigure.look_for("zombie", zombie_type).get("hunch", 0.85)), 0.0, 1.0)
	figure.swing = 1.0 if (_lunge_left > 0.0 or state == State.ATTACK) else 0.0
	if state == State.CHASE or state == State.ATTACK:
		figure.look["eye"] = "#ff5c5c"
	else:
		figure.look["eye"] = str(TopDownFigure.look_for("zombie", zombie_type).get("eye", "#c8ff7a"))

func _become_alert() -> void:
	state = State.CHASE
	if mission:
		mission.raise_alarm(global_position, 420.0, self)

func alert_to(pos: Vector2) -> void:
	if not alive:
		return
	last_seen = pos
	_lost_timer = 4.0
	if state == State.PATROL:
		state = State.ALERT
	if _cone:
		_cone.color = Color(1.0, 0.24, 0.33, 0.16)

func _do_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		facing = facing.rotated(sin(idle_phase + Time.get_ticks_msec() * 0.0004) * 0.4).normalized()
		return
	var target: Vector2 = patrol_points[patrol_index]
	if wait_timer > 0.0:
		wait_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		return
	if global_position.distance_to(target) < 12.0:
		wait_timer = 0.9
		patrol_index = (patrol_index + 1) % patrol_points.size()
		return
	var dir: Vector2 = global_position.direction_to(target)
	facing = dir
	velocity = dir * patrol_speed

func _do_alert(delta: float) -> void:
	var dir: Vector2 = global_position.direction_to(last_seen)
	facing = dir
	if global_position.distance_to(last_seen) < 18.0:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		wait_timer -= delta
		if wait_timer <= 0.0:
			state = State.PATROL
		return
	velocity = dir * (chase_speed * 0.7)

func _do_chase(delta: float) -> void:
	var to_player: Vector2 = global_position.direction_to(last_seen)
	var dist: float = global_position.distance_to(last_seen)
	facing = to_player

	# zombie lunge: a short telegraphed burst when the player is just out of reach
	if _lunge_left <= 0.0 and _lunge_cd <= 0.0 and dist > 46.0 and dist < 150.0 and zombie_type != "bloated":
		_lunge_left = 0.32
		_lunge_cd = 1.7
		_lunge_dir = to_player

	if _lunge_left > 0.0:
		velocity = _lunge_dir * (chase_speed * 1.85)
		_update_cone_color()
		return

	if dist < 44.0:
		state = State.ATTACK
		velocity = velocity.move_toward(Vector2.ZERO, 1600.0 * delta)
		_attack_player(delta)
		return

	state = State.CHASE
	# approach with a tiny lateral wobble so a corridor pile-up still resolves
	var strafe := to_player.rotated(PI * 0.5) * sin(Time.get_ticks_msec() * 0.004 + idle_phase) * 0.18
	velocity = (to_player + strafe).normalized() * chase_speed
	_update_cone_color()

func _attack_player(delta: float) -> void:
	if weapon_id == "pistol":
		if _shoot_cd > 0.0:
			return
		_shoot_cd = 0.9 + randf() * 0.35
		_shoot_player()
		return
	_windup += delta
	if _windup >= 0.22:
		_windup = 0.0
		if mission and mission.player and mission.player.alive:
			if global_position.distance_to(mission.player.global_position) < 52.0:
				mission.player.kill()
				if mission:
					mission.shake_camera(3.0)

func _shoot_player() -> void:
	if mission == null or mission.player == null:
		return
	var dir: Vector2 = global_position.direction_to(mission.player.global_position)
	dir = dir.rotated(randf_range(-0.05, 0.05))
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * 800.0, (1 << 0) | (1 << 1) | (1 << 3))
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var end_point: Vector2 = hit.get("position", global_position + dir * 800.0)
	if mission:
		mission.spawn_tracer(global_position + dir * 16.0, end_point, Color("#ff9f7a"))
		mission.shake_camera(3.0)
	if not hit.is_empty() and hit.get("collider") == mission.player:
		mission.player.kill()

func _can_see_player() -> bool:
	if mission == null or mission.player == null:
		return false
	var p = mission.player
	if not p.alive or p.in_cover:
		return false
	if mission._elapsed < 1.2:
		# brief spawn grace so a mission never opens with an unavoidable hit
		return false
	var to_p: Vector2 = global_position.direction_to(p.global_position)
	var dist: float = global_position.distance_to(p.global_position)
	if dist > view_range:
		return false
	if to_p.angle_to(facing) > deg_to_rad(view_angle * 0.5):
		return false
	_los_timer -= 0.08
	if _los_timer > 0.0:
		return true
	_los_timer = 0.08
	return not mission.is_wall_between(global_position, p.global_position)

func _update_cone() -> void:
	if _cone == null:
		return
	if not alive:
		_cone.visible = false
		return
	_cone.visible = true
	var half: float = deg_to_rad(view_angle * 0.5)
	var reach: float = view_range
	if state == State.CHASE or state == State.ATTACK:
		reach = min(view_range, 520.0)
		_update_cone_color()
	_cone_tick += 1
	var clip := (_cone_tick % 3) == 0
	var space := get_world_2d().direct_space_state if clip else null
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var steps := 16
	for i in range(steps + 1):
		var a: float = -half + (2.0 * half) * (float(i) / float(steps))
		var p: Vector2 = Vector2(0, -reach).rotated(a)
		if space:
			var q := PhysicsRayQueryParameters2D.create(
				global_position, global_position + p, (1 << 0) | (1 << 3))
			q.exclude = [get_rid()]
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				p = hit["position"] - global_position
		pts.append(p)
	_cone.polygon = pts
	_cone.rotation = facing.angle() + PI * 0.5

func _update_cone_color() -> void:
	if _cone == null:
		return
	match state:
		State.CHASE, State.ATTACK:
			_cone.color = Color(1.0, 0.2, 0.28, 0.12)
		State.ALERT:
			_cone.color = Color(1.0, 0.55, 0.2, 0.10)
		_:
			_cone.color = Color(0.85, 0.9, 0.8, 0.05)

func die(from_dir: Vector2 = Vector2.ZERO) -> void:
	if not alive:
		return
	alive = false
	state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if _cone:
		_cone.visible = false
	if mission:
		mission.on_enemy_killed(self, from_dir)
	queue_redraw()

func _draw() -> void:
	# Body is drawn by the TopDownFigure child. Nothing to add here yet; kept
	# so the node still has a draw pass for future status pips.
	pass
