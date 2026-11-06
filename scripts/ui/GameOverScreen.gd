# GameOverScreen.gd
# Displays final outcome screen, showing ending title and narration
# based on ending_type (good, bad, neutral).
extends Control

@export var ending_type: String = "neutral"

@onready var title_label: Label = %TitleLabel
@onready var ending_type_label: Label = %EndingTypeLabel
@onready var narration_label: Label = %NarrationLabel
@onready var play_again_button: Button = %PlayAgainButton
@onready var share_button: Button = %ShareButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var status_label: Label = %StatusLabel

const ENDING_DETAILS := {
	"good": {
		"title": "A Hopeful Horizon",
		"type_text": "GOOD ENDING",
		"color": Color(0.3, 0.9, 0.4, 1.0),
		"narration": "Through your choices and resolve, you unraveled the mystery and protected those around you. The path ahead is clear and bright."
	},
	"bad": {
		"title": "Consumed by Shadows",
		"type_text": "BAD ENDING",
		"color": Color(0.9, 0.3, 0.3, 1.0),
		"narration": "Mistrust and tragic decisions led to an untimely demise. The shadows closed in, leaving unanswered secrets behind."
	},
	"neutral": {
		"title": "An Uncertain Path",
		"type_text": "NEUTRAL ENDING",
		"color": Color(0.85, 0.85, 0.85, 1.0),
		"narration": "You survived the ordeal, but at great cost. Some truths remain hidden, and the consequences of your choices will echo forever."
	}
}

func _ready() -> void:
	if GameManager:
		GameManager.change_state(GameManager.GameManagerState.GAME_OVER)
	
	_connect_signals()
	
	# Data-driven: StoryManager records what actually happened; the exported
	# ending_type is only a fallback for hand-wired ending scenes.
	var reached_type: String = StoryManager.last_ending_type if StoryManager else ""
	if not reached_type.is_empty():
		ending_type = reached_type
	setup_ending(ending_type)

func setup_ending(type: String) -> void:
	ending_type = type
	var details: Dictionary = ENDING_DETAILS.get(type, ENDING_DETAILS["neutral"])
	
	# Checkpoint-provided ending text overrides the built-in defaults.
	if StoryManager and not StoryManager.last_ending_title.is_empty():
		details["title"] = StoryManager.last_ending_title
	if StoryManager and not StoryManager.last_ending_narration.is_empty():
		details["narration"] = StoryManager.last_ending_narration
	
	if title_label:
		title_label.text = details.get("title", "THE END")
	if ending_type_label:
		ending_type_label.text = details.get("type_text", "ENDING")
		ending_type_label.add_theme_color_override("font_color", details.get("color", Color.WHITE))
	if narration_label:
		narration_label.text = details.get("narration", "")
	if status_label:
		status_label.text = ""

func _connect_signals() -> void:
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again_pressed)
	if share_button:
		share_button.pressed.connect(_on_share_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

func _on_play_again_pressed() -> void:
	_play_click_sfx()
	if GameManager:
		GameManager.start_new_game()

func _on_share_pressed() -> void:
	_play_click_sfx()
	var share_text := "I reached the %s ending '%s' in BranchingPaths!" % [ending_type_label.text if ending_type_label else "narrative", title_label.text if title_label else ""]
	DisplayServer.clipboard_set(share_text)
	if status_label:
		status_label.text = "Result copied to clipboard!"

func _on_main_menu_pressed() -> void:
	_play_click_sfx()
	if GameManager:
		GameManager.quit_to_menu()

func _play_click_sfx() -> void:
	if SettingsManager and SettingsManager.is_haptics_enabled():
		Input.vibrate_handheld(30)
