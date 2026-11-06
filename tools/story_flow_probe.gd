# Story flow probe (QA): enters a mission checkpoint through the real story
# engine, verifies the mission scene loads with the right mission_id, completes
# it and checks the post-mission fallback back into the story container.
extends Node

func _ready() -> void:
	await get_tree().create_timer(2.6).timeout
	StoryManager.enter_checkpoint("ch1_fireescape")
	await get_tree().create_timer(1.6).timeout
	var s: Node = get_tree().current_scene
	print("PROBE loaded_scene=", s.name, " mission_id=", s.get("mission_id"), " enemies=", (s.get("enemies") as Array).size() if s.get("enemies") != null else -1)
	if s.has_method("complete_mission"):
		s.kills = 4
		s.complete_mission()
		s._finish_mission()
	await get_tree().create_timer(2.2).timeout
	var s2: Node = get_tree().current_scene
	print("PROBE after_scene=", s2.name, " checkpoint=", StoryManager.current_checkpoint_id, " flags=", FlagsManager.get_flag("fire_escape_used"), " kills=", FlagsManager.get_flag("ch1_fireescape_kills"))
	get_tree().quit()
