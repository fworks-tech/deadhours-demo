# CutscenePlayer.gd
# Orchestrates a full cutscene sequence — dialogue, camera movements,
# sprite animations, transitions between "shots," and camera effects like screen shake.
#
# A cutscene scene (.tscn) uses this script on its root node and contains:
#   - Camera2D for scripted camera moves
#   - Sprite2D / AnimatedSprite2D nodes for characters
#   - A DialogueSystem instance for text display
#   - A timeline data array (set via inspector or from story data)
extends Node2D

signal cutscene_started()
signal cutscene_finished()
signal shot_changed(shot_index: int)

@onready var _camera: Camera2D = $Camera2D
@onready var _dialogue: DialogueSystem = $DialogueSystem

# Timeline: a sequence of "shots," each with camera, character, and dialogue data
# Format:
#   [
#     {
#       "camera": { "position": [100, 200], "zoom": [1.5, 1.5], "duration": 1.0 },
#       "shake": { "intensity": 10.0, "duration": 0.5 },
#       "characters": [ { "node": "Alice", "position": [200, 300], "animation": "idle_worried", "visible": true } ],
#       "dialogue": [ { "speaker": "alice", "emotion": "worried", "text": "..." } ],
#       "wait": 0.5,
#       "fade": { "color": "black", "duration": 1.0 }
#     },
#     ...
#   ]
var _timeline: Array = []
var _current_shot: int = 0
var _is_playing: bool = false
var _character_nodes: Dictionary = {}  # name -> Node reference

# Screen shake variables
var _shake_time: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0

func _ready() -> void:
	# Index child character nodes by name
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			_character_nodes[child.name.to_lower()] = child
	
	if _dialogue:
		_dialogue.dialogue_finished.connect(_on_dialogue_finished)
	
	if GameManager:
		GameManager.change_state(GameManager.GameManagerState.CUTSCENE)
	cutscene_started.emit()

func _process(delta: float) -> void:
	# Process screen shake offset
	if _shake_time > 0.0:
		_shake_time -= delta
		if _shake_time <= 0.0:
			_shake_time = 0.0
			if _camera:
				_camera.offset = Vector2.ZERO
		else:
			var current_intensity := _shake_intensity * (_shake_time / _shake_duration)
			if _camera:
				_camera.offset = Vector2(
					randf_range(-current_intensity, current_intensity),
					randf_range(-current_intensity, current_intensity)
				)

# Method to offset Camera2D position randomly over duration
func shake_camera(intensity: float, duration: float) -> void:
	if not _camera or intensity <= 0.0 or duration <= 0.0:
		if _camera:
			_camera.offset = Vector2.ZERO
		_shake_time = 0.0
		return
	
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_time = duration

func play_timeline(timeline: Array) -> void:
	_timeline = timeline
	_current_shot = 0
	_is_playing = true
	_play_current_shot()

func _play_current_shot() -> void:
	if _current_shot >= _timeline.size():
		_on_cutscene_complete()
		return
	
	var shot: Dictionary = _timeline[_current_shot]
	shot_changed.emit(_current_shot)
	
	# Handle camera
	if shot.has("camera") and _camera:
		_animate_camera(shot["camera"])
	
	# Handle screen shake
	if shot.has("shake"):
		var shake_val = shot["shake"]
		if shake_val is Dictionary:
			shake_camera(float(shake_val.get("intensity", 10.0)), float(shake_val.get("duration", 0.5)))
		elif typeof(shake_val) == TYPE_FLOAT or typeof(shake_val) == TYPE_INT:
			shake_camera(float(shake_val), 0.5)
	
	# Handle character positions/animations
	if shot.has("characters"):
		_animate_characters(shot["characters"])
	
	# Handle fade
	if shot.has("fade"):
		_play_fade(shot["fade"])
	
	# Handle dialogue (waits for dialogue to complete before advancing)
	if shot.has("dialogue") and _dialogue:
		_dialogue.start_dialogue(shot["dialogue"])
	else:
		# No dialogue — advance after wait or immediately
		var wait_time: float = shot.get("wait", 0.5)
		await get_tree().create_timer(wait_time).timeout
		_advance_shot()

func _animate_camera(cam_data: Dictionary) -> void:
	if not _camera:
		return
	var target_pos := Vector2(
		float(cam_data.get("position", [_camera.position.x, _camera.position.y])[0]),
		float(cam_data.get("position", [_camera.position.x, _camera.position.y])[1])
	)
	var target_zoom := Vector2(
		float(cam_data.get("zoom", [1.0, 1.0])[0]),
		float(cam_data.get("zoom", [1.0, 1.0])[1])
	)
	var duration := float(cam_data.get("duration", 1.0))
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_camera, "position", target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "zoom", target_zoom, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _animate_characters(characters: Array) -> void:
	for char_data in characters:
		var node_name: String = char_data.get("node", "").to_lower()
		var char_node = _character_nodes.get(node_name)
		if char_node == null:
			continue
		
		# Visibility
		if char_data.has("visible"):
			char_node.visible = bool(char_data["visible"])
		
		# Position
		if char_data.has("position"):
			var target := Vector2(float(char_data["position"][0]), float(char_data["position"][1]))
			if char_data.has("move_duration"):
				var tween := create_tween()
				tween.tween_property(char_node, "position", target, float(char_data["move_duration"]))
			else:
				char_node.position = target
		
		# Animation
		if char_node is AnimatedSprite2D and char_data.has("animation"):
			var anim_name: String = char_data["animation"]
			if char_node.sprite_frames.has_animation(anim_name):
				char_node.play(anim_name)

func _play_fade(fade_data: Dictionary) -> void:
	var duration := float(fade_data.get("duration", 1.0))
	pass

func _on_dialogue_finished() -> void:
	if _is_playing:
		_advance_shot()

func _advance_shot() -> void:
	_current_shot += 1
	_play_current_shot()

func _on_cutscene_complete() -> void:
	_is_playing = false
	cutscene_finished.emit()
	
	if StoryManager and StoryManager.current_checkpoint:
		var cp_type: String = StoryManager.current_checkpoint.get("type", "cutscene")
		if cp_type == "choice" and StoryManager:
			# Re-enter the choice checkpoint so StoryManager presents
			# the choices through ChoiceManager -> ChoiceUI.
			StoryManager.present_choices(StoryManager.current_checkpoint)
		elif StoryManager.current_checkpoint.has("next"):
			StoryManager.advance_to_next_checkpoint()
		else:
			if GameManager:
				GameManager.change_state(GameManager.GameManagerState.PLAYING)
	else:
		if GameManager:
			GameManager.change_state(GameManager.GameManagerState.PLAYING)

func skip_cutscene() -> void:
	_is_playing = false
	if _dialogue and _dialogue.has_method("advance"):
		_dialogue.advance()
	_on_cutscene_complete()
