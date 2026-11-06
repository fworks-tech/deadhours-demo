# PauseMenu.gd
# Pause overlay screen allowing resuming game, adjusting settings,
# restarting chapter, or returning to main menu.
extends Control

@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_signals()

func _connect_signals() -> void:
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	_play_click_sfx()
	if GameManager:
		GameManager.resume_game()
	visible = false

func _on_settings_pressed() -> void:
	_play_click_sfx()
	if SceneManager:
		SceneManager.change_scene("res://scenes/ui/SettingsScreen.tscn")

func _on_restart_pressed() -> void:
	_play_click_sfx()
	if GameManager:
		GameManager.resume_game()
		# Restart current checkpoint or chapter
		if StoryManager and StoryManager.current_checkpoint_id != "":
			StoryManager.enter_checkpoint(StoryManager.current_checkpoint_id)
		else:
			GameManager.start_new_game()

func _on_quit_pressed() -> void:
	_play_click_sfx()
	if GameManager:
		GameManager.resume_game()
		GameManager.quit_to_menu()

func _play_click_sfx() -> void:
	if SettingsManager and SettingsManager.is_haptics_enabled():
		Input.vibrate_handheld(30)
