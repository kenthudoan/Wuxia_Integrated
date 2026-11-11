extends RefCounted
## Read-only reference frames. This is a VFX integration example, not a casting animation.
var clips: Dictionary
var textures: Dictionary = {}
var facing := "east"
func _init(direction: String = "east") -> void:
	facing = direction
	clips = JSON.parse_string(FileAccess.get_file_as_string("res://Examples/Hanyue/animation.json")).clips
	for action in ["idle","walk"]:
		for file in clips[action][facing].files:
			textures[file] = load("res://"+file)
func frame_at(elapsed: float) -> Dictionary:
	var moving := elapsed >= .32 and elapsed < .88
	var clip: Dictionary = clips["walk" if moving else "idle"][facing]
	var time := elapsed-.32 if moving else elapsed
	var fps: float = 12.0 if moving else float(clip.fps)
	var index: int = int(maxf(0,time)*fps)%clip.files.size()
	return {"texture":textures[clip.files[index]],"anchor":Vector2(clip.anchor[0],clip.anchor[1])}
