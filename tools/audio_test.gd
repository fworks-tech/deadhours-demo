extends Node

var blips: int = 0

func _ready() -> void:
	var fails: Array = []
	# assets present and loadable
	for p in ["res://assets/audio/music/chapter1.wav", "res://assets/audio/music/chapter2.wav",
			"res://assets/audio/music/chapter3.wav", "res://assets/audio/ambient/gas_station_hum.wav",
			"res://assets/audio/ambient/wind_loop.wav", "res://assets/audio/ambient/industrial_hum.wav",
			"res://assets/audio/voices/voice_a.wav", "res://assets/audio/voices/voice_d.wav"]:
		var ok: bool = ResourceLoader.exists(p) and load(p) != null
		print(("PASS " if ok else "FAIL ") + "asset " + p.get_file())
		if not ok:
			fails.append(p)

	var m = load("res://scenes/gameplay/TopDownMission.tscn").instantiate()
	m.default_mission_id = "ch2_sneak"
	add_child(m)
	await get_tree().create_timer(0.4, true, false, true).timeout
	print(("PASS " if AudioManager.is_music_playing else "FAIL ") + "music playing")
	if not AudioManager.is_music_playing:
		fails.append("music")
	print(("PASS " if AudioManager.is_ambient_playing("gas_station") else "FAIL ") + "station ambience")
	if not AudioManager.is_ambient_playing("gas_station"):
		fails.append("ambient")

	# fake voices fire while a line types out
	AudioManager.sfx_played.connect(func(_n): blips += 1)
	var garcia = null
	for n in m.npcs:
		if n.npc_id == "garcia":
			garcia = n
	m.open_dialogue("garcia_forecourt", garcia)
	await get_tree().create_timer(0.6, true, false, true).timeout
	print(("PASS " if blips > 0 else "FAIL ") + "voice blips during typing  n=%d" % blips)
	if blips == 0:
		fails.append("blips")

	# narrator stays silent
	var before := blips
	m.npc_dialogue.close()
	m.open_dialogue("marcus_landing", null)
	await get_tree().create_timer(0.5, true, false, true).timeout
	print(("PASS " if blips > before else "FAIL ") + "named npc also voices")
	print("AUDIO RESULT failures=%d" % fails.size())
	get_tree().quit()
