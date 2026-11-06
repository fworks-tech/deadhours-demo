# TouchInputManager.gd
# Touch input manager: virtual joystick (left side) for 4-directional movement,
# tap-to-interact, swipe gestures, and camera pan.
# Attachable to any Control node in a 1280x720 mobile viewport.
extends Control

signal tapped(position: Vector2)
signal swiped(direction: Vector2)
signal camera_panned(offset: Vector2)
signal long_pressed(position: Vector2)
signal joystick_vector(vector: Vector2)

@export var tap_max_distance: float = 18.0
@export var tap_max_duration: float = 0.35
@export var long_press_duration: float = 0.5
@export var swipe_min_distance: float = 40.0
@export var joystick_radius: float = 80.0
@export var enable_joystick: bool = true
@export var snap_to_4_directions: bool = true

var _default_joystick_center: Vector2 = Vector2(160, 560)
var _joystick_center: Vector2 = Vector2(160, 560)
var _joystick_touch_index: int = -1
var _raw_joystick_vec: Vector2 = Vector2.ZERO
var _current_joystick_vec: Vector2 = Vector2.ZERO

var _pan_touch_index: int = -1
var _pan_start_pos: Vector2 = Vector2.ZERO
var _pan_last_pos: Vector2 = Vector2.ZERO
var _pan_start_time: float = 0.0
var _pan_total_displacement: float = 0.0
var _long_press_emitted: bool = false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	_update_default_joystick_center()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_default_joystick_center()

func _update_default_joystick_center() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.x > 0 and vp_size.y > 0:
		_default_joystick_center = Vector2(vp_size.x * 0.15, vp_size.y * 0.78)
	else:
		_default_joystick_center = Vector2(160, 560)
	if _joystick_touch_index == -1:
		_joystick_center = _default_joystick_center
	queue_redraw()

func _process(_delta: float) -> void:
	if _pan_touch_index != -1 and not _long_press_emitted:
		var touch_duration := (Time.get_ticks_msec() / 1000.0) - _pan_start_time
		if _pan_total_displacement <= tap_max_distance and touch_duration >= long_press_duration:
			_long_press_emitted = true
			long_pressed.emit(_pan_last_pos)

func _gui_input(event: InputEvent) -> void:
	_handle_input_event(event)

func _unhandled_input(event: InputEvent) -> void:
	_handle_input_event(event)

func _handle_input_event(event: InputEvent) -> void:
	var vp_width := get_viewport_rect().size.x
	if vp_width <= 0:
		vp_width = 1280.0
	var left_side_threshold := vp_width * 0.5

	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < left_side_threshold and _joystick_touch_index == -1 and enable_joystick:
				_start_joystick(event.index, event.position)
			elif _pan_touch_index == -1:
				_start_pan(event.index, event.position)
		else:
			if event.index == _joystick_touch_index:
				_end_joystick()
			if event.index == _pan_touch_index:
				_end_pan(event.position)

	elif event is InputEventScreenDrag:
		if event.index == _joystick_touch_index:
			_update_joystick_drag(event.position)
		if event.index == _pan_touch_index:
			_update_pan_drag(event.position)

	# Desktop mouse support for testing in editor / PC
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.x < left_side_threshold and _joystick_touch_index == -1 and enable_joystick:
				_start_joystick(0, event.position)
			elif _pan_touch_index == -1:
				_start_pan(0, event.position)
		else:
			if _joystick_touch_index == 0:
				_end_joystick()
			if _pan_touch_index == 0:
				_end_pan(event.position)

	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if _joystick_touch_index == 0:
				_update_joystick_drag(event.position)
			if _pan_touch_index == 0:
				_update_pan_drag(event.position)

func _start_joystick(index: int, pos: Vector2) -> void:
	_joystick_touch_index = index
	_joystick_center = pos
	_raw_joystick_vec = Vector2.ZERO
	_current_joystick_vec = Vector2.ZERO
	joystick_vector.emit(Vector2.ZERO)
	queue_redraw()

func _update_joystick_drag(pos: Vector2) -> void:
	var offset := pos - _joystick_center
	if offset.length() > 0:
		_raw_joystick_vec = offset.limit_length(joystick_radius) / joystick_radius
	else:
		_raw_joystick_vec = Vector2.ZERO

	if _raw_joystick_vec.length() < 0.2:
		_current_joystick_vec = Vector2.ZERO
	elif snap_to_4_directions:
		if abs(_raw_joystick_vec.x) > abs(_raw_joystick_vec.y):
			_current_joystick_vec = Vector2(sign(_raw_joystick_vec.x), 0.0)
		else:
			_current_joystick_vec = Vector2(0.0, sign(_raw_joystick_vec.y))
	else:
		_current_joystick_vec = _raw_joystick_vec

	joystick_vector.emit(_current_joystick_vec)
	queue_redraw()

func _end_joystick() -> void:
	_joystick_touch_index = -1
	_raw_joystick_vec = Vector2.ZERO
	_current_joystick_vec = Vector2.ZERO
	_joystick_center = _default_joystick_center
	joystick_vector.emit(Vector2.ZERO)
	queue_redraw()

func _start_pan(index: int, pos: Vector2) -> void:
	_pan_touch_index = index
	_pan_start_pos = pos
	_pan_last_pos = pos
	_pan_start_time = Time.get_ticks_msec() / 1000.0
	_pan_total_displacement = 0.0
	_long_press_emitted = false

func _update_pan_drag(pos: Vector2) -> void:
	var delta := pos - _pan_last_pos
	_pan_total_displacement += delta.length()
	if delta.length() > 1.0:
		camera_panned.emit(delta)
	_pan_last_pos = pos

func _end_pan(pos: Vector2) -> void:
	var touch_duration := (Time.get_ticks_msec() / 1000.0) - _pan_start_time
	var total_vector := pos - _pan_start_pos
	
	if not _long_press_emitted:
		if _pan_total_displacement <= tap_max_distance and touch_duration <= tap_max_duration:
			tapped.emit(pos)
		elif total_vector.length() >= swipe_min_distance:
			swiped.emit(total_vector.normalized())
			
	_pan_touch_index = -1
	_long_press_emitted = false

func _draw() -> void:
	if not enable_joystick:
		return

	var is_active := _joystick_touch_index != -1
	var center := _joystick_center if is_active else _default_joystick_center

	# Horror aesthetic colors: dark translucent base, red glowing ring and knob
	var base_fill := Color(0.1, 0.1, 0.12, 0.45) if is_active else Color(0.08, 0.08, 0.1, 0.25)
	var ring_outline := Color(0.85, 0.2, 0.2, 0.8) if is_active else Color(0.5, 0.5, 0.55, 0.35)
	var knob_fill := Color(0.9, 0.15, 0.15, 0.85) if is_active else Color(0.4, 0.4, 0.45, 0.3)

	# Base circle
	draw_circle(center, joystick_radius, base_fill)
	draw_arc(center, joystick_radius, 0.0, TAU, 36, ring_outline, 3.0)

	# Knob position
	var knob_pos := center + _raw_joystick_vec * joystick_radius
	draw_circle(knob_pos, 28.0, knob_fill)
	draw_arc(knob_pos, 28.0, 0.0, TAU, 24, ring_outline, 2.0)

func get_joystick_vector() -> Vector2:
	return _current_joystick_vec

func is_touching() -> bool:
	return _joystick_touch_index != -1 or _pan_touch_index != -1
