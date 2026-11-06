# GameManager.gd
# Central game state controller — manages overall game flow, transitions
# between meta-states (splash, menu, playing, cutscene, paused, game_over)
extends Node

signal game_state_changed(new_state: GameManagerState)

enum GameManagerState {
	SPLASH,
	MENU,
	LOADING,
	PLAYING,
	CUTSCENE,
	CHOICE_PENDING,
	PAUSED,
	GAME_OVER,
	EPILOGUE
}

var current_state: GameManagerState = GameManagerState.SPLASH
var current_chapter: int = 0
var current_checkpoint: String = ""
var play_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if current_state == GameManagerState.PLAYING or current_state == GameManagerState.CUTSCENE:
		play_time += delta

func change_state(new_state: GameManagerState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	game_state_changed.emit(new_state)

func get_state_name() -> String:
	return GameManagerState.keys()[current_state]

func pause_game() -> void:
	change_state(GameManagerState.PAUSED)
	get_tree().paused = true

func resume_game() -> void:
	get_tree().paused = false
	change_state(GameManagerState.PLAYING)

func start_new_game() -> void:
	play_time = 0.0
	FlagsManager.reset_all_flags()
	StoryManager.load_story_data()
	
	# Data-driven entry: first checkpoint of the first chapter. Falls back
	# to GameScene if the story data has no entry checkpoint with a scene.
	current_checkpoint = StoryManager.get_entry_checkpoint_id()
	if current_checkpoint.is_empty():
		push_error("No entry checkpoint found in story data — cannot start game")
		return
	StoryManager.enter_checkpoint(current_checkpoint)

func load_game(slot: int = 0) -> void:
	if SaveManager.load_game(slot):
		SceneManager.change_scene("res://scenes/core/GameScene.tscn")

func quit_to_menu() -> void:
	change_state(GameManagerState.MENU)
	SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")
