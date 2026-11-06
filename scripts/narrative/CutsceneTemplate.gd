# CutsceneTemplate.gd
# Reusable cutscene template extending CutscenePlayer.
# Loads timeline data from checkpoint or constructs default timeline from dialogue.
# Automatically sets the background image based on the current checkpoint via BackgroundManager.
extends "res://scripts/narrative/CutscenePlayer.gd"

@onready var background: Sprite2D = $Background
@onready var alice_sprite: Sprite2D = $Alice
@onready var bob_sprite: Sprite2D = $Bob
@onready var player_sprite: Sprite2D = $Player

func _ready() -> void:
	super._ready()
	_setup_background()
	setup_from_checkpoint()

func _setup_background() -> void:
	if not StoryManager or StoryManager.current_checkpoint.is_empty():
		return
	
	var bg_texture := BackgroundManager.get_background_for_checkpoint(StoryManager.current_checkpoint)
	if bg_texture:
		background.texture = bg_texture
		# Scale to fill viewport
		var viewport_size := Vector2(1280, 720)
		if bg_texture.get_width() > 0:
			var scale_x := viewport_size.x / bg_texture.get_width()
			var scale_y := viewport_size.y / bg_texture.get_height()
			background.scale = Vector2(scale_x, scale_y)
			background.position = Vector2(viewport_size.x / 2, viewport_size.y / 2)
	else:
		# Fallback: dark background
		background.modulate = Color(0.05, 0.05, 0.08)

func setup_from_checkpoint(checkpoint_data: Dictionary = {}) -> void:
	if checkpoint_data.is_empty() and StoryManager:
		checkpoint_data = StoryManager.current_checkpoint
		
	if checkpoint_data.is_empty():
		return
		
	var timeline: Array = []
	if checkpoint_data.has("timeline"):
		timeline = checkpoint_data["timeline"]
	else:
		timeline = _construct_timeline_from_dialogue(checkpoint_data)
		
	if not timeline.is_empty():
		play_timeline(timeline)

func _construct_timeline_from_dialogue(checkpoint_data: Dictionary) -> Array:
	var dialogue_lines: Array = checkpoint_data.get("dialogue", [])
	if dialogue_lines.is_empty():
		return []
		
	var cam_pos := Vector2(640, 360)
	if _camera:
		cam_pos = _camera.position
		
	var shot := {
		"camera": {
			"position": [cam_pos.x, cam_pos.y],
			"zoom": [1.0, 1.0],
			"duration": 0.5
		},
		"characters": [
			{ "node": "alice", "visible": true, "position": [alice_sprite.position.x if alice_sprite else 300, alice_sprite.position.y if alice_sprite else 400] },
			{ "node": "bob", "visible": false, "position": [bob_sprite.position.x if bob_sprite else 900, bob_sprite.position.y if bob_sprite else 400] },
			{ "node": "player", "visible": true, "position": [player_sprite.position.x if player_sprite else 640, player_sprite.position.y if player_sprite else 450] }
		],
		"dialogue": dialogue_lines
	}
	return [shot]

# Called when checkpoint changes — reloads the background, and for cutscene
# checkpoints hosted by THIS scene, replay the new checkpoint's dialogue.
func _on_checkpoint_entered(checkpoint_id: String) -> void:
	_setup_background()
	if StoryManager == null or StoryManager.current_checkpoint.is_empty():
		return
	var cp: Dictionary = StoryManager.current_checkpoint
	if cp.get("type", "cutscene") != "cutscene":
		return  # choices/endings are handled by ChoiceUI and GameOverScreen
	var scene_path: String = cp.get("scene", "")
	if not scene_path.is_empty() and scene_path != SceneManager.get_current_scene_path():
		return  # a different scene file hosts this checkpoint — it replays on _ready
	setup_from_checkpoint(cp)
