# AudioManager.gd
# Centralized audio framework for 'Dead Hours' — music crossfading, per-chapter
# track management, ambient loop layering, voice line playback with subtitle
# sync signals, SFX pooling, and bus volume management.
extends Node

signal music_changed(track_name: String)
signal sfx_played(sfx_name: String)
signal voice_started(stream: AudioStream, subtitle: String)
signal subtitle_synced(subtitle: String)
signal ambient_started(key: String)
signal ambient_stopped(key: String)

const CROSSFADE_TIME := 2.0  # 2-second crossfade transition
const SFX_POOL_SIZE := 8

# Music players for crossfading
var _music_player: AudioStreamPlayer = null
var _music_player_next: AudioStreamPlayer = null
var _music_fading: bool = false

# Ambient players map (key -> AudioStreamPlayer)
var _ambient_players: Dictionary = {}

# Voice player
var _voice_player: AudioStreamPlayer = null

# SFX pool
var _sfx_pool: Array[AudioStreamPlayer] = []

# Volume settings (dB)
var _master_volume: float = 0.0
var _music_volume: float = 0.0
var _ambient_volume: float = 0.0
var _sfx_volume: float = 0.0
var _voice_volume: float = 0.0

# State tracking
var current_chapter: int = 0
var current_track: String = ""
var is_music_playing: bool = false

# Standard Chapter Music File Map
const CHAPTER_MUSIC_MAP := {
	1: "res://assets/audio/music/chapter1.wav",
	2: "res://assets/audio/music/chapter2.wav",
	3: "res://assets/audio/music/chapter3.wav"
}

# Standard Ambient Track File Map
const AMBIENT_TRACK_MAP := {
	"rain": "res://assets/audio/ambient/rain_loop.wav",
	"wind": "res://assets/audio/ambient/wind_loop.wav",
	"drone": "res://assets/audio/ambient/cold_drone_loop.wav",
	"gas_station": "res://assets/audio/ambient/gas_station_hum.wav",
	"industrial": "res://assets/audio/ambient/industrial_hum.wav"
}

func _ready() -> void:
	# music, ambience and voices must survive a paused tree (menus, dialogue)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_players()
	_load_initial_volumes()
	_connect_story_manager()

func _setup_audio_players() -> void:
	# Main music players for crossfading
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	
	_music_player_next = AudioStreamPlayer.new()
	_music_player_next.bus = "Music"
	add_child(_music_player_next)
	
	# Voice player
	_voice_player = AudioStreamPlayer.new()
	_voice_player.bus = "Voice"
	add_child(_voice_player)
	
	# SFX pool
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

func _load_initial_volumes() -> void:
	if SettingsManager:
		_master_volume = SettingsManager.get_setting("master_volume", 0.0)
		_music_volume = SettingsManager.get_setting("music_volume", 0.0)
		_ambient_volume = SettingsManager.get_setting("ambient_volume", 0.0)
		_sfx_volume = SettingsManager.get_setting("sfx_volume", 0.0)
		_voice_volume = SettingsManager.get_setting("voice_volume", 0.0)
	
	_apply_volumes()

func _connect_story_manager() -> void:
	if StoryManager and StoryManager.has_signal("chapter_changed"):
		if not StoryManager.chapter_changed.is_connected(_on_story_chapter_changed):
			StoryManager.chapter_changed.connect(_on_story_chapter_changed)

func _on_story_chapter_changed(chapter: int) -> void:
	play_chapter_music(chapter)

# --- Chapter & Music Methods ---

func play_chapter_music(chapter_id: Variant) -> void:
	var ch_num: int = int(chapter_id) if (chapter_id is int or (chapter_id is String and chapter_id.is_valid_int())) else 1
	current_chapter = ch_num
	
	var track_path: String = CHAPTER_MUSIC_MAP.get(ch_num, "res://assets/audio/music/chapter%d.wav" % ch_num)
	var track_name: String = track_path.get_file().get_basename()
	
	if ResourceLoader.exists(track_path):
		var stream := load(track_path) as AudioStream
		if stream:
			play_music(stream, true)
			current_track = track_name
			return
	
	# Fallback if audio file is not present yet
	current_track = track_name
	is_music_playing = false
	music_changed.emit(track_name)
	push_warning("AudioManager: Chapter %d music file not found at %s (placeholder tracked)." % [ch_num, track_path])

func play_music(stream: AudioStream, fade: bool = true) -> void:
	if stream == null:
		return
	
	var track_name: String = stream.resource_path.get_file().get_basename() if stream.resource_path else "music_track"
	
	if _music_player.stream == stream and _music_player.playing:
		current_track = track_name
		is_music_playing = true
		return
	
	if fade and _music_player.playing:
		_crossfade_music(stream, CROSSFADE_TIME)
	else:
		_music_player.stream = stream
		_music_player.volume_db = _music_volume
		_music_player.play()
		is_music_playing = true
		current_track = track_name
		music_changed.emit(track_name)

func _crossfade_music(new_stream: AudioStream, duration: float = CROSSFADE_TIME) -> void:
	if _music_fading:
		return
	_music_fading = true
	
	var track_name: String = new_stream.resource_path.get_file().get_basename() if new_stream.resource_path else "music_track"
	
	# Move current active stream to next player for fade-out
	_music_player_next.stream = _music_player.stream
	_music_player_next.volume_db = _music_volume
	_music_player_next.play(_music_player.get_playback_position())
	
	# Start new track on primary player
	_music_player.stream = new_stream
	_music_player.volume_db = -80.0
	_music_player.play()
	
	is_music_playing = true
	current_track = track_name
	music_changed.emit(track_name)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_music_player, "volume_db", _music_volume, duration)
	tween.tween_property(_music_player_next, "volume_db", -80.0, duration)
	tween.chain().tween_callback(func():
		_music_player_next.stop()
		_music_fading = false
	)

func stop_music(fade: bool = true) -> void:
	if fade and _music_player.playing:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, CROSSFADE_TIME)
		tween.tween_callback(func():
			_music_player.stop()
			is_music_playing = false
		)
	else:
		_music_player.stop()
		is_music_playing = false

# --- Ambient Loops Methods ---

func play_ambient(key: String, fade_time: float = 1.0) -> void:
	if key.is_empty():
		return
	
	# Check if already playing
	if _ambient_players.has(key) and _ambient_players[key].playing:
		return
	
	var track_path: String = AMBIENT_TRACK_MAP.get(key, "res://assets/audio/ambient/%s.wav" % key)
	
	var player: AudioStreamPlayer = _ambient_players.get(key, null)
	if player == null:
		player = AudioStreamPlayer.new()
		player.bus = "Ambient"
		add_child(player)
		_ambient_players[key] = player
	
	if ResourceLoader.exists(track_path):
		var stream := load(track_path) as AudioStream
		player.stream = stream
		player.volume_db = -80.0
		player.play()
		
		var tween := create_tween()
		tween.tween_property(player, "volume_db", _ambient_volume, fade_time)
		ambient_started.emit(key)
	else:
		ambient_started.emit(key)
		push_warning("AudioManager: Ambient file not found for key '%s' at %s." % [key, track_path])

func stop_ambient(key: String, fade_time: float = 1.0) -> void:
	if key == "all":
		for k in _ambient_players.keys():
			stop_ambient(k, fade_time)
		return
	
	if not _ambient_players.has(key):
		return
	
	var player: AudioStreamPlayer = _ambient_players[key]
	if player.playing:
		var tween := create_tween()
		tween.tween_property(player, "volume_db", -80.0, fade_time)
		tween.tween_callback(func():
			player.stop()
			ambient_stopped.emit(key)
		)
	else:
		ambient_stopped.emit(key)

func is_ambient_playing(key: String) -> bool:
	return _ambient_players.has(key) and _ambient_players[key].playing

# --- Voice & Subtitles ---

func play_voice(stream: AudioStream, subtitle_text: String = "") -> void:
	if stream == null:
		return
	
	_voice_player.stream = stream
	_voice_player.volume_db = _voice_volume
	_voice_player.play()
	
	voice_started.emit(stream, subtitle_text)
	if not subtitle_text.is_empty():
		subtitle_synced.emit(subtitle_text)

func stop_voice() -> void:
	if _voice_player.playing:
		_voice_player.stop()

# --- Sound Effects ---

func play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null:
		return
	
	var sfx_name: String = stream.resource_path.get_file().get_basename() if stream.resource_path else "sfx"
	
	# Find free player in pool
	for player in _sfx_pool:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = pitch
			player.volume_db = _sfx_volume
			player.play()
			sfx_played.emit(sfx_name)
			return
	
	# Re-use oldest if pool full
	var player := _sfx_pool[0]
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = _sfx_volume
	player.play()
	sfx_played.emit(sfx_name)

# --- Volume & Bus Controls ---

func set_master_volume(volume_db: float) -> void:
	_master_volume = volume_db
	_set_bus_volume("Master", volume_db)
	if SettingsManager:
		SettingsManager.set_setting("master_volume", volume_db)

func set_music_volume(volume_db: float) -> void:
	_music_volume = volume_db
	_music_player.volume_db = volume_db
	_set_bus_volume("Music", volume_db)
	if SettingsManager:
		SettingsManager.set_setting("music_volume", volume_db)

func set_ambient_volume(volume_db: float) -> void:
	_ambient_volume = volume_db
	for player in _ambient_players.values():
		player.volume_db = volume_db
	_set_bus_volume("Ambient", volume_db)
	if SettingsManager:
		SettingsManager.set_setting("ambient_volume", volume_db)

func set_sfx_volume(volume_db: float) -> void:
	_sfx_volume = volume_db
	for player in _sfx_pool:
		player.volume_db = volume_db
	_set_bus_volume("SFX", volume_db)
	if SettingsManager:
		SettingsManager.set_setting("sfx_volume", volume_db)

func set_voice_volume(volume_db: float) -> void:
	_voice_volume = volume_db
	_voice_player.volume_db = volume_db
	_set_bus_volume("Voice", volume_db)
	if SettingsManager:
		SettingsManager.set_setting("voice_volume", volume_db)

func _set_bus_volume(bus_name: String, volume_db: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, volume_db)

func _apply_volumes() -> void:
	set_master_volume(_master_volume)
	set_music_volume(_music_volume)
	set_ambient_volume(_ambient_volume)
	set_sfx_volume(_sfx_volume)
	set_voice_volume(_voice_volume)

func pause_all() -> void:
	_music_player.stream_paused = true
	_voice_player.stream_paused = true
	for player in _ambient_players.values():
		player.stream_paused = true
	for player in _sfx_pool:
		player.stream_paused = true

func resume_all() -> void:
	_music_player.stream_paused = false
	_voice_player.stream_paused = false
	for player in _ambient_players.values():
		player.stream_paused = false
	for player in _sfx_pool:
		player.stream_paused = false

# --- State Getters ---

func get_current_chapter() -> int:
	return current_chapter

func get_current_track() -> String:
	return current_track

func get_music_state() -> Dictionary:
	return {
		"current_chapter": current_chapter,
		"current_track": current_track,
		"is_playing": is_music_playing,
		"active_ambients": get_active_ambient_loops()
	}

func get_active_ambient_loops() -> Array[String]:
	var active: Array[String] = []
	for key in _ambient_players.keys():
		if _ambient_players[key].playing:
			active.append(key)
	return active
