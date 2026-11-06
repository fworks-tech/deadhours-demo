# NpcDialogue.gd
# In-mission conversation overlay: portrait, speaker, typewriter text and
# branching choices. Reads assets/data/dialogues.json and applies the same flag
# operations the cutscenes use, so a conversation in a mission feeds the story.
#
# The tree is paused while a conversation is open (this layer keeps running),
# which is how Hotline Miami style games let a talk happen mid-firefight.
extends CanvasLayer
class_name NpcDialogue

signal closed()

const DATA_PATH := "res://assets/data/dialogues.json"
const PORTRAIT_DIR := "res://assets/images/portraits/%s.png"

static var _data: Dictionary = {}

var mission: Node = null
var conversation: Dictionary = {}
var nodes: Dictionary = {}
var current: String = ""
var npc: Node = null
var active: bool = false

var _typing: bool = false
var _full_text: String = ""
var _shown: float = 0.0
var _speed: float = 62.0

var _root: Control
var _portrait: TextureRect
var _name: Label
var _text: Label
var _choices: VBoxContainer
var _hint: Label
var _choice_nodes: Array = []

# ---------------------------------------------------------------- data

static func library() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_data = parsed
	return _data

# ---------------------------------------------------------------- ui

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	_build_ui()
	visible = false

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -300.0
	panel.offset_left = 24.0
	panel.offset_right = -24.0
	panel.offset_bottom = -20.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0c1012")
	style.border_color = Color("#3e5c46")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(220, 240)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 20)
	_name.add_theme_color_override("font_color", Color("#e6e1d5"))
	col.add_child(_name)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 17)
	_text.add_theme_color_override("font_color", Color(0.85, 0.86, 0.82))
	col.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	col.add_child(_choices)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.58))
	col.add_child(_hint)

# ---------------------------------------------------------------- flow

func open(conv_id: String, speaker_node: Node = null) -> void:
	var lib := library()
	var convs: Dictionary = lib.get("conversations", {})
	if not convs.has(conv_id):
		push_warning("NpcDialogue: unknown conversation " + conv_id)
		return
	conversation = convs[conv_id]
	nodes = conversation.get("nodes", {})
	npc = speaker_node
	current = str(conversation.get("start", "n1"))
	active = true
	visible = true
	enter_node(current)

func enter_node(node_id: String) -> void:
	if node_id.is_empty() or not nodes.has(node_id):
		close()
		return
	current = node_id
	var node: Dictionary = nodes[node_id]
	_apply(node.get("effects", []))
	var speaker := str(node.get("speaker", conversation.get("speaker", "narrator")))
	_name.text = str(node.get("name", speaker.to_upper()))
	_set_portrait(str(node.get("portrait", "")))
	_show_text(str(node.get("text", "")))
	_clear_choices()
	if node.has("choices"):
		# defer so the line can be read (or skipped) before the options appear
		_typing_finished_choices = node.get("choices", [])

var _typing_finished_choices: Array = []

func _set_portrait(key: String) -> void:
	if key.is_empty():
		_portrait.texture = null
		_portrait.visible = false
		return
	var path := PORTRAIT_DIR % key
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
		_portrait.visible = true
	else:
		_portrait.texture = null
		_portrait.visible = false

func _show_text(text: String) -> void:
	_full_text = text
	_shown = 0.0
	_typing = true
	_text.text = text
	_text.visible_characters = 0
	_hint.text = "SPACE / TAP TO CONTINUE"

func _process(delta: float) -> void:
	if not active or not _typing:
		return
	_shown += delta * _speed
	_text.visible_characters = int(_shown)
	if _shown >= float(_full_text.length()):
		_finish_typing()

func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	if not _typing_finished_choices.is_empty():
		_show_choices(_typing_finished_choices)
		_typing_finished_choices = []
		_hint.text = "1-4 / TAP TO CHOOSE"
	else:
		_hint.text = "SPACE / TAP TO CONTINUE"

func advance() -> void:
	if not active:
		return
	if _typing:
		_finish_typing()
		return
	if not _choice_nodes.is_empty():
		return
	var node: Dictionary = nodes.get(current, {})
	var next := str(node.get("next", ""))
	if next.is_empty():
		close()
	else:
		enter_node(next)

func close() -> void:
	active = false
	visible = false
	_clear_choices()
	if mission and mission.has_method("close_dialogue"):
		mission.close_dialogue()
	closed.emit()

# ---------------------------------------------------------------- choices

func _clear_choices() -> void:
	for b in _choice_nodes:
		if is_instance_valid(b):
			b.queue_free()
	_choice_nodes.clear()
	_typing_finished_choices = []

func _show_choices(list: Array) -> void:
	for i in range(list.size()):
		var choice: Dictionary = list[i]
		if not _requirements_met(choice.get("requires", {})):
			continue
		var btn := Button.new()
		btn.text = "%d. %s" % [_choice_nodes.size() + 1, str(choice.get("text", ""))]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 38)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_choose.bind(choice))
		_choices.add_child(btn)
		_choice_nodes.append(btn)

func _requirements_met(req) -> bool:
	if typeof(req) != TYPE_DICTIONARY or req.is_empty():
		return true
	for key in req.keys():
		if FlagsManager.get_flag(key) != req[key]:
			return false
	return true

func choose(index: int) -> void:
	var visible_choices := []
	for b in _choice_nodes:
		if is_instance_valid(b):
			visible_choices.append(b)
	if index < 0 or index >= visible_choices.size():
		return
	visible_choices[index].emit_signal("pressed")

func _choose(choice: Dictionary) -> void:
	_apply(choice.get("effects", []))
	var next := str(choice.get("next", ""))
	if next.is_empty() or next == "end":
		close()
	else:
		enter_node(next)

# ---------------------------------------------------------------- effects

func _apply(effects) -> void:
	if typeof(effects) != TYPE_ARRAY:
		return
	for e in effects:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		if e.has("set"):
			FlagsManager.process_flag_operations([{"set": e["set"]}])
		if e.has("inc"):
			for k in e["inc"].keys():
				FlagsManager.add_to_flag(k, int(e["inc"][k]))
		if e.has("give") and mission and mission.has_method("give_weapon"):
			mission.give_weapon(str(e["give"]), int(e.get("ammo", -1)))
		if e.has("hostile") and mission and mission.has_method("turn_hostile"):
			mission.turn_hostile(npc)
		if e.has("complete") and mission and mission.has_method("complete_mission"):
			mission.complete_mission()

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E:
			advance()
			get_viewport().set_input_as_handled()
			return
		var idx := -1
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			idx = event.keycode - KEY_1
		elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_4:
			idx = event.keycode - KEY_KP_1
		if idx >= 0:
			choose(idx)
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventScreenTouch and event.pressed:
		advance()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
