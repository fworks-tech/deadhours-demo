# GameScene.gd
# The main gameplay container. Loads the current checkpoint and instantiates
# the appropriate scene type (cutscene, exploration, puzzle) as a child.
# Manages the flow between dialogue, choices, and exploration phases.
extends Node2D

signal scene_ready()
signal checkpoint_scene_loaded(checkpoint_id: String)

@onready var _camera: Camera2D = $Camera2D
@onready var _content_layer: Node2D = $ContentLayer
@onready var _hud: Control = $HUD/HUD

var _current_content: Node = null
var _current_checkpoint_id: String = ""

func _ready() -> void:
	StoryManager.checkpoint_entered.connect(_on_checkpoint_entered)
	
	# If we have a checkpoint, load it
	if not StoryManager.current_checkpoint_id.is_empty():
		_on_checkpoint_entered(StoryManager.current_checkpoint_id)
	else:
		# Default to chapter 1 start
		StoryManager.enter_checkpoint("ch1_start")
	
	scene_ready.emit()

func _on_checkpoint_entered(checkpoint_id: String) -> void:
	_current_checkpoint_id = checkpoint_id
	var checkpoint: Dictionary = StoryManager.current_checkpoint
	
	if checkpoint.is_empty():
		push_error("GameScene: empty checkpoint data for " + checkpoint_id)
		return
	
	var scene_path: String = checkpoint.get("scene", "")
	var cp_type: String = checkpoint.get("type", "cutscene")

	# Scene-based checkpoints (missions, cutscenes with their own .tscn) are
	# loaded by StoryManager.change_scene. GameScene must not also instance
	# them into ContentLayer or the scene runs twice.
	if cp_type == "mission" and not scene_path.is_empty() and ResourceLoader.exists(scene_path):
		_update_hud(checkpoint)
		return
	
	# Clear previous content
	if _current_content != null and is_instance_valid(_current_content):
		_current_content.queue_free()
	
	# Update HUD
	_update_hud(checkpoint)
	
	# Load the scene for this checkpoint
	if not scene_path.is_empty() and ResourceLoader.has_cached(scene_path) or ResourceLoader.exists(scene_path):
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene:
			_current_content = packed_scene.instantiate()
			_content_layer.add_child(_current_content)
			_connect_content_signals(_current_content)
			checkpoint_scene_loaded.emit(checkpoint_id)
		else:
			push_warning("GameScene: failed to load scene: " + scene_path)
			_fallback_to_dialogue(checkpoint)
	else:
		# Scene file doesn't exist yet — run dialogue directly
		_fallback_to_dialogue(checkpoint)

func _fallback_to_dialogue(checkpoint: Dictionary) -> void:
	# If no scene file exists, show dialogue + choices using built-in UI
	# This lets the game run even before all scene files are created
	var dialogue_lines: Array = checkpoint.get("dialogue", [])
	
	if dialogue_lines.size() > 0:
		# Create a temporary dialogue display
		var dialogue_scene := load("res://scenes/narrative/DialogueSystem.tscn") as PackedScene
		if dialogue_scene:
			_current_content = dialogue_scene.instantiate()
			_content_layer.add_child(_current_content)
			_current_content.start_dialogue(dialogue_lines)
			_current_content.dialogue_finished.connect(func():
				_on_dialogue_complete(checkpoint)
			)
	else:
		_on_dialogue_complete(checkpoint)

func _on_dialogue_complete(checkpoint: Dictionary) -> void:
	var cp_type: String = checkpoint.get("type", "cutscene")
	
	match cp_type:
		"choice":
			ChoiceManager.present_choices(checkpoint)
		"end":
			StoryManager.handle_ending(checkpoint)
		"cutscene", _:
			if checkpoint.has("next"):
				StoryManager.advance_to_next_checkpoint()

func _connect_content_signals(content: Node) -> void:
	if content.has_signal("cutscene_finished"):
		content.cutscene_finished.connect(func():
			var cp_type: String = StoryManager.current_checkpoint.get("type", "cutscene")
			if cp_type == "choice":
				ChoiceManager.present_choices(StoryManager.current_checkpoint)
			elif StoryManager.current_checkpoint.has("next"):
				StoryManager.advance_to_next_checkpoint()
		)
	
	if content.has_signal("choice_selected"):
		content.choice_selected.connect(func(choice_id: String):
			ChoiceManager.select_choice(choice_id)
		)

func _update_hud(checkpoint: Dictionary) -> void:
	var chapter: int = checkpoint.get("chapter", StoryManager.current_chapter)
	var title: String = ""
	
	# Get chapter title
	var chapter_data: Dictionary = StoryManager.story_data.get("chapters", {}).get(str(chapter), {})
	if chapter_data.has("title"):
		title = chapter_data["title"]
	
	if _hud:
		_hud.update_hud_display()
		_hud.set_objective_text(_get_objective_hint(checkpoint))

func _get_objective_hint(checkpoint: Dictionary) -> String:
	var cp_type: String = checkpoint.get("type", "cutscene")
	match cp_type:
		"cutscene": return ""
		"choice": return tr("Make your choice...")
		"exploration": return tr("Explore the area")
		"puzzle": return tr("Solve the puzzle")
		"end": return tr("The End")
		_: return ""

