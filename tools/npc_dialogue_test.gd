extends Node

var fails: Array = []

func check(label: String, ok: bool, detail: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + label + ("  " + detail if detail != "" else ""))
	if not ok:
		fails.append(label)

func load_mission(id: String):
	var m = load("res://scenes/gameplay/TopDownMission.tscn").instantiate()
	m.default_mission_id = id
	add_child(m)
	await get_tree().create_timer(0.35, true, false, true).timeout
	return m

func _ready() -> void:
	FlagsManager.reset_all_flags()

	# ---------------- Marcus: fire escape landing
	var m1 = await load_mission("ch1_fireescape")
	check("marcus placed", m1.npcs.size() == 1, "npcs=%d" % m1.npcs.size())
	var marcus = m1.npcs[0]
	check("marcus conversation bound", marcus.conversation == "marcus_landing", marcus.conversation)
	m1.try_interact(marcus.global_position)  # no target yet, must be a no-op
	m1.open_dialogue(marcus.conversation, marcus)
	check("dialogue_open", m1.dialogue_open)
	check("tree paused", get_tree().paused)
	check("player locked", not m1.player.can_act)
	var d = m1.npc_dialogue
	d.advance(); d.advance()                # finish typing n1 -> n2 (flashlight)
	check("flag has_flashlight", FlagsManager.get_flag("has_flashlight") == true)
	d.advance(); d.advance(); d.advance()   # type n2, go n3, finish typing -> choices
	check("choices shown", d._choice_nodes.size() == 3, "n=%d" % d._choice_nodes.size())
	d.choose(0)                              # ask about the night
	check("flag shared_marcus_story", FlagsManager.get_flag("shared_marcus_story") == true)
	for i in range(8):
		if not m1.dialogue_open:
			break
		d.advance()
	check("dialogue closed", not m1.dialogue_open)
	check("tree resumed", not get_tree().paused)
	check("player unlocked", m1.player.can_act)
	m1.queue_free()
	await get_tree().create_timer(0.2, true, false, true).timeout

	# ---------------- Garcia: hostile branch + weapon reward on the honest branch
	var m2 = await load_mission("ch2_sneak")
	check("two npcs at the station", m2.npcs.size() == 2, "npcs=%d" % m2.npcs.size())
	var garcia = null
	for n in m2.npcs:
		if n.npc_id == "garcia":
			garcia = n
	check("garcia present", garcia != null)
	m2.open_dialogue(garcia.conversation, garcia)
	var d2 = m2.npc_dialogue
	check("flag met_garcia", FlagsManager.get_flag("met_garcia") == true)
	d2.advance(); d2.advance(); d2.advance()
	check("garcia choices", d2._choice_nodes.size() == 3, "n=%d" % d2._choice_nodes.size())
	d2.choose(2)  # raise weapon first
	check("flag garcia_hostile", FlagsManager.get_flag("garcia_hostile") == true)
	check("flag made_enemies", FlagsManager.get_flag("made_enemies") == true)
	check("npc removed after turning", m2.npcs.size() == 1, "npcs=%d" % m2.npcs.size())
	check("dialogue ended", not m2.dialogue_open)
	m2.queue_free()
	await get_tree().create_timer(0.2, true, false, true).timeout

	# ---------------- Priya: honest path hands over the shotgun
	var m3 = await load_mission("ch2_sneak")
	var priya = null
	for n in m3.npcs:
		if n.npc_id == "priya":
			priya = n
	m3.open_dialogue("garcia_forecourt", m3.npcs[0])
	var d3 = m3.npc_dialogue
	d3.advance(); d3.advance(); d3.advance()
	d3.choose(0)  # honest about the bite
	check("flag inside_gas_station", FlagsManager.get_flag("inside_gas_station") == true)
	check("flag danny_bitten", FlagsManager.get_flag("danny_bitten") == true)
	check("shotgun awarded", m3.player.weapon_id == "shotgun", m3.player.weapon_id)
	check("ammo awarded", m3.player.ammo >= 4, str(m3.player.ammo))
	d3.close()
	check("dialogue closed (garcia path)", not m3.dialogue_open)
	check("priya still there", m3.npcs.size() == 2, "npcs=%d" % m3.npcs.size())
	m3.queue_free()

	print("NPC RESULT failures=%d" % fails.size())
	get_tree().quit()
