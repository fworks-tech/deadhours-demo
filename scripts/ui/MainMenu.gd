# MainMenu.gd
# Main Menu controller
extends Control

@onready var start_button: Button = $MarginContainer/VBoxContainer/StartButton
@onready var load_button: Button = $MarginContainer/VBoxContainer/LoadButton
@onready var settings_button: Button = $MarginContainer/VBoxContainer/SettingsButton

func _ready() -> void:
	if GameManager:
		GameManager.change_state(GameManager.GameManagerState.MENU)
	
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if load_button:
		load_button.pressed.connect(_on_load_pressed)
		load_button.disabled = not SaveManager.has_save(0)

func _on_start_pressed() -> void:
	GameManager.start_new_game()

func _on_load_pressed() -> void:
	GameManager.load_game(0)
