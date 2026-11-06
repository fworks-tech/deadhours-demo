# SaveManager.gd
# Handles save/load to user:// directory. Auto-saves at every choice point
# and checkpoint. Stores story progress, flags, play time, and ending unlocks.
# Supports multiple save slots.
extends Node

signal game_saved(slot: int)
signal game_loaded_slot(slot: int)
signal save_error(message: String)

const SAVE_DIR := "user://saves/"
const MAX_SLOTS := 3
const SAVE_VERSION := 1

func _ready() -> void:
	_ensure_save_dir()

func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func auto_save() -> void:
	save_game(0)  # Slot 0 is auto-save

func save_game(slot: int) -> void:
	var save_data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"play_time": GameManager.play_time,
		"chapter": GameManager.current_chapter,
		"checkpoint": GameManager.current_checkpoint,
		"story": StoryManager.get_save_data(),
		"flags": FlagsManager.get_all_flags(),
	}
	
	var path := SAVE_DIR + "save_slot_" + str(slot) + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		save_error.emit("Failed to open save file: " + path)
		return
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	game_saved.emit(slot)

func load_game(slot: int) -> bool:
	var path := SAVE_DIR + "save_slot_" + str(slot) + ".json"
	if not FileAccess.file_exists(path):
		save_error.emit("Save file not found: " + path)
		return false
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		save_error.emit("Failed to read save file: " + path)
		return false
	
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	
	if err != OK:
		save_error.emit("Corrupted save file: " + path)
		return false
	
	var data: Dictionary = json.data
	
	# Version check
	if int(data.get("version", 0)) > SAVE_VERSION:
		save_error.emit("Save file is from a newer version")
		return false
	
	GameManager.play_time = float(data.get("play_time", 0.0))
	GameManager.current_chapter = int(data.get("chapter", 1))
	GameManager.current_checkpoint = String(data.get("checkpoint", ""))
	
	if data.has("story"):
		StoryManager.load_from_save(data["story"])
	if data.has("flags"):
		FlagsManager.load_flags(data["flags"])
	
	game_loaded_slot.emit(slot)
	return true

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(SAVE_DIR + "save_slot_" + str(slot) + ".json")

func get_save_info(slot: int) -> Dictionary:
	var path := SAVE_DIR + "save_slot_" + str(slot) + ".json"
	if not FileAccess.file_exists(path):
		return {}
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return {}
	
	var data: Dictionary = json.data
	return {
		"chapter": int(data.get("chapter", 1)),
		"checkpoint": String(data.get("checkpoint", "")),
		"play_time": float(data.get("play_time", 0.0)),
		"timestamp": float(data.get("timestamp", 0.0)),
	}

func delete_save(slot: int) -> void:
	var path := SAVE_DIR + "save_slot_" + str(slot) + ".json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func get_unlocked_endings() -> Array:
	return FlagsManager.get_unlocked_endings()

func format_play_time(seconds: float) -> String:
	var hours := int(seconds) / 3600
	var minutes := (int(seconds) % 3600) / 60
	return "%02d:%02d" % [hours, minutes]
