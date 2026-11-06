# PaintedZombieSprite.gd
# Attaches a painted GegX zombie (4 directions, 12-frame walk) to an enemy and
# replaces the procedural body. Reads the enemy's `facing` each frame, picks the
# strip for that direction and walks it while the enemy moves.
#
# Sheets: assets/images/sprites/zombies_painted/<character>_<direction>.png
# Pivot from the pack: feet on the 110th row of a 128 px cell, centred on 64.
extends Node2D

const CONFIG := "res://assets/data/painted_zombies.json"
const SHEET := "res://assets/images/sprites/zombies_painted/%s_%s.png"

static var _config: Dictionary = {}

var enemy: Node = null
var character: String = "fresh_zombie"
var cell: int = 128
var foot: int = 110
var frames: int = 12
var fps: float = 10.0

var _sprite: Sprite2D
var _dir: String = "south"
var _t: float = 0.0
var _prev: Vector2 = Vector2.ZERO
var _moving: bool = false
var _tex_cache: Dictionary = {}

static func config() -> Dictionary:
	if not _config.is_empty():
		return _config
	if not FileAccess.file_exists(CONFIG):
		return {}
	var f := FileAccess.open(CONFIG, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	_config = parsed
	return _config

func setup(target: Node, char_id: String) -> void:
	enemy = target
	var cfg := config()
	if not cfg.is_empty():
		character = char_id if char_id != "" else str(cfg.get("characters", ["fresh_zombie"])[0])
		cell = int(cfg.get("cell", 128))
		foot = int(cfg.get("foot", 110))
		frames = int(cfg.get("frames", 12))
		fps = float(cfg.get("fps", 10))
	else:
		character = char_id
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.position = Vector2(-cell * 0.5, -float(foot))
	_sprite.hframes = frames
	_sprite.frame = 0
	add_child(_sprite)
	_prev = target.global_position if target else Vector2.ZERO
	_apply_direction("south")
	queue_redraw()

func _texture(dir: String) -> Texture2D:
	var key := character + "_" + dir
	if _tex_cache.has(key):
		return _tex_cache[key]
	var path := SHEET % [character, dir]
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[key] = tex
	return tex

func _apply_direction(dir: String) -> void:
	if dir == _dir and _sprite.texture != null:
		return
	var tex := _texture(dir)
	if tex == null:
		return
	_dir = dir
	_sprite.texture = tex

func _process(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var pos: Vector2 = enemy.global_position
	var step: Vector2 = pos - _prev
	_moving = step.length() > 0.35
	_prev = pos
	var dir_vec: Vector2 = step
	if not _moving:
		var f = enemy.get("facing")
		dir_vec = f if f is Vector2 else Vector2.DOWN
	_apply_direction(_dir_from(dir_vec))
	_t = _t + delta if _moving else 0.0
	_sprite.frame = int(_t * fps) % frames

func _dir_from(v: Vector2) -> String:
	if v == Vector2.ZERO:
		return _dir
	if absf(v.x) > absf(v.y):
		return "east" if v.x > 0.0 else "west"
	return "south" if v.y > 0.0 else "north"

func _draw() -> void:
	# soft contact shadow so the painted body sits on the floor
	draw_circle(Vector2(0, -2), 13.0, Color(0, 0, 0, 0.28))
