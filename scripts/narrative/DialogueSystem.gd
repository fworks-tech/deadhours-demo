# DialogueSystem.gd
# Handles the typewriter-style dialogue display with character portraits,
# speaker names, and emotion-based portrait swaps. Used in cutscenes and
# exploration scenes.
#
# Dialogue entry format (from story.json):
#   {
#     "speaker": "elena",
#     "emotion": "scared",
#     "text": "They're coming!",
#     "voice": "res://assets/audio/voice/ch1_elena_01.ogg"
#   }
#
# Portrait config is loaded from res://assets/data/portraits.json at startup.
# The config maps speaker keys to emotion → texture path pairs.
# Speakers with "portrait": null (narrator, radio, unknown) show no portrait
# and use a custom text color.
class_name DialogueSystem
extends Control

signal dialogue_finished()
signal line_shown(speaker: String, text: String)
signal choice_prompted()

@onready var _speaker_label: Label = $MarginContainer/Panel/SpeakerLabel
@onready var _text_label: RichTextLabel = $MarginContainer/Panel/TextLabel
@onready var _portrait: TextureRect = $MarginContainer/Panel/Portrait
@onready var _continue_indicator: Control = $MarginContainer/Panel/ContinueIndicator
@onready var _progress_bar: ProgressBar = $MarginContainer/Panel/ProgressBar

var _dialogue_queue: Array = []
var _current_index: int = 0
var _is_typing: bool = false
var _current_text: String = ""
var _visible_characters: int = 0
var _typewriter_speed: float = 30.0
var _portrait_map: Dictionary = {}       # speaker -> { emotion -> texture path }
var _speaker_colors: Dictionary = {}     # speaker -> Color (for special speakers)
var _default_speaker_color: Color = Color(0.9, 0.9, 0.95)

const PORTRAITS_CONFIG_PATH := "res://assets/data/portraits.json"

func _ready() -> void:
	_continue_indicator.visible = false
	_text_label.text = ""
	_speaker_label.text = ""
	_portrait.texture = null
	_load_portrait_config()

func _load_portrait_config() -> void:
	if not FileAccess.file_exists(PORTRAITS_CONFIG_PATH):
		push_warning("DialogueSystem: portraits.json not found")
		return
	
	var file := FileAccess.open(PORTRAITS_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("DialogueSystem: Failed to open portraits.json")
		return
	
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	
	if err != OK:
		push_error("DialogueSystem: Failed to parse portraits.json: " + json.get_error_message())
		return
	
	var config: Dictionary = json.data
	
	# Load portrait paths
	var portraits: Dictionary = config.get("portraits", {})
	for speaker in portraits:
		var emotions: Dictionary = portraits[speaker]
		_portrait_map[speaker] = {}
		for emotion in emotions:
			_portrait_map[speaker][emotion] = emotions[emotion]
	
	# Load special speaker colors (narrator, radio, unknown, marcus_text)
	var special_speakers := ["narrator", "unknown", "marcus_text", "radio"]
	for sp in special_speakers:
		if config.has(sp):
			var sp_data: Dictionary = config[sp]
			var color_str: String = sp_data.get("color", "#888888")
			_speaker_colors[sp] = Color.from_string(color_str, _default_speaker_color)

func _process(delta: float) -> void:
	if _is_typing:
		_visible_characters += int(_typewriter_speed * delta)
		_text_label.visible_characters = _visible_characters
		if _visible_characters >= _current_text.length():
			_is_typing = false
			_continue_indicator.visible = true

func start_dialogue(lines: Array) -> void:
	_dialogue_queue = lines
	_current_index = 0
	_typewriter_speed = 30.0 * SettingsManager.get_text_speed()
	if SettingsManager.get_text_speed() == 0.0:
		_typewriter_speed = 99999.0  # instant
	_show_line()

func _show_line() -> void:
	if _current_index >= _dialogue_queue.size():
		dialogue_finished.emit()
		_clear()
		return
	
	var line: Dictionary = _dialogue_queue[_current_index]
	var speaker: String = line.get("speaker", "")
	var emotion: String = line.get("emotion", "neutral")
	var text: String = tr(line.get("text", ""))
	var voice_path: String = line.get("voice", "")
	
	# Set speaker label with appropriate formatting
	if speaker == "narrator":
		_speaker_label.text = ""
	elif speaker == "marcus_text":
		_speaker_label.text = "[Marcus]"
	elif speaker == "radio":
		_speaker_label.text = "[RADIO]"
	elif speaker == "unknown":
		_speaker_label.text = "???"
	else:
		_speaker_label.text = speaker.capitalize()
	
	# Apply speaker color
	if _speaker_colors.has(speaker):
		_speaker_label.add_theme_color_override("font_color", _speaker_colors[speaker])
		_text_label.add_theme_color_override("default_color", _speaker_colors[speaker])
	else:
		_speaker_label.add_theme_color_override("font_color", _default_speaker_color)
		_text_label.add_theme_color_override("default_color", _default_speaker_color)
	
	_current_text = text
	_text_label.text = text
	_text_label.visible_characters = 0
	_visible_characters = 0
	_is_typing = true
	_continue_indicator.visible = false
	
	# Update portrait
	_update_portrait(speaker, emotion)
	
	# Play voice line if available
	if not voice_path.is_empty() and ResourceLoader.exists(voice_path):
		var voice := load(voice_path) as AudioStream
		AudioManager.play_voice(voice)
	
	line_shown.emit(speaker, text)

func _update_portrait(speaker: String, emotion: String) -> void:
	# Special speakers have no portrait
	if speaker in ["narrator", "radio", "marcus_text", "unknown"]:
		_portrait.texture = null
		return
	
	if _portrait_map.has(speaker):
		var emotions: Dictionary = _portrait_map[speaker]
		var texture_path: String = emotions.get(emotion, emotions.get("neutral", ""))
		if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
			_portrait.texture = load(texture_path)
		else:
			_portrait.texture = null
	else:
		_portrait.texture = null

func advance() -> void:
	if _is_typing:
		# Skip typing — reveal full text immediately
		_text_label.visible_characters = -1
		_is_typing = false
		_continue_indicator.visible = true
		return
	
	_current_index += 1
	_show_line()

func _clear() -> void:
	_text_label.text = ""
	_speaker_label.text = ""
	_portrait.texture = null
	_continue_indicator.visible = false
	_dialogue_queue.clear()
	_current_index = 0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		advance()
	elif event is InputEventMouseButton and event.pressed:
		advance()

func set_portrait_map(map: Dictionary) -> void:
	_portrait_map = map

func is_active() -> bool:
	return not _dialogue_queue.is_empty() and _current_index < _dialogue_queue.size()
