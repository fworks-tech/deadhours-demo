# BackgroundManager.gd
# Maps checkpoints to background images and handles loading/displaying them.
# Used by cutscene and exploration scenes to set the right background art.
#
# Backgrounds are defined in assets/data/portraits.json under "backgrounds".
# Scenes can request a background by key, or the checkpoint can specify
# a "background" field in story.json to set it automatically.
extends Node

signal background_changed(key: String, texture: Texture2D)

var _background_textures: Dictionary = {}  # key -> CompressedTexture2D (cached)
var _config: Dictionary = {}

const CONFIG_PATH := "res://assets/data/portraits.json"

func _ready() -> void:
	_load_config()

func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		_config = json.data.get("backgrounds", {})

func get_background(key: String) -> Texture2D:
	# Check cache
	if _background_textures.has(key):
		return _background_textures[key]
	
	# Load from config
	var path: String = _config.get(key, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	
	var texture := load(path) as Texture2D
	if texture:
		_background_textures[key] = texture
	return texture

func get_background_for_checkpoint(checkpoint: Dictionary) -> Texture2D:
	# If checkpoint explicitly specifies a background key
	if checkpoint.has("background"):
		return get_background(checkpoint["background"])
	
	# Infer from scene path — map scene files to background keys
	var scene_path: String = checkpoint.get("scene", "")
	var key := _infer_background_key(scene_path, checkpoint.get("id", ""))
	if not key.is_empty():
		return get_background(key)
	
	return null

func _infer_background_key(scene_path: String, checkpoint_id: String) -> String:
	# Map checkpoint IDs and scene paths to background keys
	var mappings := {
		"ch1_start": "ch1_bedroom",
		"ch1_choice1": "ch1_bedroom",
		"ch1_elena_enter": "ch1_bedroom",
		"ch1_refuse_door": "ch1_bedroom",
		"ch1_peephole": "ch1_hallway_peephole",
		"ch1_peephole_choice": "ch1_hallway_peephole",
		"ch1_elena_dive": "ch1_bedroom",
		"ch1_choice2": "ch1_bedroom",
		"ch1_fireescape": "ch1_fire_escape",
		"ch1_stairwell": "ch1_stairwell",
		"ch1_barricade": "ch1_bedroom",
		"ch1_barricade_choice": "ch1_bedroom",
		"ch1_marcus_infected": "ch1_bedroom",
		"ch1_marcus_test": "ch1_bedroom",
		"ch1_marcus_leaves": "ch1_bedroom",
		"ch1_barricade_survive": "ch1_bedroom",
		"ch1_choice3": "ch1_garage",
		"ch1_danny_bite": "ch1_garage",
		"ch1_danny_bite_choice": "ch1_garage",
		"ch1_take_danny": "ch1_garage",
		"ch1_leave_danny": "ch1_garage",
		"ch1_end": "route9_highway",
		"ch2_start": "ch2_gas_station",
		"ch2_choice1": "ch2_gas_station",
		"ch2_honest_approach": "ch2_gas_station",
		"ch2_lie_approach": "ch2_gas_station",
		"ch2_sneak_approach": "ch2_gas_station",
		"ch2_sneak_caught": "ch2_gas_station",
		"ch2_run_escape": "route9_highway",
		"ch2_garcia_deal": "ch2_gas_station",
		"ch2_join_group": "ch2_gas_station",
		"ch2_solo_depart": "route9_highway",
		"ch2_end": "route9_highway",
		"ch3_start": "ch3_riverside",
		"ch3_screening": "ch3_riverside",
		"ch3_danny_quarantine": "ch3_riverside",
		"ch3_danny_choice": "ch3_riverside",
		"ch3_danny_treatment": "ch3_riverside",
		"ch3_danny_peaceful": "ch3_riverside",
		"ch3_danny_final_hours": "ch3_riverside",
		"ch3_refuse_screening": "ch3_riverside",
		"ch3_outside_choice": "ch3_riverside",
		"ch3_riverside_welcome": "ch3_riverside",
		"ch3_convergence": "ch3_riverside",
		"ending_hero": "ch3_riverside",
		"ending_survivor": "route9_highway",
		"ending_martyr": "route9_highway",
		"ending_drifter": "route9_highway",
		"ending_coward": "ch3_riverside",
		"ending_cure": "ch3_riverside",
		"ending_silence": "ch3_riverside",
	}
	
	if mappings.has(checkpoint_id):
		return mappings[checkpoint_id]
	
	return ""

func list_available_backgrounds() -> Array:
	return _config.keys()

func preload_all_backgrounds() -> void:
	for key in _config:
		get_background(key)
