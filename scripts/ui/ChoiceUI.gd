# ChoiceUI.gd
# The visual interface for presenting choices to the player. Shows option
# buttons, optional countdown timer bar, and handles tap selection.
# Designed for mobile — large touch targets, vertical stacking.
extends Control

signal choice_selected(choice_id: String)

@onready var _choice_container: VBoxContainer = $MarginContainer/ScrollContainer/ChoiceContainer
@onready var _timer_bar: ProgressBar = $MarginContainer/TimerBar
@onready var _title_label: Label = $MarginContainer/TitleLabel

var _choice_buttons: Array[Button] = []

const BUTTON_MIN_HEIGHT := 72
const BUTTON_MAX_HEIGHT := 120

func _ready() -> void:
	# Overlay starts hidden; ChoiceManager's signals drive visibility.
	visible = false
	_timer_bar.visible = false
	_title_label.text = tr("What will you do?")
	
	ChoiceManager.choices_shown.connect(_on_choices_shown)
	ChoiceManager.choices_hidden.connect(_on_choices_hidden)
	ChoiceManager.timer_expired.connect(_on_timer_expired)

func _process(delta: float) -> void:
	if ChoiceManager.is_timer_active():
		_timer_bar.value = ChoiceManager.get_timer_remaining() / ChoiceManager.choice_timer_seconds * 100.0

func _on_choices_shown(choices: Array) -> void:
	_clear_choices()
	visible = true
	
	# Optional: show character context if this choice is "speaking for" someone
	var character: String = StoryManager.current_checkpoint.get("speaker", "")
	if not character.is_empty():
		_title_label.text = tr("As {character}...").format({"character": character.capitalize()})
	else:
		_title_label.text = tr("What will you do?")
	
	for choice in choices:
		var button := Button.new()
		button.text = tr(choice.get("text", "..."))
		button.custom_minimum_size = Vector2(0, BUTTON_MIN_HEIGHT)
		button.add_theme_font_size_override("font_size", 18)
		# Button colors come from the project theme (restyled per game by
		# the generator) — no hardcoded styleboxes here.
			
		var choice_id: String = choice.get("id", "")
		button.pressed.connect(func(): _on_choice_pressed(choice_id))
		
		_choice_container.add_child(button)
		_choice_buttons.append(button)
		
		# Animate button in with a slight delay
		button.modulate.a = 0.0
		button.position.y += 20
		var tween := create_tween()
		tween.tween_interval(float(_choice_buttons.size() - 1) * 0.1)
		tween.set_parallel(true)
		tween.tween_property(button, "modulate:a", 1.0, 0.3)
		tween.tween_property(button, "position:y", button.position.y - 20, 0.3)
	
	# Show timer if active
	if ChoiceManager.is_timer_active():
		_timer_bar.visible = true
		_timer_bar.value = 100.0

func _clear_choices() -> void:
	for button in _choice_buttons:
		button.queue_free()
	_choice_buttons.clear()

func _on_choices_hidden() -> void:
	_clear_choices()
	_timer_bar.visible = false
	visible = false

func _on_choice_pressed(choice_id: String) -> void:
	# Button press animation
	var button: Button = null
	var non_empty := _choice_buttons.filter(func(b): return b.text != "")
	if non_empty.size() > 0:
		button = non_empty.front()
	ChoiceManager.select_choice(choice_id)
	choice_selected.emit(choice_id)
	
	# Haptic feedback
	if SettingsManager.is_haptics_enabled():
		Input.vibrate_handheld(50)

func _on_timer_expired() -> void:
	_timer_bar.visible = false



