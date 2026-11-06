# SaveSelectScreen.gd
# Displays save slot selection interface: Slot 0 (Auto-Save) and
# Slots 1-3 (Manual Saves). Shows chapter, play time, and timestamp.
# Provides Load and Delete functionality for each slot.
extends Control

@onready var back_button: Button = %BackButton
@onready var slot0_info_label: Label = %Slot0InfoLabel
@onready var slot0_load_btn: Button = %Slot0LoadBtn
@onready var slot0_delete_btn: Button = %Slot0DeleteBtn

@onready var slot1_info_label: Label = %Slot1InfoLabel
@onready var slot1_load_btn: Button = %Slot1LoadBtn
@onready var slot1_delete_btn: Button = %Slot1DeleteBtn

@onready var slot2_info_label: Label = %Slot2InfoLabel
@onready var slot2_load_btn: Button = %Slot2LoadBtn
@onready var slot2_delete_btn: Button = %Slot2DeleteBtn

@onready var slot3_info_label: Label = %Slot3InfoLabel
@onready var slot3_load_btn: Button = %Slot3LoadBtn
@onready var slot3_delete_btn: Button = %Slot3DeleteBtn

func _ready() -> void:
	_connect_signals()
	refresh_slots()

func _connect_signals() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	if slot0_load_btn:
		slot0_load_btn.pressed.connect(func(): _on_load_slot(0))
	if slot0_delete_btn:
		slot0_delete_btn.pressed.connect(func(): _on_delete_slot(0))
	
	if slot1_load_btn:
		slot1_load_btn.pressed.connect(func(): _on_load_slot(1))
	if slot1_delete_btn:
		slot1_delete_btn.pressed.connect(func(): _on_delete_slot(1))
	
	if slot2_load_btn:
		slot2_load_btn.pressed.connect(func(): _on_load_slot(2))
	if slot2_delete_btn:
		slot2_delete_btn.pressed.connect(func(): _on_delete_slot(2))
	
	if slot3_load_btn:
		slot3_load_btn.pressed.connect(func(): _on_load_slot(3))
	if slot3_delete_btn:
		slot3_delete_btn.pressed.connect(func(): _on_delete_slot(3))

func refresh_slots() -> void:
	_update_slot_ui(0, slot0_info_label, slot0_load_btn, slot0_delete_btn, "Auto-Save Slot")
	_update_slot_ui(1, slot1_info_label, slot1_load_btn, slot1_delete_btn, "Save Slot 1")
	_update_slot_ui(2, slot2_info_label, slot2_load_btn, slot2_delete_btn, "Save Slot 2")
	_update_slot_ui(3, slot3_info_label, slot3_load_btn, slot3_delete_btn, "Save Slot 3")

func _update_slot_ui(slot: int, label: Label, load_btn: Button, delete_btn: Button, slot_title: String) -> void:
	if not SaveManager or not label:
		return
	
	if SaveManager.has_save(slot):
		var info := SaveManager.get_save_info(slot)
		var chapter: int = info.get("chapter", 1)
		var play_time: float = info.get("play_time", 0.0)
		var timestamp: float = info.get("timestamp", 0.0)
		
		var formatted_time := SaveManager.format_play_time(play_time)
		var formatted_date := ""
		if timestamp > 0:
			formatted_date = Time.get_datetime_string_from_unix_time(int(timestamp), true)
		
		label.text = "%s\nChapter %d | Time: %s\nSaved: %s" % [slot_title, chapter, formatted_time, formatted_date]
		if load_btn:
			load_btn.disabled = false
		if delete_btn:
			delete_btn.disabled = false
	else:
		label.text = "%s\n[ Empty Slot ]" % slot_title
		if load_btn:
			load_btn.disabled = true
		if delete_btn:
			delete_btn.disabled = true

func _on_load_slot(slot: int) -> void:
	_play_click_sfx()
	if GameManager:
		GameManager.load_game(slot)

func _on_delete_slot(slot: int) -> void:
	_play_click_sfx()
	if SaveManager:
		SaveManager.delete_save(slot)
		refresh_slots()

func _on_back_pressed() -> void:
	_play_click_sfx()
	if SceneManager:
		SceneManager.change_scene("res://scenes/ui/MainMenu.tscn")

func _play_click_sfx() -> void:
	if SettingsManager and SettingsManager.is_haptics_enabled():
		Input.vibrate_handheld(30)
