# StoryValidator.gd
# Editor tool script for Godot 4.x that validates story.json content integrity.
#
# Runs in the Godot Editor (Script Editor -> File -> Run) or programmatically.
# Performs comprehensive structural validation:
#   - Duplicate checkpoint ID detection
#   - Missing 'next' references
#   - Choices missing 'next' references
#   - Endings missing 'end_type' specifications
#   - Missing scene files on disk (FileAccess check)
#   - Orphan checkpoints unreachable from story entry points
@tool
extends EditorScript

const STORY_DATA_PATH := "res://assets/data/story.json"

func _run() -> void:
	validate_story()

static func validate_story() -> Dictionary:
	print("\n==================================================")
	print("   STORY VALIDATOR — Validating story.json")
	print("==================================================")
	
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var stats: Dictionary = {
		"total_chapters": 0,
		"total_checkpoints": 0,
		"total_choices": 0,
		"total_endings": 0,
		"orphan_count": 0
	}
	
	if not FileAccess.file_exists(STORY_DATA_PATH):
		var err_msg := "CRITICAL: Story file not found at path: " + STORY_DATA_PATH
		push_error(err_msg)
		errors.append(err_msg)
		return {"errors": errors, "warnings": warnings, "stats": stats}
	
	var file := FileAccess.open(STORY_DATA_PATH, FileAccess.READ)
	if file == null:
		var err_msg := "CRITICAL: Failed to open file at path: " + STORY_DATA_PATH
		push_error(err_msg)
		errors.append(err_msg)
		return {"errors": errors, "warnings": warnings, "stats": stats}
	
	var json := JSON.new()
	var parse_err := json.parse(file.get_as_text())
	file.close()
	
	if parse_err != OK:
		var err_msg := "CRITICAL: Story JSON parse error: " + json.get_error_message() + " at line " + str(json.get_error_line())
		push_error(err_msg)
		errors.append(err_msg)
		return {"errors": errors, "warnings": warnings, "stats": stats}
	
	var data: Dictionary = json.data
	if not data.has("chapters") or not (data["chapters"] is Dictionary):
		var err_msg := "CRITICAL: Root JSON object missing 'chapters' dictionary"
		push_error(err_msg)
		errors.append(err_msg)
		return {"errors": errors, "warnings": warnings, "stats": stats}
	
	var chapters: Dictionary = data["chapters"]
	stats["total_chapters"] = chapters.size()
	
	var all_checkpoints: Dictionary = {}        # cp_id -> cp_dict
	var checkpoint_chapters: Dictionary = {}    # cp_id -> chapter_key
	var duplicate_ids: Array[String] = []
	var entry_points: Array[String] = []
	
	# Pass 1: Gather all checkpoints and check for duplicate IDs
	for chapter_key in chapters:
		var chapter_data = chapters[chapter_key]
		if not (chapter_data is Dictionary):
			warnings.append("Chapter entry '" + str(chapter_key) + "' is not a valid dictionary.")
			continue
		
		var checkpoints = chapter_data.get("checkpoints", {})
		if not (checkpoints is Dictionary):
			warnings.append("Chapter '" + str(chapter_key) + "' has invalid 'checkpoints' dictionary.")
			continue
		
		var is_first_in_chapter := true
		for cp_id_raw in checkpoints:
			var cp_id := str(cp_id_raw)
			var cp = checkpoints[cp_id_raw]
			if not (cp is Dictionary):
				warnings.append("Checkpoint '" + cp_id + "' in Chapter " + str(chapter_key) + " is not an object.")
				continue
			
			if all_checkpoints.has(cp_id):
				duplicate_ids.append(cp_id)
				var duplicate_msg := "Duplicate Checkpoint ID detected: '" + cp_id + "' (found in Chapter " + str(chapter_key) + ")"
				errors.append(duplicate_msg)
			else:
				all_checkpoints[cp_id] = cp
				checkpoint_chapters[cp_id] = str(chapter_key)
			
			if is_first_in_chapter:
				entry_points.append(cp_id)
				is_first_in_chapter = false
	
	stats["total_checkpoints"] = all_checkpoints.size()
	
	# Pass 2: Check scenes, next references, endings, choices
	for cp_id in all_checkpoints:
		var cp: Dictionary = all_checkpoints[cp_id]
		var cp_type: String = cp.get("type", "cutscene")
		
		# Check scene file existence
		if cp.has("scene"):
			var scene_path: String = str(cp.get("scene", ""))
			if not scene_path.is_empty():
				if not FileAccess.file_exists(scene_path):
					var missing_scene_msg: String = "Checkpoint '" + cp_id + "': Missing scene file on disk -> '" + scene_path + "'"
					errors.append(missing_scene_msg)
			else:
				warnings.append("Checkpoint '" + cp_id + "': Empty scene path specified.")
		
		# Check 'next' reference
		if cp.has("next"):
			var next_id: String = str(cp.get("next", ""))
			if not next_id.is_empty():
				if not all_checkpoints.has(next_id):
					var missing_next_msg: String = "Checkpoint '" + cp_id + "': Points to non-existent next checkpoint -> '" + next_id + "'"
					errors.append(missing_next_msg)
			else:
				if cp_type != "end":
					warnings.append("Checkpoint '" + cp_id + "': Has empty 'next' reference field.")
		
		# Check 'end' checkpoint type
		if cp_type == "end":
			stats["total_endings"] = int(stats["total_endings"]) + 1
			var end_type: String = str(cp.get("end_type", ""))
			if end_type.is_empty():
				var missing_end_type_msg: String = "Ending Checkpoint '" + cp_id + "': Missing or empty 'end_type' field (must be good/bad/neutral/etc.)"
				errors.append(missing_end_type_msg)
		
		# Check choices array
		if cp.has("choices") or cp_type == "choice":
			var choices = cp.get("choices", [])
			if not (choices is Array) or choices.is_empty():
				if cp_type == "choice":
					var no_choices_msg: String = "Choice Checkpoint '" + cp_id + "': Declared as type 'choice' but contains no choices array!"
					errors.append(no_choices_msg)
			else:
				for i in range(choices.size()):
					var choice = choices[i]
					if not (choice is Dictionary):
						errors.append("Checkpoint '" + cp_id + "': Choice at index " + str(i) + " is not an object.")
						continue
					
					stats["total_choices"] = int(stats["total_choices"]) + 1
					var choice_id: String = str(choice.get("id", "choice_" + str(i)))
					var choice_next: String = str(choice.get("next", ""))
					
					if choice_next.is_empty():
						var no_choice_next_msg: String = "Checkpoint '" + cp_id + "' choice '" + choice_id + "': Has no 'next' checkpoint defined!"
						errors.append(no_choice_next_msg)
					elif not all_checkpoints.has(choice_next):
						var missing_choice_next_msg: String = "Checkpoint '" + cp_id + "' choice '" + choice_id + "': Points to missing next checkpoint -> '" + choice_next + "'"
						errors.append(missing_choice_next_msg)
	
	# Pass 3: Reachability / Orphan Checkpoints Analysis
	var visited: Dictionary = {}
	var queue: Array[String] = []
	for ep in entry_points:
		if not visited.has(ep):
			visited[ep] = true
			queue.append(ep)
	
	while not queue.is_empty():
		var curr_id: String = queue.pop_front()
		var cp: Dictionary = all_checkpoints.get(curr_id, {})
		
		# Traverse direct 'next' link
		if cp.has("next"):
			var next_id: String = str(cp.get("next", ""))
			if not next_id.is_empty() and all_checkpoints.has(next_id) and not visited.has(next_id):
				visited[next_id] = true
				queue.append(next_id)
		
		# Traverse choice 'next' links
		if cp.has("choices") and cp["choices"] is Array:
			for choice in cp["choices"]:
				if choice is Dictionary:
					var c_next: String = str(choice.get("next", ""))
					if not c_next.is_empty() and all_checkpoints.has(c_next) and not visited.has(c_next):
						visited[c_next] = true
						queue.append(c_next)
	
	var orphans: Array[String] = []
	for cp_id in all_checkpoints:
		if not visited.has(cp_id):
			orphans.append(cp_id)
			warnings.append("Orphan Checkpoint detected (unreachable from story start): '" + cp_id + "'")
	
	stats["orphan_count"] = orphans.size()
	
	# Output validation report
	print("\n---------------- VALIDATION RESULTS ----------------")
	print("Chapters Analyzed:   ", stats["total_chapters"])
	print("Checkpoints Found:   ", stats["total_checkpoints"])
	print("Choices Validated:   ", stats["total_choices"])
	print("Endings Discovered:  ", stats["total_endings"])
	print("Orphan Checkpoints:  ", stats["orphan_count"])
	print("Total Errors:        ", errors.size())
	print("Total Warnings:      ", warnings.size())
	print("----------------------------------------------------\n")
	
	if not warnings.is_empty():
		print("⚠️  WARNINGS (" + str(warnings.size()) + "):")
		for w in warnings:
			push_warning(w)
			print("  • " + w)
	
	if not errors.is_empty():
		print("\n❌ ERRORS FOUND (" + str(errors.size()) + "):")
		for e in errors:
			push_error(e)
			print("  ✖ " + e)
		print("\nRESULT: Story validation FAILED with " + str(errors.size()) + " error(s).\n")
	else:
		print("\n✅ RESULT: Story validation PASSED cleanly with 0 errors!\n")
	
	return {
		"errors": errors,
		"warnings": warnings,
		"stats": stats,
		"orphans": orphans,
		"duplicates": duplicate_ids
	}
