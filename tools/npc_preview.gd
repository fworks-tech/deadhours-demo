# Renders the conversation overlay over live gameplay (what the player sees):
#   TD_AUTOSTART=1 godot --path . --resolution 960x540 --write-movie shot.png res://tools/NpcPreview.tscn
extends Node2D

var mission: Node
var dialogue: NpcDialogue

func _ready() -> void:
	mission = load("res://scenes/gameplay/TopDownMission.tscn").instantiate()
	mission.default_mission_id = "ch2_sneak"
	add_child(mission)
	await get_tree().create_timer(0.5, true, false, true).timeout

	var garcia: Node = null
	for n in mission.npcs:
		if n.npc_id == "garcia":
			garcia = n
	if garcia == null:
		push_warning("preview: no garcia")
		return
	mission.open_dialogue("garcia_forecourt", garcia)
	dialogue = mission.npc_dialogue
	await get_tree().process_frame
	dialogue.advance()   # finish typing line 1
	dialogue.advance()   # move to the choice node
	dialogue.advance()   # finish typing, options appear
	# keep rendering for the capture (audio + world stay live)
	get_tree().paused = false
