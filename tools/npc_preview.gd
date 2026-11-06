# Renders the NPC conversation UI for design review:
#   godot --path . --resolution 960x540 --write-movie shot.png res://tools/NpcPreview.tscn
extends Node2D

var dialogue: NpcDialogue

func _ready() -> void:
	dialogue = NpcDialogue.new()
	add_child(dialogue)
	# a couple of frames so the viewport is live before the overlay opens
	await get_tree().process_frame
	dialogue.open("garcia_forecourt", null)
	await get_tree().process_frame
	dialogue.advance()   # finish typing
	dialogue.advance()   # move to the choice node
	dialogue.advance()   # finish typing, options appear
	await get_tree().process_frame
	get_tree().paused = false   # keep rendering for the capture

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color("#0a0c0b"))
	for x in range(0, 960, 48):
		draw_line(Vector2(x, 0), Vector2(x, 540), Color(1, 1, 1, 0.02), 1.0)
	for y in range(0, 540, 48):
		draw_line(Vector2(0, y), Vector2(960, y), Color(1, 1, 1, 0.02), 1.0)
