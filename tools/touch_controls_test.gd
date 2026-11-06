# touch_controls_test.gd
# Headless QA harness for the touch controls: dual sticks, action buttons and
# multi-touch. Run with:
#   godot --headless --path . res://tools/TouchControlsTest.tscn
extends Node

var _fail := 0

func _check(label: String, ok: bool, detail: String = "") -> void:
	print("TOUCH %s %s %s" % ["OK  " if ok else "FAIL", label, detail])
	if not ok:
		_fail += 1

func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = idx
	ev.position = pos
	ev.pressed = pressed
	mission._unhandled_input(ev)

func _drag(idx: int, pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = idx
	ev.position = pos
	mission._unhandled_input(ev)

var mission: Node

func _ready() -> void:
	await get_tree().process_frame
	mission = load("res://scenes/gameplay/TopDownMission.tscn").instantiate()
	mission.debug_skip_briefing = true
	add_child(mission)
	await get_tree().process_frame
	await get_tree().process_frame

	mission.start_mission()
	mission.touch_mode = true
	mission.layout_size = Vector2(720, 1280)
	mission._layout_touch()
	var p = mission.player
	var vs: Vector2 = Vector2(720, 1280)
	print("TOUCH viewport=", vs)

	# layout sanity: every control inside the viewport
	for item in [["move", mission._move_base, 78.0], ["aim", mission._aim_base, 78.0],
			["attack", mission._btn_attack, 54.0], ["dash", mission._btn_dash, 40.0]]:
		var c: Vector2 = item[1]
		var r: float = item[2]
		var inside := c.x - r >= 0.0 and c.y - r >= 0.0 and c.x + r <= vs.x and c.y + r <= vs.y
		_check("layout_" + str(item[0]), inside, str(c))

	# --- left stick walks ---
	_touch(1, mission._move_base + Vector2(10, 0), true)
	_drag(1, mission._move_base + Vector2(60, 0))
	_check("move_stick", mission.touch_move.x > 0.6 and absf(mission.touch_move.y) < 0.1,
		"vec=" + str(mission.touch_move))
	_touch(1, mission._move_base + Vector2(60, 0), false)
	_check("move_release", mission.touch_move.length() < 0.01)

	# --- right stick aims and does NOT fire by itself ---
	_touch(2, mission._aim_base, true)
	_drag(2, mission._aim_base + Vector2(0, -70))
	_check("aim_stick", mission.touch_aim.y < -0.8, "vec=" + str(mission.touch_aim))
	_check("aim_no_autofire", mission.touch_fire == false)
	_touch(2, mission._aim_base + Vector2(0, -70), false)
	_check("aim_release", mission.touch_aim.length() < 0.01)

	# --- attack button ---
	_touch(3, mission._btn_attack, true)
	_check("attack_press", mission.touch_fire)
	_check("attack_not_stick", mission._aim_touch == -1 and mission._move_touch == -1)
	p._attack_cd = 0.0
	var before_kills: int = mission.kills
	p.aim_dir = Vector2.RIGHT
	_check("attack_held_reads", p._fire_pressed())
	_touch(3, mission._btn_attack, false)
	_check("attack_release", mission.touch_fire == false)

	# --- dash button is edge triggered and consumed ---
	_touch(4, mission._btn_dash, true)
	_check("dash_press", mission.touch_dash)
	var consumed: bool = p._dash_pressed()
	_check("dash_consumed", consumed and mission.touch_dash == false)
	_check("dash_not_repeat", p._dash_pressed() == false)
	_touch(4, mission._btn_dash, false)

	# --- use button ---
	_touch(5, mission._btn_use, true)
	_check("use_press", mission.touch_interact)
	var used: bool = p._interact_pressed()
	_check("use_consumed", used and mission.touch_interact == false)
	_touch(5, mission._btn_use, false)
	_check("use_hidden_without_target", mission.use_button_available() == false)

	# --- multi-touch: move and aim at the same time ---
	_touch(6, mission._move_base, true)
	_drag(6, mission._move_base + Vector2(0, 60))
	_touch(7, mission._aim_base, true)
	_drag(7, mission._aim_base + Vector2(-60, 0))
	_check("multitouch_move", mission.touch_move.y > 0.6)
	_check("multitouch_aim", mission.touch_aim.x < -0.6)
	_touch(6, mission._move_base, false)
	_touch(7, mission._aim_base, false)

	# --- attack while moving keeps both ---
	_touch(8, mission._move_base, true)
	_drag(8, mission._move_base + Vector2(55, 0))
	_touch(9, mission._btn_attack, true)
	_check("attack_while_moving", mission.touch_fire and mission.touch_move.x > 0.5)
	_touch(8, mission._move_base, false)
	_touch(9, mission._btn_attack, false)

	print("TOUCH RESULT failures=", _fail)
	get_tree().quit()
