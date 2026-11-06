# TopDownNpc.gd
# A character you can talk to inside a mission. Place them from level data:
#   "npcs": [{"id":"marcus","name":"MARCUS","char":"marcus",
#             "pos":[700,1270],"facing":"south","conversation":"marcus_landing"}]
#
# The body uses the same layered figure as everyone else, so NPCs sit in the
# same art language; the name tag and talk ring are drawn on the mission layer.
extends Area2D
class_name TopDownNpc

var mission: Node = null
var npc_id: String = ""
var display_name: String = "SURVIVOR"
var conversation: String = ""
var character: String = ""
var facing: Vector2 = Vector2.DOWN
var hostile: bool = false

var figure: TopDownFigure = null
var _near: bool = false

func _ready() -> void:
	collision_layer = 1 << 4
	collision_mask = 1 << 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 34.0
	shape.shape = circle
	add_child(shape)

	figure = TopDownFigure.new()
	var look := _look()
	figure.setup(look)
	figure.view_dir = facing
	figure.rotation = facing.angle() + PI * 0.5
	figure.hunch = float(look.get("hunch", 0.0))
	figure.weapon = str(look.get("weapon", "fists"))
	add_child(figure)
	z_index = 1
	queue_redraw()

func _look() -> Dictionary:
	var lib := TopDownFigure.library()
	var npcs: Dictionary = lib.get("npcs", {})
	var key := character if not character.is_empty() else npc_id
	if npcs.has(key):
		return npcs[key].duplicate(true)
	# fall back to a muted survivor palette so a data typo never crashes a level
	return {
		"name": display_name, "skin": "#c39a76", "hair": "#2f2620",
		"top": "#3a4340", "top_dark": "#2a3230", "pants": "#2f3238",
		"boots": "#191b1f", "accent": "#8a6a3a", "blood": "#5a1418",
		"eye": "#1b1512", "build": 1.0, "zombie": false,
	}

func talk() -> void:
	if mission and mission.has_method("open_dialogue"):
		mission.open_dialogue(conversation, self)

func set_near(value: bool) -> void:
	if _near == value:
		return
	_near = value
	queue_redraw()

func _process(_delta: float) -> void:
	if mission == null or mission.player == null:
		return
	var close: bool = global_position.distance_to(mission.player.global_position) < 96.0
	set_near(close)
	# look at the player when they come close, so the talk reads as an invitation
	if close and not hostile:
		var to_player: Vector2 = global_position.direction_to(mission.player.global_position)
		if to_player.length() > 0.05:
			facing = to_player
			figure.view_dir = to_player
			figure.rotation = to_player.angle() + PI * 0.5

func _draw() -> void:
	if _near:
		draw_circle(Vector2(0, 6), 30.0, Color(0.28, 0.42, 0.32, 0.18))
		draw_arc(Vector2(0, 6), 30.0, 0.0, TAU, 26, Color(0.5, 0.78, 0.6, 0.55), 2.0)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2(-w * 0.5, -46), display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		Color(0.86, 0.88, 0.84, 0.85))
	if _near:
		draw_string(font, Vector2(-24, -58), "TALK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.55, 0.9, 0.7, 0.9))
