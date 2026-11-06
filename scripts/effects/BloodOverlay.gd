# BloodOverlay.gd
# Controls the blood overlay effect on layer 99 with smooth fade-in/fade-out methods.
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

@export var max_alpha: float = 0.8

var _tween: Tween

func _ready() -> void:
	# Start with alpha set to max_alpha or shader default
	if color_rect and color_rect.material:
		color_rect.material.set_shader_parameter("blood_alpha", max_alpha)

func fade_in(duration: float = 1.0, target_alpha: float = -1.0) -> void:
	if target_alpha < 0.0:
		target_alpha = max_alpha
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	if color_rect and color_rect.material:
		_tween.tween_method(_set_blood_alpha, _get_blood_alpha(), target_alpha, duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)

func fade_out(duration: float = 1.0) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	if color_rect and color_rect.material:
		_tween.tween_method(_set_blood_alpha, _get_blood_alpha(), 0.0, duration)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN)

func set_blood_alpha(alpha: float) -> void:
	_set_blood_alpha(alpha)

func _set_blood_alpha(alpha: float) -> void:
	if color_rect and color_rect.material:
		color_rect.material.set_shader_parameter("blood_alpha", alpha)

func _get_blood_alpha() -> float:
	if color_rect and color_rect.material:
		return float(color_rect.material.get_shader_parameter("blood_alpha"))
	return 0.0
