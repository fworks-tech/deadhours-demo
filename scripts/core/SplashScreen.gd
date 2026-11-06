# SplashScreen.gd
# Splash screen controller: displays game title/logo with fade in/out,
# allows skipping on tap, and transitions to MainMenu.
extends Control

@export var splash_duration: float = 3.0
@export var fade_duration: float = 0.8
@export var next_scene: String = "res://scenes/ui/MainMenu.tscn"

@onready var _logo_container: Control = $CenterContainer
@onready var _fade_rect: ColorRect = $FadeOverlay

var _has_transitioned: bool = false
var _tween: Tween

func _ready() -> void:
	if GameManager:
		GameManager.change_state(GameManager.GameManagerState.SPLASH)
	
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 1.0
	_logo_container.modulate.a = 0.0
	
	_start_splash_sequence()

func _start_splash_sequence() -> void:
	_tween = create_tween()
	# Fade in logo and fade out dark overlay
	_tween.parallel().tween_property(_fade_rect, "modulate:a", 0.0, fade_duration)
	_tween.parallel().tween_property(_logo_container, "modulate:a", 1.0, fade_duration)
	# Display wait
	var hold_time := maxf(0.1, splash_duration - (fade_duration * 2.0))
	_tween.tween_interval(hold_time)
	# Fade out logo and fade in dark overlay
	_tween.parallel().tween_property(_fade_rect, "modulate:a", 1.0, fade_duration)
	_tween.parallel().tween_property(_logo_container, "modulate:a", 0.0, fade_duration)
	# Transition
	_tween.tween_callback(_on_splash_finished)

func _gui_input(event: InputEvent) -> void:
	if _is_tap_event(event):
		skip()

func _unhandled_input(event: InputEvent) -> void:
	if _is_tap_event(event):
		skip()

func _is_tap_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch and event.pressed:
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false

func skip() -> void:
	if _has_transitioned:
		return
	if _tween and _tween.is_running():
		_tween.kill()
	_on_splash_finished()

func _on_splash_finished() -> void:
	if _has_transitioned:
		return
	_has_transitioned = true
	SceneManager.change_scene(next_scene)
