# Renders a contact board of every combat effect, for design review and for
# catching regressions visually. Run with a real renderer:
#   godot --path . --resolution 960x540 --write-movie shot.png res://tools/FxPreview.tscn
extends Node2D

var fx: TopDownFX

func _ready() -> void:
	fx = TopDownFX.new()
	add_child(fx)

	# corpses and pools
	fx.blood_pool(Vector2(120, 400), 34)
	fx.blood_smear(Vector2(60, 470), Vector2(210, 500), 18)
	fx.corpse_fx(Vector2(300, 420), Vector2.RIGHT)

	# explosion in progress
	fx.explosion(Vector2(700, 260), 150)
	fx.ambient_fire(Vector2(880, 400), 1.6)

	# gunfire, slightly later so the flash is caught mid-frame
	await get_tree().create_timer(0.18).timeout
	fx.muzzle_flash(Vector2(560, 120), Vector2.RIGHT, 1.4)
	fx.tracer(Vector2(560, 120), Vector2(900, 140), Color("#ffd9a0"), 2.4)
	fx.casing(Vector2(570, 124), Vector2.RIGHT)
	fx.impact(Vector2(900, 140), Vector2.LEFT)
	fx.impact(Vector2(430, 200), Vector2.DOWN, "glass")

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color("#0b0d0f"))
	# floor grid so scale reads
	for x in range(0, 960, 48):
		draw_line(Vector2(x, 0), Vector2(x, 540), Color(1, 1, 1, 0.02), 1.0)
	for y in range(0, 540, 48):
		draw_line(Vector2(0, y), Vector2(960, y), Color(1, 1, 1, 0.02), 1.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(40, 60), "DEAD HOURS — combat effects", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#e6e1d5"))
	draw_string(font, Vector2(40, 84), "muzzle flash / tracer / impact / glass / blood / corpse / explosion / fire", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.6, 0.62, 0.6))
