# topdown_smoke_test.gd
# Headless QA harness for the top-down mission layer. Builds a level, fires a
# melee and a ranged attack, kills an enemy and walks into the exit zone, then
# reports the mission counters. Run with:
#   godot --headless --path . res://tools/TopDownSmokeTest.tscn
extends Node

func _ready() -> void:
	await get_tree().process_frame
	var packed: PackedScene = load("res://scenes/gameplay/TopDownMission.tscn")
	var mission = packed.instantiate()
	mission.debug_skip_briefing = true
	add_child(mission)
	await get_tree().process_frame
	await get_tree().process_frame

	var p = mission.player
	print("SMOKE: enemies=", mission.enemies.size(), " start_weapon=", p.weapon_id, " alive=", p.alive)

	# melee kill
	var e = mission.enemies[0]
	p.global_position = e.global_position + Vector2(-34, 0)
	p.aim_dir = Vector2.RIGHT
	p._attack_cd = 0.0
	p._attack()
	await get_tree().process_frame
	print("SMOKE: after melee kills=", mission.kills, " enemy_alive=", e.alive)

	# firearm kill
	var e2 = mission.enemies[8]
	p.global_position = e2.global_position + Vector2(-150, 0)
	p.set_weapon("pistol", 7)
	p.aim_dir = Vector2.RIGHT
	p._attack_cd = 0.0
	p._attack()
	await get_tree().process_frame
	print("SMOKE: after shot kills=", mission.kills, " ammo=", p.ammo, " enemy_alive=", e2.alive)

	# noise + alarm path
	mission.emit_noise(p.global_position, 900.0, p)
	print("SMOKE: alarm=", mission.alarm_raised)

	# exit
	p.global_position = mission.exit_zone.global_position
	await get_tree().create_timer(0.2).timeout
	print("SMOKE: complete=", mission.mission_complete, " kills=", mission.kills, " time=", mission._elapsed)
	get_tree().quit()
