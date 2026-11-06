# bake_object_sprites.gd
# Renders the interactive objects (doors, lockers, weapon pickups) from the same
# art code the game uses, at 2x, straight into shippable PNGs.
#
#   assets/images/sprites/objects/<key>.png   (+ _meta.json with draw size)
#
# Run with a real renderer:
#   xvfb-run -a godot --path . res://tools/BakeObjectSprites.tscn
extends Node

const OUT_DIR := "res://assets/images/sprites/objects"

const ITEMS := [
	{"key": "door_h_closed", "kind": "door", "size": Vector2(160, 26), "open": false, "horizontal": true},
	{"key": "door_h_open", "kind": "door", "size": Vector2(160, 26), "open": true, "horizontal": true},
	{"key": "door_v_closed", "kind": "door", "size": Vector2(26, 160), "open": false, "horizontal": false},
	{"key": "door_v_open", "kind": "door", "size": Vector2(26, 160), "open": true, "horizontal": false},
	{"key": "locker_closed", "kind": "locker", "size": Vector2(54, 92), "open": false},
	{"key": "locker_open", "kind": "locker", "size": Vector2(54, 92), "open": true},
	{"key": "pickup_bat", "kind": "pickup", "size": Vector2(30, 30), "weapon": "bat"},
	{"key": "pickup_knife", "kind": "pickup", "size": Vector2(30, 30), "weapon": "knife"},
	{"key": "pickup_pistol", "kind": "pickup", "size": Vector2(30, 30), "weapon": "pistol"},
	{"key": "pickup_shotgun", "kind": "pickup", "size": Vector2(30, 30), "weapon": "shotgun"},
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)

	var meta := {}
	for item in ITEMS:
		var size: Vector2 = item["size"]
		var draw_size := TopDownObjectArt.draw_size(size) * TopDownObjectArt.BAKE_SCALE
		vp.size = Vector2i(int(ceil(draw_size.x)), int(ceil(draw_size.y)))
		var art := _ArtNode.new()
		art.item = item
		art.position = Vector2(vp.size) * 0.5
		art.scale = Vector2.ONE * TopDownObjectArt.BAKE_SCALE
		vp.add_child(art)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img == null:
			push_error("bake: no image for " + str(item["key"]))
			art.queue_free()
			continue
		img.convert(Image.FORMAT_RGBA8)
		var path := "%s/%s.png" % [OUT_DIR, item["key"]]
		img.save_png(ProjectSettings.globalize_path(path))
		meta[item["key"]] = {
			"footprint": [size.x, size.y],
			"draw_size": [size.x + TopDownObjectArt.PAD * 2.0, size.y + TopDownObjectArt.PAD * 2.0],
			"bake_scale": TopDownObjectArt.BAKE_SCALE,
			"pivot": [img.get_width() * 0.5, img.get_height() * 0.5],
		}
		print("bake: ", item["key"], " -> ", path, " ", img.get_width(), "x", img.get_height())
		art.queue_free()
		await get_tree().process_frame

	var f := FileAccess.open("%s/_meta.json" % OUT_DIR, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta, "  "))
		f.close()
	get_tree().quit()

class _ArtNode extends Node2D:
	var item: Dictionary = {}
	func _draw() -> void:
		var kind := str(item.get("kind", "door"))
		match kind:
			"door":
				TopDownObjectArt.door(self, item["size"], bool(item.get("open", false)), bool(item.get("horizontal", true)))
			"locker":
				TopDownObjectArt.locker(self, item["size"], bool(item.get("open", false)))
			"pickup":
				TopDownObjectArt.pickup(self, str(item.get("weapon", "pistol")))
