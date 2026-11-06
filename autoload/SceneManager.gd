# SceneManager.gd
# Handles scene transitions with fade in/out. Manages a transition overlay
# layer that sits above all game content.
extends Node

signal scene_change_started(target: String)
signal scene_change_completed(target: String)

var _current_scene_path: String = ""
var _transition_layer: CanvasLayer = null
var _fade_rect: ColorRect = null
var _is_transitioning: bool = false

const FADE_DURATION := 0.5

func _ready() -> void:
	_create_transition_layer()

func _create_transition_layer() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.layer = 100
	add_child(_transition_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_rect.modulate.a = 0.0
	_transition_layer.add_child(_fade_rect)

func change_scene(scene_path: String, fade: bool = true) -> void:
	if _is_transitioning:
		return

	scene_change_started.emit(scene_path)

	if fade:
		_is_transitioning = true
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

		var tween := create_tween()
		tween.tween_property(_fade_rect, "modulate:a", 1.0, FADE_DURATION)
		tween.tween_callback(func():
			_perform_scene_change(scene_path)
		)
		tween.tween_property(_fade_rect, "modulate:a", 0.0, FADE_DURATION)
		tween.tween_callback(func():
			_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_is_transitioning = false
			scene_change_completed.emit(scene_path)
		)
	else:
		_perform_scene_change(scene_path)
		scene_change_completed.emit(scene_path)

func _perform_scene_change(scene_path: String) -> void:
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("Failed to change scene to: " + scene_path)
		return
	_current_scene_path = scene_path

func get_current_scene_path() -> String:
	return _current_scene_path

func is_transitioning() -> bool:
	return _is_transitioning
