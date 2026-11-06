# ChoiceManager.gd
# Manages the UI presentation of choices — handles the visual flow of
# presenting options to the player, timing (optional countdown for tension),
# hiding/disabling choices, and feeding the selection back to StoryManager.
extends Node

signal choices_shown(choices: Array)
signal choices_hidden()
signal choice_selected(choice_id: String)
signal timer_expired()

@export var use_choice_timer: bool = false
@export var choice_timer_seconds: float = 10.0

var _timer_active: bool = false
var _timer_remaining: float = 0.0
var _current_choices: Array = []
var _choice_ui: Control = null

const CHOICE_UI_SCENE := preload("res://scenes/ui/ChoiceUI.tscn")

func _ready() -> void:
	StoryManager.choice_presented.connect(_on_choices_presented)
	_ensure_choice_ui()

func _ensure_choice_ui() -> void:
	## The choice overlay is engine-owned: it lives in its own CanvasLayer so
	## choices can be presented from ANY scene (chapter cutscenes, GameScene,
	## future genres) without each scene needing to instance ChoiceUI.
	if _choice_ui and is_instance_valid(_choice_ui):
		return
	var layer := CanvasLayer.new()
	layer.name = "ChoiceOverlay"
	layer.layer = 10
	_choice_ui = CHOICE_UI_SCENE.instantiate()
	layer.add_child(_choice_ui)
	get_tree().root.add_child.call_deferred(layer)

func _process(delta: float) -> void:
	if _timer_active:
		_timer_remaining -= delta
		if _timer_remaining <= 0.0:
			_timer_active = false
			timer_expired.emit()
			# If timer expires, pick a "default/silent" choice or auto-progress
			_on_timer_expired()

func _on_choices_presented(choices: Array) -> void:
	_ensure_choice_ui()
	_current_choices = choices
	choices_shown.emit(choices)
	
	if use_choice_timer and choices.size() > 1:
		_timer_active = true
		_timer_remaining = choice_timer_seconds

func select_choice(choice_id: String) -> void:
	if not _current_choices.any(func(c): return c.get("id", "") == choice_id):
		push_warning("Invalid choice selection: " + choice_id)
		return
	
	_timer_active = false
	choice_selected.emit(choice_id)
	choices_hidden.emit()
	StoryManager.make_choice(choice_id)

func _on_timer_expired() -> void:
	# When the timer runs out, select the last (usually "silent/default") choice
	# This creates tension — not choosing IS a choice
	if _current_choices.is_empty():
		return
	
	var default_choice: Dictionary = _current_choices[-1]
	select_choice(default_choice.get("id", ""))

func get_timer_remaining() -> float:
	return _timer_remaining

func is_timer_active() -> bool:
	return _timer_active

func get_current_choices() -> Array:
	return _current_choices

func hide_choices() -> void:
	_timer_active = false
	_current_choices.clear()
	choices_hidden.emit()
