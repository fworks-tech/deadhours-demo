# FlagsManager.gd
# The flag system — tracks story state variables that determine branching.
# Flags can be booleans, integers, or strings. They gate choices, alter
# dialogue, unlock/lock paths, and determine which ending you reach.
#
# Flag operations (used in story.json "effects" and "on_enter"):
#   { "set": { "met_npc_alice": true, "trust_level": 5 } }
#   { "add": { "trust_level": 1 } }        # increment integer flags
#   { "sub": { "trust_level": 2 } }        # decrement integer flags
#   { "toggle": ["has_flashlight"] }       # flip boolean flags
#   { "clear": ["temporary_flag"] }        # reset to default
extends Node

signal flag_changed(flag_name: String, old_value: Variant, new_value: Variant)

var _flags: Dictionary = {}
var _default_flags: Dictionary = {}

func _ready() -> void:
	_initialize_defaults()

func _initialize_defaults() -> void:
	_default_flags = {
		# === Dead Hours — Zombie Game Flags ===
		
		# Character relationships (trust levels)
		"trust_elena": 0,
		"trust_danny": 0,
		"trust_garcia": 0,
		"trust_priya": 0,
		"trust_riverside": 0,
		
		# Characters met / in party
		"met_elena": false,
		"met_danny": false,
		"met_garcia": false,
		"met_priya": false,
		"met_marcus": false,
		
		"elena_in_party": false,
		"danny_in_party": false,
		"joined_group": false,
		"travels_solo": false,
		
		# Chapter 1 flags
		"chapter1_started": false,
		"chapter1_complete": false,
		"let_stranger_in": false,
		"ignored_stranger": false,
		"checked_peephole": false,
		"watched_elena_die": false,
		"alone_chapter1": false,
		"heroic_moment": false,
		"brave_moment": false,
		"used_fire_escape": false,
		"took_stairs": false,
		"barricaded": false,
		"barricaded_chapter1": false,
		"fire_escape_used": false,
		"opened_for_infected": false,
		"smart_check": false,
		"ignored_marcus": false,
		"marcus_dead": false,
		"marcus_infected": false,
		"player_bitten_ch1": false,
		"has_vehicle": false,
		"left_danny_behind": false,
		"danny_bitten": false,
		"danny_tourniquet": false,
		
		# Chapter 2 flags
		"chapter2_started": false,
		"chapter2_complete": false,
		"inside_gas_station": false,
		"attempted_sneak": false,
		"lied_about_bite": false,
		"made_enemies": false,
		"garcia_hostile": false,
		"shared_marcus_story": false,
		
		# Chapter 3 flags
		"chapter3_started": false,
		"honest_at_riverside": false,
		"cleared_riverside": false,
		"refused_screening": false,
		"abandoned_riverside": false,
		"helped_riverside": false,
		"sneaked_into_riverside": false,
		"player_bitten_ch3": false,
		"danny_treated": false,
		"danny_comfort_care": false,
		"stayed_with_danny": false,
		"danny_survived": false,
		"danny_dead": false,
		"found_cure": false,
		"knows_sofia": false,
		"held_the_gate": false,
		"chose_evacuation": false,
		"sacrificed_self": false,
		"betrayed_riverside": false,
		"released_cure": false,
		
		# Inventory / supplies
		"supplies": 3,
		"has_flashlight": false,
		"has_key": false,
		"has_weapon": false,
		
		# Moral / meta tracking
		"secrets_discovered": 0,
		"corruption_level": 0,
		
		# Endings unlocked (persist across playthroughs)
		"endings_seen": [],
	}
	reset_all_flags()

func reset_all_flags() -> void:
	var endings: Array = _flags.get("endings_seen", [])
	_flags = _default_flags.duplicate(true)
	_flags["endings_seen"] = endings

func get_flag(flag_name: String) -> Variant:
	# If flag doesn't exist, return false for bools, 0 for ints
	if not _flags.has(flag_name):
		return null
	return _flags[flag_name]

func set_flag(flag_name: String, value: Variant) -> void:
	var old: Variant = _flags.get(flag_name, null)
	_flags[flag_name] = value
	flag_changed.emit(flag_name, old, value)

func toggle_flag(flag_name: String) -> void:
	var current: bool = bool(_flags.get(flag_name, false))
	set_flag(flag_name, not current)

func add_to_flag(flag_name: String, amount: int) -> void:
	var current: int = int(_flags.get(flag_name, 0))
	set_flag(flag_name, current + amount)

func sub_from_flag(flag_name: String, amount: int) -> void:
	add_to_flag(flag_name, -amount)

func clear_flag(flag_name: String) -> void:
	set_flag(flag_name, _default_flags.get(flag_name, null))

func process_flag_operations(operations: Array) -> void:
	for op in operations:
		if op.has("set"):
			for flag_name in op["set"]:
				set_flag(flag_name, op["set"][flag_name])
		elif op.has("add"):
			for flag_name in op["add"]:
				add_to_flag(flag_name, int(op["add"][flag_name]))
		elif op.has("sub"):
			for flag_name in op["sub"]:
				sub_from_flag(flag_name, int(op["sub"][flag_name]))
		elif op.has("toggle"):
			for flag_name in op["toggle"]:
				toggle_flag(flag_name)
		elif op.has("clear"):
			for flag_name in op["clear"]:
				clear_flag(flag_name)

func check_condition(flag_name: String, expected_value: Variant, operator: String = "==") -> bool:
	var actual: Variant = get_flag(flag_name)
	match operator:
		"==": return actual == expected_value
		"!=": return actual != expected_value
		">": return int(actual) > int(expected_value)
		"<": return int(actual) < int(expected_value)
		">=": return int(actual) >= int(expected_value)
		"<=": return int(actual) <= int(expected_value)
		"in": return expected_value in actual if actual is Array else false
		_: return actual == expected_value

func unlock_ending(ending_id: String) -> void:
	var endings: Array = _flags.get("endings_seen", [])
	if ending_id not in endings:
		endings.append(ending_id)
		_flags["endings_seen"] = endings

func get_unlocked_endings() -> Array:
	return _flags.get("endings_seen", [])

func get_all_flags() -> Dictionary:
	return _flags.duplicate(true)

func load_flags(data: Dictionary) -> void:
	_flags = data.duplicate(true)

func has_flag(flag_name: String) -> bool:
	return _flags.has(flag_name)

# Evaluate a requires block — supports both simple equality and operator objects
# Simple: { "has_key": true, "met_alice": true }
# Operator: { "trust_alice": { ">=": 2 } }
func evaluate_requirements(requirements: Dictionary) -> bool:
	for flag_name in requirements:
		var condition = requirements[flag_name]
		var actual = get_flag(flag_name)
		
		if condition is Dictionary:
			# Operator format: { "trust_alice": { ">=": 2 } }
			for op in condition:
				var expected = condition[op]
				if not check_condition(flag_name, expected, op):
					return false
		else:
			# Simple equality: { "has_key": true }
			if actual != condition:
				return false
	return true
