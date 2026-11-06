# NpcDialogue.gd
# In-mission conversation overlay in the Dead Hours look: the game keeps showing
# behind a soft vignette, the panel is void-black with a hairline accent stripe,
# and every speaker has a pitch-shifted "voice" blip while the line types out.
#
# Reads assets/data/dialogues.json and applies the same flag operations the
# cutscenes use, so a conversation in a mission feeds the story.
extends CanvasLayer
class_name NpcDialogue

signal closed()

const DATA_PATH := "res://assets/data/dialogues.json"
const PORTRAIT_DIR := "res://assets/images/portraits/%s.png"
const VOICE_DIR := "res://assets/audio/voices/voice_%s.wav"
const VOICE_VARIANTS := ["a", "b", "c", "d"]

const BONE := Color("#e6e1d5")
const VOID := Color("#0a0c0b")
const HINT := Color(0.52, 0.58, 0.55)

# speaker -> accent colour and voice pitch (fake voice, Animal-Crossing style)
const SPEAKERS := {
	"narrator": {"accent": Color("#6b7a72"), "pitch": 0.0},
	"marcus": {"accent": Color("#9fbfd0"), "pitch": 0.88},
	"stranger": {"accent": Color("#a8564f"), "pitch": 1.02},
	"garcia": {"accent": Color("#c9a35a"), "pitch": 0.7},
	"priya": {"accent": Color("#7fb7a1"), "pitch": 1.3},
	"elena": {"accent": Color("#d8d3c4"), "pitch": 1.12},
	"danny": {"accent": Color("#b98a68"), "pitch": 1.2},
}

static var _data: Dictionary = {}

var mission: Node = null
var conversation: Dictionary = {}
var nodes: Dictionary = {}
var current: String = ""
var npc: Node = null
var active: bool = false

var _speaker: String = "narrator"
var _accent: Color = Color("#6b7a72")
var _typing: bool = false
var _full_text: String = ""
var _shown: float = 0.0
var _speed: float = 62.0
var _blip_counter: int = 0

var _root: Control
var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _stripe: ColorRect
var _name: Label
var _text: Label
var _choices: VBoxContainer
var _hint: Label
var _choice_nodes: Array = []
var _typing_finished_choices: Array = []
var _voice_players: Array = []

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
	_load_voices()
	visible = false

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# the game stays visible: only a light wash plus a bottom gradient for legibility
	var wash := ColorRect.new()
	wash.color = Color(0.02, 0.03, 0.035, 0.16)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(wash)

	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.03, 0.035, 0.0))
	grad.set_color(1, Color(0.02, 0.03, 0.035, 0.86))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 8
	tex.height = 128
	var shade := TextureRect.new()
	shade.texture = tex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -340.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -286.0
	panel.offset_left = 28.0
	panel.offset_right = -28.0
	panel.offset_bottom = -24.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(VOID.r, VOID.g, VOID.b, 0.9)
	style.border_color = Color(0.24, 0.33, 0.34, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	panel.add_child(row)

	_stripe = ColorRect.new()
	_stripe.custom_minimum_size = Vector2(3, 0)
	_stripe.color = _accent
	row.add_child(_stripe)

	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 18)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(inner)
	row.add_child(pad)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.custom_minimum_size = Vector2(214, 232)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.03, 0.04, 0.045, 1.0)
	pstyle.border_color = _accent
	pstyle.set_border_width_all(1)
	pstyle.set_corner_radius_all(2)
	_portrait_frame.add_theme_stylebox_override("panel", pstyle)
	inner.add_child(_portrait_frame)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_frame.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	inner.add_child(col)

	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 19)
	col.add_child(_name)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 1)
	rule.color = Color(_accent.r, _accent.g, _accent.b, 0.35)
	col.add_child(rule)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 17)
	_text.add_theme_color_override("font_color", Bone_color())
	col.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 5)
	col.add_child(_choices)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", HINT)
	col.add_child(_hint)

func Bone_color() -> Color:
	return BONE

func _load_voices() -> void:
	for key in VOICE_VARIANTS:
		var path := VOICE_DIR % key
		if ResourceLoader.exists(path):
			_voice_players.append(load(path))

func _set_accent(speaker: String) -> void:
	var cfg: Dictionary = SPEAKERS.get(speaker, {"accent": Color("#8f9a92"), "pitch": 1.0})
	_accent = cfg.get("accent", Color("#8f9a92"))
	_speaker = speaker
	if _stripe:
		_stripe.color = _accent
	if _name:
		_name.add_theme_color_override("font_color", _accent)
	if _portrait_frame:
		var st := _portrait_frame.get_theme_stylebox("panel")
		if st is StyleBoxFlat:
			st.border_color = _accent

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
	_set_accent(speaker)
	_name.text = str(node.get("name", speaker.to_upper()))
	_set_portrait(str(node.get("portrait", "")))
	_show_text(str(node.get("text", "")))
	_clear_choices()
	if node.has("choices"):
		_typing_finished_choices = node.get("choices", [])

func _set_portrait(key: String) -> void:
	if key.is_empty():
		_portrait.texture = null
		_portrait_frame.visible = false
		return
	var path := PORTRAIT_DIR % key
	if ResourceLoader.exists(path):
		_portrait.texture = load(path)
		_portrait_frame.visible = true
	else:
		_portrait.texture = null
		_portrait_frame.visible = false

func _show_text(text: String) -> void:
	_full_text = text
	_shown = 0.0
	_typing = true
	_blip_counter = 0
	_text.text = text
	_text.visible_characters = 0
	_hint.text = "SPACE / TAP TO CONTINUE"

func _process(delta: float) -> void:
	if not active or not _typing:
		return
	_shown += delta * _speed
	var before := _text.visible_characters
	_text.visible_characters = int(_shown)
	if _text.visible_characters != before:
		_maybe_blip(before, _text.visible_characters)
	if _shown >= float(_full_text.length()):
		_finish_typing()

func _maybe_blip(from: int, to: int) -> void:
	if _voice_players.is_empty():
		return
	var cfg: Dictionary = SPEAKERS.get(_speaker, {"pitch": 1.0})
	var pitch: float = float(cfg.get("pitch", 1.0))
	if pitch <= 0.0:            # narrator stays silent
		return
	for i in range(max(0, from), min(to, _full_text.length())):
		var ch := _full_text[i]
		if ch == " " or ch == "." or ch == ",":
			continue
		_blip_counter += 1
		if _blip_counter % 2 == 0:
			var stream = _voice_players[(i + _blip_counter) % _voice_players.size()]
			AudioManager.play_sfx(stream, pitch * randf_range(0.94, 1.08))
			break

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
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", BONE)
		btn.add_theme_color_override("font_hover_color", Color("#0a0c0b"))

		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.06, 0.08, 0.09, 0.92)
		normal.border_color = Color(_accent.r, _accent.g, _accent.b, 0.5)
		normal.border_width_left = 3
		normal.set_corner_radius_all(1)
		normal.content_margin_left = 10
		normal.content_margin_right = 8
		btn.add_theme_stylebox_override("normal", normal)

		var hover := StyleBoxFlat.new()
		hover.bg_color = _accent
		hover.border_color = _accent
		hover.border_width_left = 3
		hover.set_corner_radius_all(1)
		hover.content_margin_left = 10
		hover.content_margin_right = 8
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)

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
