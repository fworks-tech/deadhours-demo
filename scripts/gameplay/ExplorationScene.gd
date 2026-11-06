# ExplorationScene.gd
# Template for exploration/puzzle gameplay phases.
# Handles touch movement, object interactions, dialogue, camera panning, and checkpoint completion.
extends Node2D

signal objective_completed(objective_id: String)

@export var move_speed: float = 200.0
@export var interaction_distance: float = 80.0

@onready var camera: Camera2D = $Camera2D
@onready var player: CharacterBody2D = $Player
@onready var interactables_container: Node2D = $Interactables
@onready var dialogue_system: Control = $UI/DialogueSystem
@onready var hud: Control = $UI/HUD
@onready var touch_input_manager: Control = $UI/TouchInputManager

var _target_position: Vector2 = Vector2.ZERO
var _has_move_target: bool = false
var _joystick_vector: Vector2 = Vector2.ZERO
var _pending_interactable: Area2D = null
var _manual_camera_pan_timer: float = 0.0

func _ready() -> void:
	if GameManager:
		GameManager.change_state(GameManager.GameManagerState.PLAYING)
		
	if touch_input_manager:
		touch_input_manager.tapped.connect(_on_touch_tapped)
		touch_input_manager.joystick_vector.connect(_on_joystick_vector)
		if touch_input_manager.has_signal("swiped"):
			touch_input_manager.swiped.connect(_on_touch_swiped)
		if touch_input_manager.has_signal("camera_panned"):
			touch_input_manager.camera_panned.connect(_on_camera_panned)
		
	if dialogue_system and dialogue_system.has_signal("dialogue_finished"):
		dialogue_system.dialogue_finished.connect(_on_dialogue_finished)
		
	_setup_interactables()
	_load_checkpoint_dialogue()

func _physics_process(delta: float) -> void:
	if not player:
		return
		
	# Disable movement during active dialogue
	if dialogue_system and dialogue_system.has_method("is_active") and dialogue_system.is_active():
		player.velocity = Vector2.ZERO
		return
		
	var velocity := Vector2.ZERO
	
	# Keyboard / InputMap movement fallback
	var kb_input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if kb_input.length() > 0.1:
		velocity = kb_input.normalized() * move_speed
		_has_move_target = false
	# Joystick movement takes priority over tap movement target
	elif _joystick_vector.length() > 0.1:
		velocity = _joystick_vector * move_speed
		_has_move_target = false
	elif _has_move_target:
		var dir := _target_position - player.global_position
		if dir.length() <= 8.0:
			_has_move_target = false
			velocity = Vector2.ZERO
			if _pending_interactable:
				_interact_with(_pending_interactable)
				_pending_interactable = null
		else:
			velocity = dir.normalized() * move_speed
			
	player.velocity = velocity
	player.move_and_slide()
	
	# Smooth camera follow unless user is actively panning camera
	if camera and player:
		if _manual_camera_pan_timer > 0.0:
			_manual_camera_pan_timer -= delta
		else:
			camera.global_position = camera.global_position.lerp(player.global_position, delta * 5.0)

func _setup_interactables() -> void:
	if not interactables_container:
		return
	for child in interactables_container.get_children():
		if child is Area2D:
			child.input_pickable = true

func _on_touch_tapped(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var clicked_interactable := _raycast_interactable_at(world_pos)
	
	if clicked_interactable:
		var dist := player.global_position.distance_to(clicked_interactable.global_position)
		if dist <= interaction_distance:
			_interact_with(clicked_interactable)
		else:
			_target_position = clicked_interactable.global_position
			_has_move_target = true
			_pending_interactable = clicked_interactable
	else:
		_target_position = world_pos
		_has_move_target = true
		_pending_interactable = null

func _raycast_interactable_at(world_pos: Vector2) -> Area2D:
	if get_world_2d():
		var space_state := get_world_2d().direct_space_state
		var query := PhysicsPointQueryParameters2D.new()
		query.position = world_pos
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var results := space_state.intersect_point(query)
		for result in results:
			var collider = result.get("collider")
			if collider is Area2D:
				return collider
	return _find_interactable_at(world_pos)

func _on_joystick_vector(vec: Vector2) -> void:
	_joystick_vector = vec
	if vec.length() > 0.1:
		_has_move_target = false
		_pending_interactable = null

func _on_touch_swiped(direction: Vector2) -> void:
	if camera:
		var pan_offset := direction * 120.0
		var tween := create_tween()
		tween.tween_property(camera, "position", camera.position + pan_offset, 0.35)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		_manual_camera_pan_timer = 2.0

func _on_camera_panned(offset: Vector2) -> void:
	if camera:
		camera.global_position -= offset
		_manual_camera_pan_timer = 2.0

func _find_interactable_at(world_pos: Vector2) -> Area2D:
	if not interactables_container:
		return null
		
	for child in interactables_container.get_children():
		if child is Area2D:
			var dist := world_pos.distance_to(child.global_position)
			if dist < 50.0:
				return child
	return null

func _interact_with(object: Area2D) -> void:
	var obj_name: String = object.name
	var dialogue: Array = object.get("dialogue") if "dialogue" in object else []
	
	if dialogue.is_empty() and object.has_meta("dialogue"):
		dialogue = object.get_meta("dialogue")
		
	if not dialogue.is_empty() and dialogue_system:
		dialogue_system.start_dialogue(dialogue)
	else:
		_on_object_objective_complete(obj_name)

func _load_checkpoint_dialogue() -> void:
	if not StoryManager or StoryManager.current_checkpoint.is_empty():
		return
	var cp: Dictionary = StoryManager.current_checkpoint
	var dialogue: Array = cp.get("dialogue", [])
	if not dialogue.is_empty() and dialogue_system:
		dialogue_system.start_dialogue(dialogue)

func _on_dialogue_finished() -> void:
	if StoryManager and not StoryManager.current_checkpoint.is_empty():
		var cp: Dictionary = StoryManager.current_checkpoint
		if cp.get("auto_advance", false) and cp.has("next"):
			StoryManager.advance_to_next_checkpoint()

func _on_object_objective_complete(objective_id: String) -> void:
	objective_completed.emit(objective_id)
	if StoryManager and StoryManager.current_checkpoint.has("next"):
		StoryManager.advance_to_next_checkpoint()

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if camera:
		var canvas_transform := get_canvas_transform()
		return canvas_transform.affine_inverse() * screen_pos
	return screen_pos
