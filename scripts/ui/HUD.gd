# HUD.gd
# In-game HUD showing chapter title, objective hints, pause button, and choice counter.
extends Control

@onready var chapter_label: Label = $MarginContainer/TopBar/HBox/ChapterLabel
@onready var objective_label: Label = $MarginContainer/TopBar/HBox/ObjectiveLabel
@onready var choices_counter_label: Label = $MarginContainer/TopBar/HBox/ChoicesCounterLabel
@onready var pause_button: Button = $MarginContainer/TopBar/HBox/PauseButton
@onready var pause_overlay: Control = $PauseOverlay
@onready var resume_button: Button = $PauseOverlay/CenterContainer/VBox/ResumeButton
@onready var quit_button: Button = $PauseOverlay/CenterContainer/VBox/QuitButton

var _choices_made_count: int = 0

func _ready() -> void:
	if pause_overlay:
		pause_overlay.visible = false
	
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	if StoryManager:
		StoryManager.checkpoint_entered.connect(_on_checkpoint_entered)
		StoryManager.chapter_changed.connect(_on_chapter_changed)
		StoryManager.choice_made.connect(_on_choice_made)
	
	if GameManager:
		GameManager.game_state_changed.connect(_on_game_state_changed)
	
	if StoryManager:
		_choices_made_count = StoryManager.story_path_history.size()
	update_hud_display()

func _on_pause_button_pressed() -> void:
	if GameManager:
		GameManager.pause_game()

func _on_resume_pressed() -> void:
	if GameManager:
		GameManager.resume_game()

func _on_quit_pressed() -> void:
	if GameManager:
		if get_tree().paused:
			get_tree().paused = false
		GameManager.quit_to_menu()

func _on_checkpoint_entered(_checkpoint_id: String) -> void:
	update_hud_display()

func _on_chapter_changed(_chapter: int) -> void:
	update_hud_display()

func _on_choice_made(_choice_id: String) -> void:
	_choices_made_count += 1
	update_hud_display()

func _on_game_state_changed(new_state: GameManager.GameManagerState) -> void:
	if pause_overlay:
		pause_overlay.visible = (new_state == GameManager.GameManagerState.PAUSED)

func update_hud_display() -> void:
	if not is_node_ready():
		return
		
	# Chapter Title
	var chapter_num := StoryManager.current_chapter if StoryManager else 1
	var chapter_data := StoryManager.get_current_chapter_data() if StoryManager else {}
	var chapter_title: String = chapter_data.get("title", "Chapter %d" % chapter_num)
	if chapter_label:
		chapter_label.text = tr(chapter_title)
	
	# Objective Hint
	if objective_label and StoryManager and not StoryManager.current_checkpoint.is_empty():
		var cp := StoryManager.current_checkpoint
		var hint: String = cp.get("summary", cp.get("objective", ""))
		if hint.is_empty():
			var dialogue: Array = cp.get("dialogue", [])
			if not dialogue.is_empty():
				hint = dialogue[0].get("text", "")
		if hint.length() > 40:
			hint = hint.substr(0, 37) + "..."
		objective_label.text = tr(hint)
	
	# Choices Made Counter
	if choices_counter_label:
		choices_counter_label.text = tr("Choices: %d") % _choices_made_count

func set_objective_text(text: String) -> void:
	if objective_label:
		objective_label.text = tr(text)
