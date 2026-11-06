# SettingsScreen.gd
# Settings menu allowing configuration of audio volumes, language,
# haptics, motion reduction, subtitles, and dialogue auto-advance.
extends Control

@onready var back_button: Button = %BackButton
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value_label: Label = %MusicValueLabel
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_value_label: Label = %SFXValueLabel
@onready var voice_slider: HSlider = %VoiceSlider
@onready var voice_value_label: Label = %VoiceValueLabel

@onready var language_option: OptionButton = %LanguageOption
@onready var haptics_toggle: CheckButton = %HapticsToggle
@onready var reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var subtitles_toggle: CheckButton = %SubtitlesToggle
@onready var auto_advance_toggle: CheckButton = %AutoAdvanceToggle
@onready var reset_button: Button = %ResetButton

const LANGUAGES := ["en", "pt_BR"]

func _ready() -> void:
	_setup_language_options()
	_load_current_settings()
	_connect_signals()

func _setup_language_options() -> void:
	if language_option:
		language_option.clear()
		language_option.add_item("English (en)", 0)
		language_option.add_item("Português (pt_BR)", 1)

func _load_current_settings() -> void:
	if not SettingsManager:
		return
	
	var music_vol: float = SettingsManager.get_setting("music_volume", 0.0)
	var sfx_vol: float = SettingsManager.get_setting("sfx_volume", 0.0)
	var voice_vol: float = SettingsManager.get_setting("voice_volume", 0.0)
	
	if music_slider:
		music_slider.value = music_vol
		_update_music_label(music_vol)
	if sfx_slider:
		sfx_slider.value = sfx_vol
		_update_sfx_label(sfx_vol)
	if voice_slider:
		voice_slider.value = voice_vol
		_update_voice_label(voice_vol)
	
	var lang: String = SettingsManager.get_setting("language", "en")
	if language_option:
		var idx := LANGUAGES.find(lang)
		if idx != -1:
			language_option.select(idx)
	
	if haptics_toggle:
		haptics_toggle.button_pressed = SettingsManager.get_setting("haptics_enabled", true)
	if reduce_motion_toggle:
		reduce_motion_toggle.button_pressed = SettingsManager.get_setting("reduce_motion", false)
	if subtitles_toggle:
		subtitles_toggle.button_pressed = SettingsManager.get_setting("subtitles_enabled", true)
	if auto_advance_toggle:
		auto_advance_toggle.button_pressed = SettingsManager.get_setting("auto_advance_dialogue", false)

func _connect_signals() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	
	if music_slider:
		music_slider.value_changed.connect(_on_music_value_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_value_changed)
	if voice_slider:
		voice_slider.value_changed.connect(_on_voice_value_changed)
	
	if language_option:
		language_option.item_selected.connect(_on_language_selected)
	if haptics_toggle:
		haptics_toggle.toggled.connect(_on_haptics_toggled)
	if reduce_motion_toggle:
		reduce_motion_toggle.toggled.connect(_on_reduce_motion_toggled)
	if subtitles_toggle:
		subtitles_toggle.toggled.connect(_on_subtitles_toggled)
	if auto_advance_toggle:
		auto_advance_toggle.toggled.connect(_on_auto_advance_toggled)

func _on_music_value_changed(value: float) -> void:
	_update_music_label(value)
	if SettingsManager:
		SettingsManager.set_setting("music_volume", value)
	if AudioManager and AudioManager.has_method("set_music_volume"):
		AudioManager.set_music_volume(value)

func _on_sfx_value_changed(value: float) -> void:
	_update_sfx_label(value)
	if SettingsManager:
		SettingsManager.set_setting("sfx_volume", value)
	if AudioManager and AudioManager.has_method("set_sfx_volume"):
		AudioManager.set_sfx_volume(value)

func _on_voice_value_changed(value: float) -> void:
	_update_voice_label(value)
	if SettingsManager:
		SettingsManager.set_setting("voice_volume", value)
	if AudioManager and AudioManager.has_method("set_voice_volume"):
		AudioManager.set_voice_volume(value)

func _update_music_label(value: float) -> void:
	if music_value_label:
		music_value_label.text = "%d dB" % int(value)

func _update_sfx_label(value: float) -> void:
	if sfx_value_label:
		sfx_value_label.text = "%d dB" % int(value)

func _update_voice_label(value: float) -> void:
	if voice_value_label:
		voice_value_label.text = "%d dB" % int(value)

func _on_language_selected(index: int) -> void:
	if index >= 0 and index < LANGUAGES.size():
		var lang := LANGUAGES[index]
		if SettingsManager:
			SettingsManager.set_setting("language", lang)
		TranslationServer.set_locale(lang)

func _on_haptics_toggled(toggled_on: bool) -> void:
	if SettingsManager:
		SettingsManager.set_setting("haptics_enabled", toggled_on)
	if toggled_on:
		Input.vibrate_handheld(50)

func _on_reduce_motion_toggled(toggled_on: bool) -> void:
	if SettingsManager:
		SettingsManager.set_setting("reduce_motion", toggled_on)

func _on_subtitles_toggled(toggled_on: bool) -> void:
	if SettingsManager:
		SettingsManager.set_setting("subtitles_enabled", toggled_on)

func _on_auto_advance_toggled(toggled_on: bool) -> void:
	if SettingsManager:
		SettingsManager.set_setting("auto_advance_dialogue", toggled_on)

func _on_reset_pressed() -> void:
	if SettingsManager:
		SettingsManager.reset_to_defaults()
		_load_current_settings()

func _on_back_pressed() -> void:
	if SettingsManager and SettingsManager.is_haptics_enabled():
		Input.vibrate_handheld(30)
	if SceneManager:
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
