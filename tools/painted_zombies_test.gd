extends Node

func _ready() -> void:
	var fails: Array = []
	for lv in ["ch1_fireescape", "ch1_stairwell", "ch2_sneak"]:
		var m = load("res://scenes/gameplay/TopDownMission.tscn").instantiate()
		m.default_mission_id = lv
		add_child(m)
		await get_tree().create_timer(0.3, true, false, true).timeout
		var with_sprite := 0
		var chars := {}
		for e in m.enemies:
			if is_instance_valid(e) and e.painted_sprite != null:
				var sp = e.painted_sprite
				if sp._sprite != null and sp._sprite.texture != null:
					with_sprite += 1
					chars[sp.character] = true
		var ok: bool = with_sprite == m.enemies.size() and with_sprite > 0
		print(("PASS " if ok else "FAIL ") + "%s painted=%d/%d chars=%s" % [lv, with_sprite, m.enemies.size(), str(chars.keys())])
		if not ok:
			fails.append(lv)
		m.queue_free()
		await get_tree().create_timer(0.2, true, false, true).timeout
	print("PAINTED RESULT failures=%d" % fails.size())
	get_tree().quit()
