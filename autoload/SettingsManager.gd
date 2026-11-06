# SettingsManager.gd
# Persists player settings (audio volumes, text speed, language, haptics,
# reduce motion) to a ConfigFile in user:// directory.
extends Node

signal settings_changed(key: String, value: Variant)

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_TEXT_SPEED := 1.0
const DEFAULT_LANGUAGE := "en"

var _config: ConfigFile = ConfigFile.new()
var _settings: Dictionary = {
	"music_volume": 0.0,       # dB, -80 to 0
	"sfx_volume": 0.0,
	"voice_volume": 0.0,
	"text_speed": 1.0,         # multiplier: 0.5 slow, 1.0 normal, 2.0 fast, 0.0 instant
	"language": "en",
	"haptics_enabled": true,
	"reduce_motion": false,
	"high_contrast": false,
	"subtitles_enabled": true,
	"auto_advance_dialogue": false,
}

func _ready() -> void:
	_load_settings()

func _load_settings() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err == OK:
		for key in _settings:
			if _config.has_section_key("settings", key):
				_settings[key] = _config.get_value("settings", key)

func _save_settings() -> void:
	for key in _settings:
		_config.set_value("settings", key, _settings[key])
	_config.save(SETTINGS_PATH)

func get_setting(key: String, default: Variant = null) -> Variant:
	if _settings.has(key):
		return _settings[key]
	return default

func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value
	_save_settings()
	settings_changed.emit(key, value)

func reset_to_defaults() -> void:
	_config.clear()
	_save_settings()
	_load_settings()
	settings_changed.emit("reset", null)

func get_all_settings() -> Dictionary:
	return _settings.duplicate()

func get_text_speed() -> float:
	return float(_settings.get("text_speed", DEFAULT_TEXT_SPEED))

func get_language() -> String:
	return String(_settings.get("language", DEFAULT_LANGUAGE))

func is_haptics_enabled() -> bool:
	return bool(_settings.get("haptics_enabled", true))

func is_reduce_motion() -> bool:
	return bool(_settings.get("reduce_motion", false))

func is_subtitles_enabled() -> bool:
	return bool(_settings.get("subtitles_enabled", true))
