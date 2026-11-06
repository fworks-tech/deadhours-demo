# StoryManager.gd
# The core narrative engine — loads story data from JSON, tracks current
# position in the story tree, evaluates conditions, and drives scene transitions.
#
# Story data structure (JSON):
#   {
#     "chapters": {
#       "1": {
#         "id": "ch1",
#         "title": "Chapter 1: The First Night",
#         "checkpoints": {
#           "ch1_start": { ... },
#           "ch1_choice1": { ... }
#         }
#       }
#     }
#   }
#
# Each checkpoint:
#   {
#     "id": "ch1_start",
#     "chapter": 1,
#     "scene": "res://scenes/cutscenes/Ch1Intro.tscn",
#     "type": "cutscene" | "choice" | "exploration" | "puzzle" | "end",
#     "dialogue": [ ... ],
#     "choices": [ ... ],
#     "on_enter": [ ... ],     # flag operations to run on entry (array)
#     "next": "checkpoint_id", # for linear progression (no choice)
#     "end_type": "good" | "bad" | "neutral"  # if type == "end"
#   }
#
# Each choice:
#   {
#     "id": "choice_1a",
#     "text": "Open the door",
#     "requires": { "has_key": true },                    # simple equality
#     "requires": { "trust_alice": { ">=": 2 } },          # operator comparison
#     "effects": [ ... ],       # flag changes
#     "next": "checkpoint_id", # where this choice leads
#     "character": "player"     # who is speaking
#   }
extends Node

signal checkpoint_entered(checkpoint_id: String)

# Last ending reached — consumed by GameOverScreen to display the actual
# outcome instead of a hardcoded one.
var last_ending_type: String = ""
var last_ending_title: String = ""
var last_ending_narration: String = ""
signal choice_presented(choices: Array)
signal choice_made(choice_id: String)
signal story_loaded()
signal chapter_changed(chapter: int)
signal ending_reached(ending_type: String)

var story_data: Dictionary = {}
var current_checkpoint_id: String = ""
var current_checkpoint: Dictionary = {}
var current_chapter: int = 1
var story_path_history: Array[String] = []

const STORY_DATA_PATH := "res://assets/data/story.json"
const GAME_SCENE_PATH := "res://scenes/core/GameScene.tscn"
const SAVE_HISTORY_LIMIT := 500

func _ready() -> void:
	load_story_data()

func load_story_data() -> bool:
	if not FileAccess.file_exists(STORY_DATA_PATH):
		push_warning("Story data file not found: " + STORY_DATA_PATH)
		return false

	var file := FileAccess.open(STORY_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open story data file")
		return false

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		push_error("Story JSON parse error: " + json.get_error_message())
		return false

	story_data = json.data
	story_loaded.emit()
	return true

func get_entry_checkpoint_id() -> String:
	## First checkpoint of the lowest-numbered chapter. Used by
	## GameManager.start_new_game() so new games work with any story data.
	var chapters: Dictionary = story_data.get("chapters", {})
	var keys := chapters.keys()
	keys.sort_custom(func(a, b): return int(str(a)) < int(str(b)))
	if keys.is_empty():
		return ""
	var checkpoints: Dictionary = chapters[keys[0]].get("checkpoints", {})
	if checkpoints.is_empty():
		return ""
	return str(checkpoints.keys()[0])


func enter_checkpoint(checkpoint_id: String) -> void:
	if not story_data.has("chapters"):
		push_error("No chapters in story data")
		return

	var checkpoint := find_checkpoint(checkpoint_id)
	if checkpoint.is_empty():
		push_error("Checkpoint not found: " + checkpoint_id)
		return

	current_checkpoint_id = checkpoint_id
	current_checkpoint = checkpoint
	story_path_history.append(checkpoint_id)
	if story_path_history.size() > SAVE_HISTORY_LIMIT:
		story_path_history.pop_front()

	# Run on_enter flag operations
	if checkpoint.has("on_enter"):
		FlagsManager.process_flag_operations(checkpoint["on_enter"])

	checkpoint_entered.emit(checkpoint_id)

	# Update current chapter
	var ch: int = int(checkpoint.get("chapter", current_chapter))
	if ch != current_chapter:
		change_chapter(ch)

	# Handle checkpoint type first: state changes, choice presentation and
	# ending handling are scene-independent (ChoiceUI is a root-level overlay,
	# endings transition to GameOverScreen themselves).
	var cp_type: String = checkpoint.get("type", "cutscene")
	match cp_type:
		"cutscene":
			GameManager.change_state(GameManager.GameManagerState.CUTSCENE)
		"choice":
			GameManager.change_state(GameManager.GameManagerState.CHOICE_PENDING)
			present_choices(checkpoint)
		"exploration":
			GameManager.change_state(GameManager.GameManagerState.PLAYING)
		"puzzle":
			GameManager.change_state(GameManager.GameManagerState.PLAYING)
		"mission":
			GameManager.change_state(GameManager.GameManagerState.PLAYING)
		"end":
			handle_ending(checkpoint)
			return  # handle_ending transitions to GameOverScreen itself

	# Scene-aware transition: if the checkpoint declares a scene file that
	# differs from the current one, change to it — the new scene's
	# CutsceneTemplate picks up current_checkpoint on _ready and plays the
	# dialogue. Checkpoints without a "scene" field stay in the current scene
	# (in-scene replay is handled by CutsceneTemplate._on_checkpoint_entered).
	var scene_path: String = checkpoint.get("scene", "")
	if not scene_path.is_empty() and scene_path != SceneManager.get_current_scene_path():
		if ResourceLoader.exists(scene_path):
			SceneManager.change_scene(scene_path)
		elif SceneManager.get_current_scene_path() != GAME_SCENE_PATH:
			# Data-driven fallback: a checkpoint whose scene file has not been
			# authored yet is rendered by the story container (dialogue/choices)
			# instead of leaving the player stranded in the previous scene.
			SceneManager.change_scene(GAME_SCENE_PATH)

func present_choices(checkpoint: Dictionary) -> void:
	var available_choices: Array = []
	var choices: Array = checkpoint.get("choices", [])

	for choice in choices:
		if can_show_choice(choice):
			available_choices.append(choice)

	choice_presented.emit(available_choices)

func can_show_choice(choice: Dictionary) -> bool:
	if not choice.has("requires"):
		return true

	# Use FlagsManager's evaluate_requirements which handles both
	# simple equality AND operator comparisons ({ ">=": 2 })
	var req: Dictionary = choice["requires"]
	return FlagsManager.evaluate_requirements(req)

func make_choice(choice_id: String) -> void:
	var choices: Array = current_checkpoint.get("choices", [])
	var selected_choice: Dictionary = {}

	for choice in choices:
		if choice.get("id", "") == choice_id:
			selected_choice = choice
			break

	if selected_choice.is_empty():
		push_error("Choice not found: " + choice_id)
		return

	# Apply choice effects
	if selected_choice.has("effects"):
		FlagsManager.process_flag_operations(selected_choice["effects"])

	choice_made.emit(choice_id)

	# Auto-save at decision point
	SaveManager.auto_save()

	# Transition to next checkpoint
	var next_id: String = selected_choice.get("next", "")
	if next_id.is_empty():
		push_warning("Choice has no 'next' checkpoint")
		return

	enter_checkpoint(next_id)

func find_checkpoint(checkpoint_id: String) -> Dictionary:
	var chapters: Dictionary = story_data.get("chapters", {})
	for chapter_key in chapters:
		var chapter: Dictionary = chapters[chapter_key]
		var checkpoints: Dictionary = chapter.get("checkpoints", {})
		if checkpoints.has(checkpoint_id):
			return checkpoints[checkpoint_id]
	return {}

func get_current_chapter_data() -> Dictionary:
	var chapters: Dictionary = story_data.get("chapters", {})
	return chapters.get(str(current_chapter), {})

func advance_to_next_checkpoint() -> void:
	var next_id: String = current_checkpoint.get("next", "")
	if next_id.is_empty():
		push_warning("No 'next' checkpoint defined")
		return
	enter_checkpoint(next_id)

func handle_ending(checkpoint: Dictionary) -> void:
	var end_type: String = checkpoint.get("end_type", "neutral")
	FlagsManager.unlock_ending(current_checkpoint_id)
	SaveManager.save_game(0)
	
	# Data-driven ending details for GameOverScreen (falls back to the
	# built-in good/bad/neutral text when the checkpoint has none).
	last_ending_type = end_type
	last_ending_title = checkpoint.get("ending_title", checkpoint.get("title", ""))
	last_ending_narration = checkpoint.get("narration", checkpoint.get("text", ""))
	
	ending_reached.emit(end_type)
	GameManager.change_state(GameManager.GameManagerState.EPILOGUE)
	SceneManager.change_scene("res://scenes/ui/GameOverScreen.tscn")

func get_total_endings() -> int:
	var count := 0
	var chapters: Dictionary = story_data.get("chapters", {})
	for chapter_key in chapters:
		var checkpoints: Dictionary = chapters[chapter_key].get("checkpoints", {})
		for cp_key in checkpoints:
			if checkpoints[cp_key].get("type", "") == "end":
				count += 1
	return count

func get_visited_endings() -> Array:
	return FlagsManager.get_unlocked_endings()

func change_chapter(chapter: int) -> void:
	current_chapter = chapter
	chapter_changed.emit(chapter)

func get_save_data() -> Dictionary:
	return {
		"current_checkpoint_id": current_checkpoint_id,
		"current_chapter": current_chapter,
		"story_path_history": story_path_history
	}

func load_from_save(data: Dictionary) -> void:
	current_checkpoint_id = data.get("current_checkpoint_id", "")
	current_chapter = int(data.get("current_chapter", 1))
	var history: Array = data.get("story_path_history", [])
	story_path_history.clear()
	for cp_id in history:
		story_path_history.append(cp_id)

func get_checkpoint_count() -> int:
	var count := 0
	var chapters: Dictionary = story_data.get("chapters", {})
	for chapter_key in chapters:
		count += chapters[chapter_key].get("checkpoints", {}).size()
	return count

func get_all_checkpoint_ids() -> Array:
	var ids: Array = []
	var chapters: Dictionary = story_data.get("chapters", {})
	for chapter_key in chapters:
		var checkpoints: Dictionary = chapters[chapter_key].get("checkpoints", {})
		ids.append_array(checkpoints.keys())
	return ids
