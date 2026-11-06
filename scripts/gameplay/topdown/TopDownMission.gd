# TopDownMission.gd
# Builds and runs a Hotline Miami-style top-down mission from a level JSON.
# Reuses Dead Hours narrative data: the mission is entered from a story
# checkpoint of type "mission" and reports its outcome back as story flags.
#
# Level JSON (assets/data/levels/<mission_id>.json):
#   title, subtitle, loading_art, briefing, tip
#   world: { width, height }
#   player: { spawn: [x, y], weapon: "bat" }
#   rooms: [ { id, rect: [x,y,w,h], floor: "checker", neon: "#ff2e88", neon_side: "top" } ]
#   doors: [ { rect: [x,y,w,h], locked: false } ]      # openings carved into walls
#   enemies: [ { pos: [x,y], weapon: "fists", patrol: [[x,y], ...] } ]
#   pickups: [ { weapon: "pistol", ammo: 7, pos: [x,y] } ]
#   props: [ { type: "crate"|"barrel"|"door"|"locker", rect|pos, locked } ]
#   exit: { rect: [x,y,w,h], label: "Reach the street" }
#   on_enemy_killed / on_alarm / on_complete: flag operation arrays
extends Node2D
class_name TopDownMission

const WALL_T := 20.0
const FLOOR_CELL := 64.0

const COLOR_VOID := Color("#07080a")
const COLOR_WALL := Color("#242a30")
const COLOR_WALL_EDGE := Color("#3a444d")
const COLOR_BLOOD := Color("#4c0a10")

@export var default_mission_id: String = "ch1_fireescape"
@export var debug_skip_briefing: bool = false

var mission_id: String = ""
var level: Dictionary = {}
var world_rect: Rect2 = Rect2(0, 0, 1600, 2200)

var world: Node2D
var floors: Node2D
var wall_art: Node2D
var decals: Node2D
var actors: Node2D
var fx: Node2D
var fx_system: TopDownFX
var explosives: Array = []

var player: TopDownPlayer
var enemies: Array = []
var pickups: Array = []
var doors: Array = []
var lockers: Array = []
var exit_zone: Area2D = null

var camera: Camera2D
var hud: CanvasLayer
var briefing_layer: CanvasLayer
var overlay_layer: CanvasLayer
var joystick_view: Control

var game_started: bool = false
var mission_complete: bool = false
var player_dead: bool = false
var kills: int = 0
var shots_fired: int = 0
var alarm_raised: bool = false
var start_msec: int = 0
var _elapsed: float = 0.0

# touch input state (written by _unhandled_input, read by the player)
var touch_mode: bool = false
var touch_move: Vector2 = Vector2.ZERO
var touch_aim: Vector2 = Vector2.ZERO
var touch_fire: bool = false
var _move_touch: int = -1
var _aim_touch: int = -1
var _attack_touch: int = -1
var _dash_touch: int = -1
var _use_touch: int = -1
var touch_dash: bool = false
var touch_interact: bool = false

# touch layout (recomputed on resize)
var _move_base: Vector2 = Vector2.ZERO
var _aim_base: Vector2 = Vector2.ZERO
var _btn_attack: Vector2 = Vector2.ZERO
var _btn_dash: Vector2 = Vector2.ZERO
var _btn_use: Vector2 = Vector2.ZERO
# QA hook: lets the headless harness lay the controls out for a phone screen.
var layout_size: Vector2 = Vector2.ZERO
var _move_origin: Vector2 = Vector2.ZERO
var _aim_origin: Vector2 = Vector2.ZERO
const STICK_RADIUS := 78.0
const BTN_ATTACK_R := 54.0
const BTN_DASH_R := 40.0
const BTN_USE_R := 34.0

var _shake: float = 0.0
var _message_t: float = 0.0
var _near_interactable: Node = null

# HUD refs
var _objective_label: Label
var _weapon_label: Label
var _alert_label: Label
var _message_label: Label
var _hint_label: Label
var _stats_label: Label

func _ready() -> void:
	randomize()
	if OS.get_cmdline_user_args().has("--auto") or OS.get_environment("TD_AUTOSTART") == "1":
		debug_skip_briefing = true
	_apply_story_context()
	_load_level()
	_build_world()
	_build_camera()
	_build_ui()
	if debug_skip_briefing:
		start_mission()

func _apply_story_context() -> void:
	mission_id = default_mission_id
	if not OS.get_environment("TD_LEVEL").is_empty():
		mission_id = OS.get_environment("TD_LEVEL")
	if StoryManager and not StoryManager.current_checkpoint.is_empty():
		var cp: Dictionary = StoryManager.current_checkpoint
		if cp.get("type", "") == "mission" and cp.has("mission_id"):
			mission_id = str(cp.get("mission_id", default_mission_id))

func _load_level() -> void:
	var path := "res://assets/data/levels/%s.json" % mission_id
	if not FileAccess.file_exists(path):
		push_error("TopDownMission: level not found " + path)
		level = {"title": "MISSING LEVEL", "rooms": [], "player": {"spawn": [400, 400]}}
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		level = parsed
	else:
		push_error("TopDownMission: invalid level JSON " + path)
		level = {"title": "INVALID LEVEL", "rooms": []}

func _r(a: Variant) -> Rect2:
	if a is Array and a.size() >= 4:
		return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return Rect2()

func _v(a: Variant) -> Vector2:
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO

func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	var backdrop := BackdropView.new()
	backdrop.rect = world_rect
	world.add_child(backdrop)

	floors = Node2D.new()
	floors.name = "Floors"
	world.add_child(floors)

	wall_art = Node2D.new()
	wall_art.name = "Walls"
	world.add_child(wall_art)

	decals = Node2D.new()
	decals.name = "Decals"
	world.add_child(decals)

	actors = Node2D.new()
	actors.name = "Actors"
	world.add_child(actors)

	fx = Node2D.new()
	fx.name = "FX"
	world.add_child(fx)

	fx_system = TopDownFX.new()
	fx_system.name = "Effects"
	fx_system.mission = self
	fx.add_child(fx_system)

	var w: float = float(level.get("world", {}).get("width", 1600))
	var h: float = float(level.get("world", {}).get("height", 2200))
	world_rect = Rect2(0, 0, w, h)

	RenderingServer.set_default_clear_color(COLOR_VOID)
	_build_floors()
	_build_walls()
	_build_props()
	_build_pickups()
	_build_ambient_effects()
	_build_exit()
	_spawn_player()
	_spawn_enemies()
	print("TopDownMission[%s]: %d rooms, %d enemies, %d wall rects, %d pickups" % [mission_id, level.get("rooms", []).size(), enemies.size(), _wall_rects().size(), pickups.size()])
	world.process_mode = Node.PROCESS_MODE_DISABLED

func _build_floors() -> void:
	var rooms: Array = level.get("rooms", [])
	for room in rooms:
		var view := FloorView.new()
		view.mission = self
		view.rect = _r(room.get("rect", []))
		view.floor_key = str(room.get("floor", "checker"))
		view.neon = Color(str(room.get("neon", "#ff2e88")))
		view.neon_side = str(room.get("neon_side", "top"))
		view.seed = abs(int(view.rect.position.x * 7.0 + view.rect.position.y * 13.0))
		floors.add_child(view)

		# Access floor to the world edge is drawn black by the clear color.
		if room.has("label"):
			var tag := Label.new()
			tag.text = str(room.get("label"))
			tag.position = view.rect.position + Vector2(16, 10)
			tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.18))
			tag.add_theme_font_size_override("font_size", 16)
			floors.add_child(tag)

func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.name = "WallBodies"
	body.collision_layer = 1 << 0
	body.collision_mask = 0
	world.add_child(body)

	var rects: Array = _wall_rects()
	for wall in rects:
		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = wall.size
		shape.shape = rect_shape
		shape.position = wall.position + wall.size * 0.5
		body.add_child(shape)

	var art := WallView.new()
	art.rects = rects
	wall_art.add_child(art)

func _wall_rects() -> Array:
	# Base perimeter per room, then subtract door openings.
	var segs: Array = []
	for room in level.get("rooms", []):
		var r := _r(room.get("rect", []))
		if r.size == Vector2.ZERO:
			continue
		segs.append({"o": "h", "c": r.position.y, "a": r.position.x - WALL_T * 0.5, "b": r.end.x + WALL_T * 0.5})
		segs.append({"o": "h", "c": r.end.y, "a": r.position.x - WALL_T * 0.5, "b": r.end.x + WALL_T * 0.5})
		segs.append({"o": "v", "c": r.position.x, "a": r.position.y - WALL_T * 0.5, "b": r.end.y + WALL_T * 0.5})
		segs.append({"o": "v", "c": r.end.x, "a": r.position.y - WALL_T * 0.5, "b": r.end.y + WALL_T * 0.5})

	var openings: Array = []
	for d in level.get("doors", []):
		openings.append(_r(d.get("rect", [])))

	var out: Array = []
	for seg in segs:
		var pieces: Array = [Vector2(seg["a"], seg["b"])]
		for op in openings:
			var next_pieces: Array = []
			for piece in pieces:
				next_pieces.append_array(_subtract(piece, seg, op))
			pieces = next_pieces
		for piece in pieces:
			var a: float = piece.x
			var b: float = piece.y
			if b - a < 4.0:
				continue
			if seg["o"] == "h":
				out.append(Rect2(a, seg["c"] - WALL_T * 0.5, b - a, WALL_T))
			else:
				out.append(Rect2(seg["c"] - WALL_T * 0.5, a, WALL_T, b - a))
	return out

func _subtract(piece: Vector2, seg: Dictionary, opening: Rect2) -> Array:
	var lo: float = piece.x
	var hi: float = piece.y
	var o_lo: float
	var o_hi: float
	if seg["o"] == "h":
		if opening.position.y > seg["c"] + WALL_T * 0.6 or opening.end.y < seg["c"] - WALL_T * 0.6:
			return [piece]
		o_lo = opening.position.x
		o_hi = opening.end.x
	else:
		if opening.position.x > seg["c"] + WALL_T * 0.6 or opening.end.x < seg["c"] - WALL_T * 0.6:
			return [piece]
		o_lo = opening.position.y
		o_hi = opening.end.y
	if o_hi <= lo or o_lo >= hi:
		return [piece]
	var result: Array = []
	if o_lo > lo:
		result.append(Vector2(lo, min(o_lo, hi)))
	if o_hi < hi:
		result.append(Vector2(max(o_hi, lo), hi))
	return result

func _build_props() -> void:
	for prop in level.get("props", []):
		var ptype := str(prop.get("type", "crate"))
		match ptype:
			"crate":
				var crate := CrateNode.new()
				crate.rect = _r(prop.get("rect", []))
				crate.color = Color(str(prop.get("color", "#2f3338")))
				world.add_child(crate)
			"barrel":
				var barrel := BarrelNode.new()
				barrel.pos = _v(prop.get("pos", [0, 0]))
				barrel.radius = float(prop.get("radius", 22.0))
				world.add_child(barrel)
			"door":
				var door := DoorNode.new()
				door.mission = self
				door.rect = _r(prop.get("rect", []))
				door.locked = bool(prop.get("locked", false))
				door.horizontal = door.rect.size.x >= door.rect.size.y
				world.add_child(door)
				doors.append(door)
			"pump", "tank":
				var erect := _r(prop.get("rect", []))
				if erect.size == Vector2.ZERO:
					continue
				var exp := ExplosiveNode.new()
				exp.mission = self
				exp.rect = erect
				exp.kind = "pump" if ptype == "pump" else "tank"
				exp.radius = float(prop.get("radius_fx", 150.0))
				world.add_child(exp)
				explosives.append(exp)
			"sofa", "bed", "table", "chair", "bench", "counter", "fridge", "tv", "shelf", "cabinet", "desk", "dumpster", "car", "plant", "rug", "trash", "streetlight":
				var prect := _r(prop.get("rect", []))
				if prect.size == Vector2.ZERO and prop.has("pos"):
					var rad := float(prop.get("radius", 18.0))
					prect = Rect2(_v(prop.get("pos", [0, 0])) - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
				if prect.size == Vector2.ZERO:
					continue
				var furn := TopDownProp.new()
				furn.position = prect.position + prect.size * 0.5
				furn.setup(ptype, prect.size, int(prop.get("seed", int(prect.position.x + prect.position.y))))
				furn.z_index = 0 if ptype == "rug" else 1
				world.add_child(furn)
				var solid_default: bool = ptype not in ["rug", "streetlight", "trash"]
				if bool(prop.get("solid", solid_default)):
					_add_prop_collider(prect)
			"locker":
				var locker := LockerNode.new()
				locker.mission = self
				locker.rect = _r(prop.get("rect", []))
				world.add_child(locker)
				lockers.append(locker)
			_:
				pass

func _add_prop_collider(rect: Rect2) -> void:
	# Furniture blocks movement, sight and bullets: one static box per footprint.
	var body := StaticBody2D.new()
	body.collision_layer = 1 << 0
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	world.add_child(body)

func _build_ambient_effects() -> void:
	var eff: Dictionary = level.get("effects", {})
	if eff.is_empty() or fx_system == null:
		return
	for f in eff.get("fires", []):
		fx_system.ambient_fire(_v(f.get("pos", [0, 0])), float(f.get("size", 1.0)))
	for smear in eff.get("blood_smears", []):
		fx_system.blood_smear(_v(smear.get("from", [0, 0])), _v(smear.get("to", [0, 0])),
			float(smear.get("width", 22.0)))

func _build_pickups() -> void:
	for p in level.get("pickups", []):
		var node := PickupNode.new()
		node.mission = self
		node.weapon_id = str(p.get("weapon", "pistol"))
		node.amount = int(p.get("ammo", -1))
		node.position = _v(p.get("pos", [0, 0]))
		world.add_child(node)
		pickups.append(node)

func _build_exit() -> void:
	var ex: Dictionary = level.get("exit", {})
	if ex.is_empty():
		return
	var area := Area2D.new()
	area.name = "Exit"
	area.collision_layer = 1 << 4
	area.collision_mask = 1 << 1
	area.monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = _r(ex.get("rect", [0, 0, 100, 100])).size
	shape.shape = rect
	area.position = _r(ex.get("rect", [0, 0, 0, 0])).position + rect.size * 0.5
	area.add_child(shape)
	var visual := ExitView.new()
	visual.size = rect.size
	visual.label = str(ex.get("label", "EXIT"))
	visual.position = -rect.size * 0.5
	area.add_child(visual)
	world.add_child(area)
	exit_zone = area
	area.body_entered.connect(_on_exit_entered)

func _spawn_player() -> void:
	player = TopDownPlayer.new()
	player.mission = self
	player.position = _v(level.get("player", {}).get("spawn", [200, 200]))
	player.weapon_id = str(level.get("player", {}).get("weapon", "bat"))
	player.died.connect(_on_player_signal_died)
	actors.add_child(player)
	player.set_weapon(player.weapon_id, -1)

func _spawn_enemies() -> void:
	for e in level.get("enemies", []):
		var enemy := TopDownEnemy.new()
		enemy.mission = self
		enemy.position = _v(e.get("pos", [0, 0]))
		enemy.weapon_id = str(e.get("weapon", "fists"))
		enemy.zombie_type = str(e.get("type", "shambler"))
		enemy.view_range = float(e.get("view_range", 340.0))
		enemy.view_angle = float(e.get("view_angle", 96.0))
		var pts: Array = []
		for p in e.get("patrol", []):
			pts.append(_v(p))
		enemy.patrol_points = pts
		if e.has("facing"):
			enemy.facing = _v(e.get("facing"))
		actors.add_child(enemy)
		enemies.append(enemy)

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera"
	var zoom_value := 1.55
	var env_zoom := OS.get_environment("TD_ZOOM")
	if not env_zoom.is_empty():
		zoom_value = maxf(0.35, float(env_zoom))
	camera.zoom = Vector2(zoom_value, zoom_value)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = int(world_rect.position.x)
	camera.limit_top = int(world_rect.position.y)
	camera.limit_right = int(world_rect.end.x)
	camera.limit_bottom = int(world_rect.end.y)
	add_child(camera)
	camera.global_position = player.global_position if player else Vector2(400, 400)

func _process(delta: float) -> void:
	if not game_started:
		_update_joystick_view()
		return
	_elapsed += delta
	if _message_t > 0.0:
		_message_t -= delta
		if _message_t <= 0.0 and _message_label:
			_message_label.text = ""
	if camera and player:
		# look-ahead toward the aim direction, Hotline Miami style
		var look := player.aim_dir * 70.0
		camera.global_position = player.global_position + look
		if _shake > 0.0:
			_shake = maxf(0.0, _shake - delta * 26.0)
			camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		else:
			camera.offset = Vector2.ZERO
	_update_near_interactable()
	_update_joystick_view()
	_update_hud()

func _update_near_interactable() -> void:
	if player == null or not player.alive:
		return
	var best: Node = null
	var best_d := 82.0
	for d in doors:
		if is_instance_valid(d) and not d.open:
			var dist: float = player.global_position.distance_to(d.global_position)
			if dist < best_d:
				best = d
				best_d = dist
	for l in lockers:
		if is_instance_valid(l):
			var dist: float = player.global_position.distance_to(l.global_position)
			if dist < best_d:
				best = l
				best_d = dist
	_near_interactable = best
	if _hint_label:
		if best is LockerNode and player.in_cover:
			_hint_label.text = "E / TAP: LEAVE COVER"
		elif best != null:
			_hint_label.text = "E / TAP: INTERACT"
		elif player.in_cover:
			_hint_label.text = ""
		else:
			_hint_label.text = ""

func try_interact(pos: Vector2) -> void:
	if _near_interactable == null:
		return
	if _near_interactable is DoorNode:
		_near_interactable.open_door()
	elif _near_interactable is LockerNode:
		_near_interactable.toggle_hide(player)

func spawn_tracer(from: Vector2, to: Vector2, color: Color) -> void:
	if fx_system:
		fx_system.tracer(from, to, color, 1.8)
		return
	var line := Line2D.new()
	line.width = 1.6
	line.default_color = color
	line.points = PackedVector2Array([from, to])
	line.z_index = 20
	fx.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.09)
	tween.tween_callback(line.queue_free)

func spawn_blood(at: Vector2, from_dir: Vector2) -> void:
	if fx_system:
		fx_system.corpse_fx(at, from_dir)
	var blood := BloodView.new()
	blood.position = at
	blood.dir = from_dir
	blood.seed = randi()
	decals.add_child(blood)

func shake_camera(amount: float) -> void:
	_shake = maxf(_shake, amount)

func emit_noise(pos: Vector2, radius: float, source: Node = null) -> void:
	if radius <= 0.0:
		return
	if radius >= 600.0 and not alarm_raised:
		alarm_raised = true
		FlagsManager.process_flag_operations(level.get("on_alarm", []))
		if _alert_label:
			_alert_label.text = "ALARM"
			_alert_label.visible = true
	for e in enemies:
		if not is_instance_valid(e) or not e.alive or e == source:
			continue
		if e.global_position.distance_to(pos) <= radius:
			e.alert_to(pos)

func raise_alarm(pos: Vector2, radius: float, source: Node = null) -> void:
	if not alarm_raised:
		alarm_raised = true
		FlagsManager.process_flag_operations(level.get("on_alarm", []))
		if _alert_label:
			_alert_label.text = "ALERTED"
			_alert_label.visible = true
	for e in enemies:
		if not is_instance_valid(e) or not e.alive or e == source:
			continue
		if e.global_position.distance_to(pos) <= radius:
			e.alert_to(pos)

func explode(pos: Vector2, radius: float = 160.0, source: Node = null) -> void:
	if fx_system:
		fx_system.explosion(pos, radius)
	shake_camera(16.0)
	raise_alarm(pos, radius * 6.0, null)
	for e in enemies.duplicate():
		if not is_instance_valid(e) or not e.alive:
			continue
		if e.global_position.distance_to(pos) > radius:
			continue
		if is_wall_between(pos, e.global_position):
			continue
		e.die((e.global_position - pos).normalized())
	if player and player.alive and player.global_position.distance_to(pos) <= radius * 0.8:
		player.kill()
	for other in explosives.duplicate():
		if not is_instance_valid(other) or other == source or other.blown:
			continue
		if other.global_position.distance_to(pos) <= radius * 1.7:
			other.chain_in(randf_range(0.08, 0.24))

func hit_stop(duration: float = 0.045) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.3
	get_tree().create_timer(duration, true, false, true).timeout.connect(_end_hit_stop)

func _end_hit_stop() -> void:
	Engine.time_scale = 1.0

func is_wall_between(a: Vector2, b: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(a, b, (1 << 0) | (1 << 3))
	return not space.intersect_ray(q).is_empty()

func on_enemy_killed(enemy: Node, from_dir: Vector2) -> void:
	kills += 1
	spawn_blood(enemy.global_position, from_dir)
	hit_stop()
	shake_camera(3.5)
	FlagsManager.process_flag_operations(level.get("on_enemy_killed", []))
	_check_clear_objective()

func on_player_died() -> void:
	player_dead = true
	if fx_system and player:
		fx_system.corpse_fx(player.global_position, Vector2.DOWN)
		fx_system.damage_flash()
	shake_camera(12.0)
	if overlay_layer:
		_show_result("YOU DIED", "The building keeps its dead.", true)

func _on_player_signal_died() -> void:
	pass

func _on_exit_entered(body: Node) -> void:
	if body == player and not mission_complete and not player_dead:
		complete_mission()

func _check_clear_objective() -> void:
	var remaining := 0
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			remaining += 1
	if remaining == 0 and level.get("complete_on_clear", false):
		complete_mission()

func complete_mission() -> void:
	if mission_complete:
		return
	mission_complete = true
	if player:
		player.can_act = false
	var t := int((Time.get_ticks_msec() - start_msec) / 1000.0)
	_show_result("FLOOR CLEARED", "%d kills  ·  %s  ·  %s" % [kills, _fmt_time(t), "ALARM RAISED" if alarm_raised else "SILENT"], false)

func _fmt_time(total: int) -> String:
	return "%02d:%02d" % [total / 60, total % 60]

func _show_result(title: String, subtitle: String, dead: bool) -> void:
	print("TopDownMission: result '%s' after %.1fs (%s)" % [title, _elapsed, subtitle])
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 54)
	t.add_theme_color_override("font_color", Color("#c4453f") if dead else Color("#e8e2d6"))
	box.add_child(t)

	var s := Label.new()
	s.text = subtitle
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 20)
	s.add_theme_color_override("font_color", Color(0.8, 0.8, 0.78, 0.9))
	box.add_child(s)

	var b := Button.new()
	b.text = "RETRY" if dead else "CONTINUE"
	b.custom_minimum_size = Vector2(220, 54)
	b.add_theme_font_size_override("font_size", 20)
	box.add_child(b)
	if dead:
		b.pressed.connect(func(): get_tree().reload_current_scene())
	else:
		b.pressed.connect(_finish_mission)

	overlay_layer.add_child(root)

func _finish_mission() -> void:
	var t := int((Time.get_ticks_msec() - start_msec) / 1000.0)
	FlagsManager.set_flag("%s_complete" % mission_id, true)
	FlagsManager.set_flag("%s_kills" % mission_id, kills)
	FlagsManager.set_flag("%s_alerted" % mission_id, alarm_raised)
	FlagsManager.set_flag("%s_time" % mission_id, t)
	FlagsManager.process_flag_operations(level.get("on_complete", []))
	if StoryManager and not StoryManager.current_checkpoint.is_empty():
		StoryManager.advance_to_next_checkpoint()
	else:
		flash_message("DEMO COMPLETE — reloading")
		await get_tree().create_timer(1.6).timeout
		get_tree().reload_current_scene()

func flash_message(text: String) -> void:
	if _message_label:
		_message_label.text = text
		_message_t = 2.0

# ---------------------------------------------------------------- UI -------

func _build_ui() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)

	_objective_label = Label.new()
	_objective_label.position = Vector2(28, 22)
	_objective_label.add_theme_font_size_override("font_size", 20)
	_objective_label.add_theme_color_override("font_color", Color("#e8e2d6"))
	_objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_objective_label.add_theme_constant_override("outline_size", 6)
	_objective_label.text = str(level.get("objective", ""))
	root.add_child(_objective_label)

	_alert_label = Label.new()
	_alert_label.position = Vector2(0, 24)
	_alert_label.size = Vector2(1280, 30)
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.add_theme_font_size_override("font_size", 22)
	_alert_label.add_theme_color_override("font_color", Color("#ff4a5e"))
	_alert_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_alert_label.add_theme_constant_override("outline_size", 6)
	_alert_label.visible = false
	root.add_child(_alert_label)

	_weapon_label = Label.new()
	_weapon_label.position = Vector2(28, 648)
	_weapon_label.add_theme_font_size_override("font_size", 24)
	_weapon_label.add_theme_color_override("font_color", Color("#f0c98a"))
	_weapon_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_weapon_label.add_theme_constant_override("outline_size", 6)
	root.add_child(_weapon_label)

	_message_label = Label.new()
	_message_label.position = Vector2(0, 610)
	_message_label.size = Vector2(1280, 28)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 20)
	_message_label.add_theme_color_override("font_color", Color("#ffd9a0"))
	root.add_child(_message_label)

	_hint_label = Label.new()
	_hint_label.position = Vector2(0, 676)
	_hint_label.size = Vector2(1280, 24)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	root.add_child(_hint_label)

	var restart := Button.new()
	restart.text = "⟲"
	restart.position = Vector2(1216, 18)
	restart.size = Vector2(46, 46)
	restart.add_theme_font_size_override("font_size", 22)
	restart.mouse_filter = Control.MOUSE_FILTER_STOP
	restart.pressed.connect(func(): get_tree().reload_current_scene())
	root.add_child(restart)

	joystick_view = JoystickView.new()
	joystick_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	joystick_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joystick_view.mission = self
	root.add_child(joystick_view)
	_layout_touch()
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	if OS.get_environment("TD_TOUCH_PREVIEW") == "1":
		touch_mode = true

	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	mat.set_shader_parameter("intensity", 0.32)
	vignette.material = mat
	root.add_child(vignette)

	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 20
	add_child(overlay_layer)

	_build_briefing()
	update_weapon_hud()
	_update_hud()

func _build_briefing() -> void:
	briefing_layer = CanvasLayer.new()
	briefing_layer.layer = 30
	add_child(briefing_layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	briefing_layer.add_child(root)

	var bg := ColorRect.new()
	bg.color = Color("#07080a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var art_key := str(level.get("loading_art", ""))
	if not art_key.is_empty():
		var tex: Texture2D = null
		if BackgroundManager and BackgroundManager.has_method("get_background"):
			tex = BackgroundManager.get_background(art_key)
		if tex == null:
			var p := "res://assets/images/backgrounds/%s.png" % art_key
			if ResourceLoader.exists(p):
				tex = load(p)
		if tex:
			var art := TextureRect.new()
			art.texture = tex
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			art.modulate = Color(0.85, 0.88, 0.95)
			root.add_child(art)

	var wash := ColorRect.new()
	wash.color = Color(0.02, 0.03, 0.04, 0.62)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(wash)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)

	var kicker := Label.new()
	kicker.text = str(level.get("kicker", "DEAD HOURS"))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 18)
	kicker.add_theme_color_override("font_color", Color(0.78, 0.42, 0.38, 0.95))
	box.add_child(kicker)

	var title := Label.new()
	title.text = str(level.get("title", mission_id)).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("#e8e2d6"))
	box.add_child(title)

	var sub := Label.new()
	sub.text = str(level.get("subtitle", ""))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78, 0.85))
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 26)
	box.add_child(spacer)

	var brief := Label.new()
	brief.text = str(level.get("briefing", ""))
	brief.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.custom_minimum_size = Vector2(760, 0)
	brief.add_theme_font_size_override("font_size", 21)
	brief.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85, 0.95))
	box.add_child(brief)

	var tip := Label.new()
	tip.text = str(level.get("tip", ""))
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.add_theme_font_size_override("font_size", 16)
	tip.add_theme_color_override("font_color", Color(0.7, 0.72, 0.7, 0.8))
	box.add_child(tip)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer2)

	var go := Button.new()
	go.text = "ENTER"
	go.custom_minimum_size = Vector2(240, 56)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.add_theme_font_size_override("font_size", 22)
	go.pressed.connect(start_mission)
	box.add_child(go)

	var ctrls := Label.new()
	ctrls.text = "TOUCH   left stick move   ·   right stick aim   ·   ATTACK   ·   DASH   ·   USE"
	ctrls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrls.add_theme_font_size_override("font_size", 14)
	ctrls.add_theme_color_override("font_color", Color(0.78, 0.9, 0.85, 0.75))
	box.add_child(ctrls)

	var keys := Label.new()
	keys.text = "KEYS   WASD move   ·   mouse aim   ·   LMB attack   ·   SPACE dash   ·   E use"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keys.add_theme_font_size_override("font_size", 13)
	keys.add_theme_color_override("font_color", Color(0.6, 0.62, 0.6, 0.65))
	box.add_child(keys)

	var tap := Label.new()
	tap.text = "tap anywhere to begin"
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap.add_theme_font_size_override("font_size", 14)
	tap.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	box.add_child(tap)

func start_mission() -> void:
	if game_started:
		return
	print("TopDownMission: start (briefing=%s)" % str(briefing_layer != null))
	game_started = true
	start_msec = Time.get_ticks_msec()
	world.process_mode = Node.PROCESS_MODE_INHERIT
	GameManager.change_state(GameManager.GameManagerState.PLAYING)
	if briefing_layer:
		briefing_layer.queue_free()
		briefing_layer = null
	update_weapon_hud()

func update_weapon_hud() -> void:
	if _weapon_label and player:
		_weapon_label.text = player.weapon_label()

func _update_hud() -> void:
	if _stats_label:
		var remaining := 0
		for e in enemies:
			if is_instance_valid(e) and e.alive:
				remaining += 1
		_stats_label.text = "%d HOSTILES" % remaining

func _update_joystick_view() -> void:
	if joystick_view == null:
		return
	joystick_view.queue_redraw()

func _view_size() -> Vector2:
	return layout_size if layout_size != Vector2.ZERO else get_viewport_rect().size

func _layout_touch() -> void:
	var vs: Vector2 = _view_size()
	var m := 30.0
	_move_base = Vector2(m + STICK_RADIUS + 6.0, vs.y - m - STICK_RADIUS)
	_aim_base = Vector2(vs.x - m - STICK_RADIUS, vs.y - m - STICK_RADIUS)
	_btn_attack = Vector2(_aim_base.x + 22.0, _aim_base.y - STICK_RADIUS - BTN_ATTACK_R - 24.0)
	_btn_dash = Vector2(_btn_attack.x - BTN_ATTACK_R - BTN_DASH_R - 16.0, _btn_attack.y + 18.0)
	_btn_use = Vector2(_btn_attack.x - 4.0, _btn_attack.y - BTN_ATTACK_R - BTN_USE_R - 14.0)

func _on_viewport_resized() -> void:
	_layout_touch()
	if joystick_view:
		joystick_view.queue_redraw()

func consume_dash() -> bool:
	var pressed := touch_dash
	touch_dash = false
	return pressed

func consume_interact() -> bool:
	var pressed := touch_interact
	touch_interact = false
	return pressed

func use_button_available() -> bool:
	return _near_interactable != null

func _hit(pos: Vector2, center: Vector2, radius: float) -> bool:
	return pos.distance_to(center) <= radius + 12.0

# ------------------------------------------------------------- touch -------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_mode = true
		if event.pressed:
			if not game_started:
				start_mission()
				return
			# action buttons first: they must never steal a stick finger
			if _hit(event.position, _btn_attack, BTN_ATTACK_R):
				_attack_touch = event.index
				touch_fire = true
				_vibrate(12)
				return
			if _hit(event.position, _btn_dash, BTN_DASH_R):
				_dash_touch = event.index
				touch_dash = true
				_vibrate(18)
				return
			if _hit(event.position, _btn_use, BTN_USE_R):
				_use_touch = event.index
				touch_interact = true
				_vibrate(12)
				return
			# sticks: left half moves, right half aims
			if event.position.x < _view_size().x * 0.5 and _move_touch == -1:
				_move_touch = event.index
				_move_origin = event.position
			elif _aim_touch == -1:
				_aim_touch = event.index
				_aim_origin = event.position
		else:
			if event.index == _attack_touch:
				_attack_touch = -1
				touch_fire = false
			if event.index == _dash_touch:
				_dash_touch = -1
			if event.index == _use_touch:
				_use_touch = -1
			if event.index == _move_touch:
				_move_touch = -1
				touch_move = Vector2.ZERO
			if event.index == _aim_touch:
				_aim_touch = -1
				touch_aim = Vector2.ZERO
	elif event is InputEventScreenDrag:
		touch_mode = true
		if event.index == _move_touch:
			touch_move = ((event.position - _move_origin) / STICK_RADIUS).limit_length(1.0)
		elif event.index == _aim_touch:
			touch_aim = ((event.position - _aim_origin) / STICK_RADIUS).limit_length(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		if not game_started and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
			start_mission()
		elif event.keycode == KEY_R and (player_dead or mission_complete):
			get_tree().reload_current_scene()
	elif event is InputEventMouseButton and event.pressed and not game_started:
		start_mission()

func _vibrate(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

# ------------------------------------------------------- nested views ------

class FloorView extends Node2D:
	const FLOOR_TEXTURES := {
		"checker": "floor_tile",
		"checker_red": "floor_carpet",
		"concrete": "floor_concrete",
		"dirt": "floor_concrete",
		"wood": "floor_wood",
		"carpet": "floor_carpet",
		"tile": "floor_tile",
	}
	const FLOOR_TINTS := {
		"checker": Color(0.85, 0.9, 0.95),
		"checker_red": Color(1.15, 0.72, 0.8),
		"concrete": Color(0.9, 0.95, 1.0),
		"dirt": Color(1.0, 0.86, 0.72),
	}
	var mission: Node
	var rect: Rect2 = Rect2()
	var floor_key: String = "checker"
	var neon: Color = Color("#ff2e88")
	var neon_side: String = "top"
	var seed: int = 1
	var texture: Texture2D = null

	func _ready() -> void:
		var tex_name: String = FLOOR_TEXTURES.get(floor_key, "")
		if tex_name.is_empty():
			return
		var path := "res://assets/images/textures/%s.png" % tex_name
		if ResourceLoader.exists(path):
			texture = load(path)
			texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

	func _draw() -> void:
		var base := Color("#1a2127")
		var alt := Color("#232c33")
		var grout := Color("#0e1317")
		if floor_key == "concrete":
			base = Color("#242a2e")
			alt = Color("#2b3338")
		elif floor_key == "dirt":
			base = Color("#201d19")
			alt = Color("#27231e")
		elif floor_key == "checker_red":
			base = Color("#241619")
			alt = Color("#301c22")
		var textured := texture != null
		if textured:
			# CC0 photographic surface (see assets/data/asset_sources.json), tinted
			# into the neon-noir grade. The checker read is kept as a light overlay.
			texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			draw_texture_rect(texture, rect, true, FLOOR_TINTS.get(floor_key, Color(0.9, 0.94, 1.0)))
			base = Color(base.r, base.g, base.b, 0.35)
			alt = Color(alt.r, alt.g, alt.b, 0.30)
		draw_rect(rect, base)
		if floor_key.begins_with("checker"):
			var cell := 64.0
			var y := rect.position.y
			var row := 0
			while y < rect.end.y:
				var x := rect.position.x
				var col := 0
				while x < rect.end.x:
					if (row + col) % 2 == 1:
						var w: float = min(cell, rect.end.x - x)
						var h: float = min(cell, rect.end.y - y)
						draw_rect(Rect2(x, y, w, h), alt)
					x += cell
					col += 1
				y += cell
				row += 1
			# grout lines
			var gx := rect.position.x
			while gx <= rect.end.x:
				draw_line(Vector2(gx, rect.position.y), Vector2(gx, rect.end.y), grout, 1.0)
				gx += cell
			var gy := rect.position.y
			while gy <= rect.end.y:
				draw_line(Vector2(rect.position.x, gy), Vector2(rect.end.x, gy), grout, 1.0)
				gy += cell
		# deterministic grime
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		for i in range(26):
			var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
			var r := rng.randf_range(6.0, 34.0)
			draw_circle(p, r, Color(0, 0, 0, rng.randf_range(0.05, 0.14)))
		draw_rect(rect, Color(0, 0, 0, 0.0), false, 2.0)
		_draw_neon()

	func _draw_neon() -> void:
		var thickness := 16.0
		var strip := Rect2()
		match neon_side:
			"top":
				strip = Rect2(rect.position.x + 8, rect.position.y + 4, rect.size.x - 16, thickness)
			"bottom":
				strip = Rect2(rect.position.x + 8, rect.end.y - thickness - 4, rect.size.x - 16, thickness)
			"left":
				strip = Rect2(rect.position.x + 4, rect.position.y + 8, thickness, rect.size.y - 16)
			_:
				strip = Rect2(rect.end.x - thickness - 4, rect.position.y + 8, thickness, rect.size.y - 16)
		draw_rect(rect, Color(neon.r, neon.g, neon.b, 0.035))
		draw_rect(strip.grow(30.0), Color(neon.r, neon.g, neon.b, 0.08))
		draw_rect(strip.grow(14.0), Color(neon.r, neon.g, neon.b, 0.16))
		draw_rect(strip, Color(neon.r, neon.g, neon.b, 0.95))
		draw_rect(strip.grow(-5.0), Color(1, 1, 1, 0.55))

class BackdropView extends Node2D:
	var rect: Rect2 = Rect2()
	func _draw() -> void:
		draw_rect(rect, Color("#0b0e11"))
		var step := 128.0
		var x := rect.position.x
		while x <= rect.end.x:
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(1, 1, 1, 0.018), 1.0)
			x += step
		var y := rect.position.y
		while y <= rect.end.y:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(1, 1, 1, 0.018), 1.0)
			y += step

class WallView extends Node2D:
	var rects: Array = []
	var texture: Texture2D = null
	func _ready() -> void:
		var path := "res://assets/images/textures/wall_brick.png"
		if ResourceLoader.exists(path):
			texture = load(path)
			texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	func _draw() -> void:
		for wall in rects:
			if texture:
				texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				draw_texture_rect(texture, wall, true, Color(0.55, 0.6, 0.66))
			draw_rect(wall, Color("#333d45") if texture == null else Color(0.05, 0.06, 0.07, 0.18))
			draw_rect(Rect2(wall.position, Vector2(wall.size.x, 3.0)), Color("#55636e"))
			draw_rect(Rect2(wall.position, Vector2(2.0, wall.size.y)), Color("#41505a"))

class BloodView extends Node2D:
	var dir: Vector2 = Vector2.RIGHT
	var seed: int = 0
	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var base := Color(0.24, 0.02, 0.04, 0.75)
		for i in range(9):
			var off := Vector2(rng.randf_range(-42, 42), rng.randf_range(-42, 42))
			if dir != Vector2.ZERO and i < 5:
				off += dir * rng.randf_range(10.0, 46.0)
			draw_circle(off, rng.randf_range(3.0, 15.0), base)
		draw_circle(Vector2.ZERO, 20.0, Color(0.18, 0.01, 0.03, 0.8))

class CrateNode extends StaticBody2D:
	var rect: Rect2 = Rect2()
	var color: Color = Color("#2f3338")
	func _ready() -> void:
		collision_layer = 1 << 3
		collision_mask = 0
		position = rect.position + rect.size * 0.5
		var shape := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = rect.size
		shape.shape = s
		add_child(shape)
		z_index = 1
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(-rect.size * 0.5, rect.size)
		draw_rect(r, color)
		draw_rect(r.grow(-4.0), color.lightened(0.08), false, 2.0)
		draw_line(r.position, r.end, Color(0, 0, 0, 0.25), 2.0)

class BarrelNode extends StaticBody2D:
	var pos: Vector2 = Vector2.ZERO
	var radius: float = 22.0
	func _ready() -> void:
		collision_layer = 1 << 3
		collision_mask = 0
		position = pos
		var shape := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = radius
		shape.shape = c
		add_child(shape)
		z_index = 1
		queue_redraw()
	func _draw() -> void:
		draw_circle(Vector2(0, 3), radius, Color(0, 0, 0, 0.35))
		draw_circle(Vector2.ZERO, radius, Color("#38403f"))
		draw_arc(Vector2.ZERO, radius - 2.0, 0, TAU, 20, Color("#59635f"), 2.0)

class DoorNode extends StaticBody2D:
	var mission: Node
	var rect: Rect2 = Rect2()
	var locked: bool = false
	var open: bool = false
	var horizontal: bool = true
	var _shape: CollisionShape2D

	func _ready() -> void:
		collision_layer = 1 << 3
		collision_mask = 0
		position = rect.position + rect.size * 0.5
		_shape = CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = rect.size
		_shape.shape = s
		add_child(_shape)
		z_index = 1
		queue_redraw()

	func open_door() -> void:
		if open:
			return
		if locked:
			if mission:
				mission.flash_message("LOCKED")
			return
		open = true
		_shape.disabled = true
		collision_layer = 0
		queue_redraw()
		if mission:
			mission.emit_noise(global_position, 150.0, null)

	func sprite_key() -> String:
		return "door_%s_%s" % ["h" if horizontal else "v", "open" if open else "closed"]

	func _draw() -> void:
		if TopDownObjectArt.draw_sprite(self, sprite_key(), rect.size):
			return
		TopDownObjectArt.door(self, rect.size, open, horizontal)

class LockerNode extends Area2D:
	var mission: Node
	var rect: Rect2 = Rect2()
	var open: bool = false
	var _inside: Node = null

	func _ready() -> void:
		collision_layer = 1 << 4
		collision_mask = 1 << 1
		position = rect.position + rect.size * 0.5
		var shape := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = rect.size + Vector2(60, 60)
		shape.shape = s
		add_child(shape)
		z_index = 1
		queue_redraw()

	func toggle_hide(player: Node) -> void:
		if player == null:
			return
		if player.in_cover:
			player.in_cover = false
			open = false
			player.global_position = global_position + Vector2(rect.size.x * 0.5 + 26.0, 0)
			if mission:
				mission.flash_message("LEFT COVER")
		else:
			player.in_cover = true
			open = true
			player.global_position = global_position
			if mission:
				mission.flash_message("HIDDEN")
		queue_redraw()

	func _draw() -> void:
		if TopDownObjectArt.draw_sprite(self, "locker_open" if open else "locker_closed", rect.size):
			return
		TopDownObjectArt.locker(self, rect.size, open)

class PickupNode extends Area2D:
	var mission: Node
	var weapon_id: String = "pistol"
	var amount: int = -1

	func _ready() -> void:
		collision_layer = 1 << 4
		collision_mask = 1 << 1
		var shape := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 26.0
		shape.shape = c
		add_child(shape)
		z_index = 1
		body_entered.connect(_on_body_entered)
		queue_redraw()

	func _on_body_entered(body: Node) -> void:
		if body == mission.player:
			var ammo := amount
			if ammo < 0:
				ammo = int(TopDownPlayer.WEAPONS.get(weapon_id, {}).get("ammo", 0))
			body.set_weapon(weapon_id, ammo)
			mission.flash_message("PICKED UP " + str(weapon_id).to_upper())
			queue_free()

	func _draw() -> void:
		var footprint := Vector2(30, 30)
		if TopDownObjectArt.draw_sprite(self, "pickup_" + weapon_id, footprint):
			return
		TopDownObjectArt.pickup(self, weapon_id)

class ExplosiveNode extends StaticBody2D:
	var mission: Node
	var rect: Rect2 = Rect2()
	var kind: String = "pump"
	var radius: float = 150.0
	var blown: bool = false
	var _shape: CollisionShape2D

	func _ready() -> void:
		collision_layer = 1 << 3
		collision_mask = 0
		position = rect.position + rect.size * 0.5
		_shape = CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = rect.size
		_shape.shape = rs
		add_child(_shape)
		z_index = 1
		queue_redraw()

	func take_hit(_dir: Vector2 = Vector2.ZERO) -> void:
		blow()

	func chain_in(delay: float) -> void:
		if blown:
			return
		blown = true   # claim it now so a second blast cannot double-trigger
		get_tree().create_timer(delay, true, false, true).timeout.connect(_detonate)

	func blow() -> void:
		if blown:
			return
		blown = true
		_detonate()

	func _detonate() -> void:
		if mission == null:
			return
		visible = false
		collision_layer = 0
		if _shape:
			_shape.set_deferred("disabled", true)
		mission.explode(global_position, radius, self)
		queue_free()

	func _draw() -> void:
		var r := Rect2(-rect.size * 0.5, rect.size)
		if kind == "pump":
			draw_rect(r, Color("#2c3138"))
			draw_rect(r, Color("#080a0c"), false, 2.0)
			draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, r.size.y * 0.42)), Color("#0f1a1c"))
			draw_rect(Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, r.size.y * 0.18)), Color(0.4, 0.9, 0.7, 0.35))
			draw_rect(Rect2(r.position + Vector2(r.size.x - 12, r.size.y * 0.55), Vector2(5, 16)), Color("#8d9298"))
			draw_line(Vector2(r.position.x + 6, r.end.y - 8), Vector2(r.end.x - 6, r.end.y - 8), Color("#8d5a2b"), 3.0)
		else:
			draw_circle(Vector2.ZERO, minf(r.size.x, r.size.y) * 0.5, Color("#3f4a44"))
			draw_circle(Vector2.ZERO, minf(r.size.x, r.size.y) * 0.5, Color("#080a0c"))
			draw_circle(Vector2.ZERO, minf(r.size.x, r.size.y) * 0.42, Color("#545f58"))
			draw_rect(Rect2(-3, -r.size.y * 0.5 + 4, 6, 8), Color("#b8443a"))
			draw_circle(Vector2.ZERO, 4.0, Color(0.9, 0.3, 0.2, 0.5))

class ExitView extends Node2D:
	var size: Vector2 = Vector2(100, 100)
	var label: String = "EXIT"
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.35, 0.85, 0.6, 0.10))
		draw_rect(r, Color(0.45, 0.95, 0.68, 0.55), false, 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(10, 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 1.0, 0.85, 0.8))

class JoystickView extends Control:
	const R_STICK := 78.0
	const R_ATTACK := 54.0
	const R_DASH := 40.0
	const R_USE := 34.0
	var mission: Node

	func _draw() -> void:
		if mission == null or not mission.touch_mode:
			return
		var font := ThemeDB.fallback_font
		var move_active: bool = mission._move_touch != -1
		var aim_active: bool = mission._aim_touch != -1

		# fixed homes, so the thumbs know where to come back to
		_draw_home(font, mission._move_base, "MOVE", Color(0.82, 0.92, 0.88), move_active)
		_draw_home(font, mission._aim_base, "AIM", Color(1.0, 0.42, 0.5), aim_active)

		if move_active:
			_draw_stick(mission._move_origin, mission.touch_move, Color(0.85, 0.95, 0.9, 0.22), Color(0.9, 1.0, 0.95, 0.5))
		if aim_active:
			_draw_stick(mission._aim_origin, mission.touch_aim, Color(1.0, 0.35, 0.45, 0.18), Color(1.0, 0.45, 0.55, 0.55))

		var p = mission.player
		var attack_label := "HIT"
		var sub := ""
		if p:
			var w: Dictionary = p.weapon()
			if not bool(w.get("melee", true)):
				attack_label = "FIRE"
			sub = str(w.get("label", "")).to_upper()
			if not bool(w.get("melee", true)):
				sub += " %d" % int(p.ammo)
		_draw_button(font, mission._btn_attack, R_ATTACK, attack_label, sub,
			mission._attack_touch != -1, Color(1.0, 0.36, 0.44))

		var dash_ready := true
		if p and p._dash_cd_left > 0.0:
			dash_ready = false
		_draw_button(font, mission._btn_dash, R_DASH, "DASH", "",
			mission._dash_touch != -1, Color(0.5, 0.85, 1.0) if dash_ready else Color(0.4, 0.45, 0.5))

		if mission.use_button_available():
			_draw_button(font, mission._btn_use, R_USE, "USE", "",
				mission._use_touch != -1, Color(0.7, 1.0, 0.82))

	func _draw_home(font: Font, center: Vector2, label: String, accent: Color, active: bool) -> void:
		var a: float = 0.0 if active else 1.0
		draw_circle(center, R_STICK, Color(1, 1, 1, 0.035 * a))
		draw_arc(center, R_STICK, 0, TAU, 40, Color(accent.r, accent.g, accent.b, 0.22 * a), 1.5)
		for i in range(4):
			var d: Vector2 = Vector2.RIGHT.rotated(i * PI * 0.5)
			draw_line(center + d * (R_STICK - 9), center + d * (R_STICK - 2), Color(accent.r, accent.g, accent.b, 0.25 * a), 1.5)
		_text(font, center + Vector2(0, R_STICK + 18), label, 12, Color(accent.r, accent.g, accent.b, 0.45 * a))

	func _draw_stick(origin: Vector2, vec: Vector2, fill: Color, ring: Color) -> void:
		draw_circle(origin, R_STICK, fill)
		draw_arc(origin, R_STICK, 0, TAU, 40, ring, 2.0)
		var knob: Vector2 = origin + vec * (R_STICK - 26.0)
		draw_circle(knob, 26.0, Color(0.95, 0.97, 0.95, 0.22))
		draw_arc(knob, 26.0, 0, TAU, 28, ring, 1.6)
		draw_circle(knob, 7.0, Color(ring.r, ring.g, ring.b, 0.5))

	func _draw_button(font: Font, center: Vector2, radius: float, label: String, sub: String,
			pressed: bool, accent: Color) -> void:
		var lift: float = 2.0 if pressed else 0.0
		draw_circle(center + Vector2(0, lift), radius, Color(accent.r, accent.g, accent.b, 0.16 if pressed else 0.08))
		draw_arc(center + Vector2(0, lift), radius, 0, TAU, 36, Color(accent.r, accent.g, accent.b, 0.85 if pressed else 0.5), 2.0)
		draw_arc(center + Vector2(0, lift), radius - 6.0, 0, TAU, 36, Color(1, 1, 1, 0.06), 10.0)
		_text(font, center + Vector2(0, 2 if sub.is_empty() else -6), label, 18, Color(0.95, 0.95, 0.92, 0.92))
		if not sub.is_empty():
			_text(font, center + Vector2(0, 16), sub, 11, Color(0.85, 0.85, 0.8, 0.55))

	func _text(font: Font, at: Vector2, text: String, size: int, color: Color) -> void:
		var sz: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		draw_string(font, at - Vector2(sz.x * 0.5, -sz.y * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

