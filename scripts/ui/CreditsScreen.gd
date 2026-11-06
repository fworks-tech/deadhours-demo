# CreditsScreen.gd
# Displays scrolling credits with back button. Supports automatic scrolling
# and manual swipe/drag navigation.
extends Control

@export var scroll_speed: float = 40.0

@onready var back_button: Button = %BackButton
@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var credits_label: Label = %CreditsLabel

var _auto_scroll: bool = true

func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	if scroll_container:
		scroll_container.gui_input.connect(_on_scroll_input)
	
	_populate_credits()

func _process(delta: float) -> void:
	if _auto_scroll and scroll_container:
		var current_scroll := scroll_container.scroll_vertical
		var max_scroll := scroll_container.get_v_scroll_bar().max_value - scroll_container.get_v_scroll_bar().page
		
		if current_scroll < max_scroll:
			scroll_container.scroll_vertical = int(current_scroll + scroll_speed * delta)
		else:
			_auto_scroll = false

func _populate_credits() -> void:
	if not credits_label:
		return
	
	credits_label.text = """

BranchingPaths
A Narrative Choice Mobile Game

=== CREATIVE & NARRATIVE ===
Game Director & Lead Writer
Story Architecture & Branching Paths
Character & World Design

=== PROGRAMMING & SYSTEMS ===
Core Engine Integration
UI & Accessibility Systems
Save & Audio Architecture

=== ART & AUDIO ===
Visual Direction & Scenes
Soundscapes & Musical Score
Voice & Dialogue Direction

=== SPECIAL THANKS ===
All Playtesters & Story Contributors
Built with Godot Engine 4.x

Thank you for playing!

"""

func _on_scroll_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		# Pause auto-scroll when player touches screen
		_auto_scroll = false

func _on_back_pressed() -> void:
	if SettingsManager and SettingsManager.is_haptics_enabled():
		Input.vibrate_handheld(30)
	if SceneManager:
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
