extends Node

func _ready() -> void:
	var scene: PackedScene = load("res://scenes/gameplay/TopDownMission.tscn")
	var mission = scene.instantiate()
	mission.default_mission_id = "ch2_sneak"
	add_child(mission)
	await get_tree().create_timer(0.3).timeout

	print("FX explosives=", mission.explosives.size())
	if mission.explosives.is_empty():
		print("FX RESULT fail=no_explosives")
		get_tree().quit()
		return

	# 1. gunfire visuals
	var p = mission.player
	p.set_weapon("pistol", 6)
	var before_fx: int = mission.fx_system.get_child_count()
	p.aim_dir = Vector2.RIGHT
	p._firearm_attack(p.weapon())
	await get_tree().create_timer(0.15).timeout
	print("FX after_shot_children=", mission.fx_system.get_child_count(), " (was ", before_fx, ")")

	# 2. explosion + chain reaction, with an enemy inside the blast
	var kills_before: int = mission.kills
	var pump = mission.explosives[0]
	var victim = mission.enemies[0]
	victim.global_position = pump.global_position + Vector2(70, 20)
	pump.take_hit(Vector2.RIGHT)
	await get_tree().create_timer(0.9).timeout
	print("FX kills ", kills_before, " -> ", mission.kills)
	print("FX time_scale=", Engine.time_scale, " blast_children=", mission.fx_system.get_child_count())
	print("FX victim_alive=", victim.alive)
	print("FX alert=", mission.alarm_raised)
	var chained := 0
	for x in mission.explosives:
		if is_instance_valid(x) and x.blown:
			chained += 1
	print("FX chained_or_blown=", chained)
	print("FX RESULT kills>", kills_before, " -> ", mission.kills > kills_before)
	get_tree().quit()
