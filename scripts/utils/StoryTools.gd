# StoryTools.gd
# Static utility functions for story authors, narrative designers, and debug tooling.
# Provides analytical helpers to query story graph topology, compute reachability,
# detect orphans, count path combinations to endings, and export graph structures.
class_name StoryTools
extends RefCounted

const STORY_DATA_PATH := "res://assets/data/story.json"

## Helper to load story dictionary if not provided explicitly.
static func load_story_dict(provided_data: Dictionary = {}) -> Dictionary:
	if not provided_data.is_empty():
		return provided_data
	
	# Check if running within engine scene tree with StoryManager autoload
	if Engine.get_main_loop() != null and Engine.get_main_loop().root != null and Engine.get_main_loop().root.has_node("StoryManager"):
		var sm = Engine.get_main_loop().root.get_node("StoryManager")
		if sm != null and sm.get("story_data") != null and not sm.story_data.is_empty():
			return sm.story_data
	
	# Fallback to direct disk read
	if FileAccess.file_exists(STORY_DATA_PATH):
		var file := FileAccess.open(STORY_DATA_PATH, FileAccess.READ)
		if file != null:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
				return json.data
	
	return {}

## Returns an Array of all checkpoint IDs in the story.
static func get_all_checkpoints(story_data: Dictionary = {}) -> Array[String]:
	var data := load_story_dict(story_data)
	var checkpoints_list: Array[String] = []
	var chapters: Dictionary = data.get("chapters", {})
	
	for ch_key in chapters:
		var ch = chapters[ch_key]
		if ch is Dictionary:
			var cps = ch.get("checkpoints", {})
			if cps is Dictionary:
				for cp_id in cps:
					checkpoints_list.append(str(cp_id))
	return checkpoints_list

## Returns an Array of choices (Dictionaries) for a given checkpoint ID.
static func get_checkpoint_choices(cp_id: String, story_data: Dictionary = {}) -> Array:
	var data := load_story_dict(story_data)
	var chapters: Dictionary = data.get("chapters", {})
	
	for ch_key in chapters:
		var ch = chapters[ch_key]
		if ch is Dictionary:
			var cps = ch.get("checkpoints", {})
			if cps is Dictionary and cps.has(cp_id):
				var cp = cps[cp_id]
				if cp is Dictionary:
					return cp.get("choices", []).duplicate(true)
	return []

## Returns an Array of checkpoint IDs reachable starting from entry points.
static func get_reachable_checkpoints(start_id: String = "", story_data: Dictionary = {}) -> Array[String]:
	var data := load_story_dict(story_data)
	var all_cps: Dictionary = _get_all_checkpoints_dict(data)
	
	var starts: Array[String] = []
	if not start_id.is_empty():
		if all_cps.has(start_id):
			starts.append(start_id)
	else:
		# Use initial checkpoint of each chapter as starting seeds
		var chapters: Dictionary = data.get("chapters", {})
		for ch_key in chapters:
			var ch = chapters[ch_key]
			if ch is Dictionary:
				var cps = ch.get("checkpoints", {})
				if cps is Dictionary and not cps.is_empty():
					starts.append(str(cps.keys()[0]))
	
	var visited: Dictionary = {}
	var queue: Array[String] = []
	for s in starts:
		if not visited.has(s):
			visited[s] = true
			queue.append(s)
	
	while not queue.is_empty():
		var curr_id: String = queue.pop_front()
		var cp: Dictionary = all_cps.get(curr_id, {})
		
		# Direct next
		if cp.has("next"):
			var next_id: String = str(cp.get("next", ""))
			if not next_id.is_empty() and all_cps.has(next_id) and not visited.has(next_id):
				visited[next_id] = true
				queue.append(next_id)
		
		# Choices
		if cp.has("choices") and cp["choices"] is Array:
			for choice in cp["choices"]:
				if choice is Dictionary:
					var c_next: String = str(choice.get("next", ""))
					if not c_next.is_empty() and all_cps.has(c_next) and not visited.has(c_next):
						visited[c_next] = true
						queue.append(c_next)
	
	var reachable: Array[String] = []
	for id in visited:
		reachable.append(id)
	return reachable

## Returns an Array of unreachable checkpoint IDs.
static func get_orphan_checkpoints(start_id: String = "", story_data: Dictionary = {}) -> Array[String]:
	var data := load_story_dict(story_data)
	var all_list: Array[String] = get_all_checkpoints(data)
	var reachable_list: Array[String] = get_reachable_checkpoints(start_id, data)
	
	var reachable_set: Dictionary = {}
	for r in reachable_list:
		reachable_set[r] = true
	
	var orphans: Array[String] = []
	for id in all_list:
		if not reachable_set.has(id):
			orphans.append(id)
	return orphans

## Returns an Array of dictionaries for all ending checkpoints.
static func get_all_endings(story_data: Dictionary = {}) -> Array:
	var data := load_story_dict(story_data)
	var endings: Array = []
	var chapters: Dictionary = data.get("chapters", {})
	
	for ch_key in chapters:
		var ch = chapters[ch_key]
		if ch is Dictionary:
			var cps = ch.get("checkpoints", {})
			if cps is Dictionary:
				for cp_id in cps:
					var cp = cps[cp_id]
					if cp is Dictionary and cp.get("type", "") == "end":
						var ending_info := cp.duplicate(true)
						ending_info["id"] = str(cp_id)
						ending_info["chapter"] = str(ch_key)
						endings.append(ending_info)
	return endings

## Counts total distinct narrative paths leading from start_id to ending_id.
static func count_paths_to_ending(ending_id: String, start_id: String = "ch1_start", story_data: Dictionary = {}) -> int:
	var data := load_story_dict(story_data)
	var all_cps: Dictionary = _get_all_checkpoints_dict(data)
	
	if not all_cps.has(start_id) or not all_cps.has(ending_id):
		return 0
	
	var memo: Dictionary = {}
	var visited_in_path: Dictionary = {}
	
	return _count_paths_dfs(start_id, ending_id, all_cps, memo, visited_in_path)

static func _count_paths_dfs(curr_id: String, target_id: String, all_cps: Dictionary, memo: Dictionary, visited: Dictionary) -> int:
	if curr_id == target_id:
		return 1
	
	if visited.has(curr_id):
		# Prevent infinite loop in non-DAG graphs
		return 0
	
	if memo.has(curr_id):
		return memo[curr_id]
	
	visited[curr_id] = true
	var total_paths := 0
	var cp: Dictionary = all_cps.get(curr_id, {})
	
	# Linear next link
	if cp.has("next"):
		var next_id: String = str(cp.get("next", ""))
		if not next_id.is_empty() and all_cps.has(next_id):
			total_paths += _count_paths_dfs(next_id, target_id, all_cps, memo, visited)
	
	# Choice links
	if cp.has("choices") and cp["choices"] is Array:
		for choice in cp["choices"]:
			if choice is Dictionary:
				var c_next: String = str(choice.get("next", ""))
				if not c_next.is_empty() and all_cps.has(c_next):
					total_paths += _count_paths_dfs(c_next, target_id, all_cps, memo, visited)
	
	visited.erase(curr_id)
	memo[curr_id] = total_paths
	return total_paths

## Exports the story graph layout as a Dictionary for visualization or graph exporters.
static func export_story_graph(story_data: Dictionary = {}) -> Dictionary:
	var data := load_story_dict(story_data)
	var all_cps: Dictionary = _get_all_checkpoints_dict(data)
	
	var nodes: Array = []
	var edges: Array = []
	var endings: Array = []
	
	for cp_id in all_cps:
		var cp: Dictionary = all_cps[cp_id]
		var cp_type: String = cp.get("type", "cutscene")
		
		nodes.append({
			"id": cp_id,
			"type": cp_type,
			"chapter": cp.get("chapter", 1),
			"scene": cp.get("scene", "")
		})
		
		if cp_type == "end":
			endings.append(cp_id)
		
		# Edge via 'next'
		if cp.has("next"):
			var next_id: String = str(cp.get("next", ""))
			if not next_id.is_empty():
				edges.append({
					"from": cp_id,
					"to": next_id,
					"label": "next",
					"type": "linear"
				})
		
		# Edges via 'choices'
		if cp.has("choices") and cp["choices"] is Array:
			for choice in cp["choices"]:
				if choice is Dictionary:
					var c_next: String = str(choice.get("next", ""))
					if not c_next.is_empty():
						edges.append({
							"from": cp_id,
							"to": c_next,
							"label": choice.get("text", "choice"),
							"choice_id": choice.get("id", ""),
							"type": "choice"
						})
	
	return {
		"game_title": data.get("game_title", "BranchingPaths"),
		"version": data.get("version", "1.0"),
		"nodes": nodes,
		"edges": edges,
		"endings": endings
	}

static func _get_all_checkpoints_dict(data: Dictionary) -> Dictionary:
	var dict: Dictionary = {}
	var chapters: Dictionary = data.get("chapters", {})
	for ch_key in chapters:
		var ch = chapters[ch_key]
		if ch is Dictionary:
			var cps = ch.get("checkpoints", {})
			if cps is Dictionary:
				for cp_id in cps:
					dict[str(cp_id)] = cps[cp_id]
	return dict
