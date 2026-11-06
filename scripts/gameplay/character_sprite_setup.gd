# Character Sprite Setup
# This script creates SpriteFrames resources for Elena and Danny
# Run in Godot editor: Project > Tool Script > Create Sprite Frames

@tool
extends EditorScript

const SPRITE_DIR = "res://assets/images/sprites/"

func _run():
    create_character_frames("elena")
    create_character_frames("danny")
    print("SpriteFrames created for elena and danny")

func create_character_frames(char_name: String):
    var frames = SpriteFrames.new()
    
    # Idle animation (south facing)
    frames.add_animation("idle_south")
    frames.add_frame("idle_south", load(SPRITE_DIR + char_name + "_idle_south.png"))
    
    # Walk south
    frames.add_animation("walk_south")
    frames.add_frame("walk_south", load(SPRITE_DIR + char_name + "_walk_south.png"))
    frames.add_frame("walk_south", load(SPRITE_DIR + char_name + "_idle_south.png"))
    
    # Walk east
    frames.add_animation("walk_east")
    frames.add_frame("walk_east", load(SPRITE_DIR + char_name + "_walk_east.png"))
    frames.add_frame("walk_east", load(SPRITE_DIR + char_name + "_idle_south.png"))  # temp fallback
    
    # Walk west (mirror of east)
    frames.add_animation("walk_west")
    frames.add_frame("walk_west", load(SPRITE_DIR + char_name + "_walk_west.png"))
    frames.add_frame("walk_west", load(SPRITE_DIR + char_name + "_idle_south.png"))  # temp fallback
    
    # Walk north
    frames.add_animation("walk_north")
    frames.add_frame("walk_north", load(SPRITE_DIR + char_name + "_walk_north.png"))
    frames.add_frame("walk_north", load(SPRITE_DIR + char_name + "_idle_south.png"))  # temp fallback
    
    # Save the resource
    var save_path = "res://assets/images/sprites/" + char_name + "_frames.tres"
    ResourceSaver.save(frames, save_path)
    print("Saved " + save_path)
