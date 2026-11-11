extends Node2D
signal cast_release(direction: String)
const DIRECTIONS = ["south", "north", "east", "west"]
var catalog: Dictionary
var images: Dictionary = {}
var casting := false
var elapsed := 0.0
var emitted: Dictionary = {}
var auto := true
var idle_time := 0.0
var font: Font

func _ready() -> void:
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 font = ThemeDB.fallback_font
 catalog = JSON.parse_string(FileAccess.get_file_as_string("res://actor.json"))
 for action in ["idle", "cast"]:
  images[action] = {}
  for direction in DIRECTIONS:
   images[action][direction] = []
   for file in catalog[action][direction].files:
    var texture = load("res://" + file)
    assert(texture != null, file)
    images[action][direction].append(texture)
 queue_redraw()

func frame_at(clip: Dictionary, time_ms: float) -> int:
 var t := maxf(time_ms, 0.0)
 var total := 0.0
 for ms in clip.durations_ms: total += float(ms)
 if clip.loop: t = fmod(t, total)
 for i in range(clip.durations_ms.size()):
  if t < float(clip.durations_ms[i]): return i
  t -= float(clip.durations_ms[i])
 return clip.durations_ms.size() - 1

func start_cast() -> bool:
 if casting: return false
 casting = true
 elapsed = 0.0
 emitted.clear()
 queue_redraw()
 return true

func advance(delta: float) -> void:
 if casting:
  elapsed += delta
  for direction in DIRECTIONS:
   var clip: Dictionary = catalog.cast[direction]
   if elapsed * 1000.0 + 0.000001 >= float(clip.suggested_release.time_ms) and not emitted.has(direction):
    emitted[direction] = true
    cast_release.emit(direction)
  if elapsed + 0.000001 >= 1.2:
   casting = false
   elapsed = 0.0
   idle_time = 0.0
 else:
  elapsed += delta
  idle_time += delta
  if auto and idle_time >= 0.8: start_cast()
 queue_redraw()

func _process(delta: float) -> void:
 advance(delta)

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_SPACE: start_cast()
  if event.keycode == KEY_A: auto = not auto

func _draw() -> void:
 if catalog.is_empty(): return
 draw_rect(Rect2(0, 0, 840, 510), Color("262b28"))
 draw_string(font, Vector2(22, 28), "Xuanxiao Master | native 1x | Idle -> Cast -> Idle", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f3e4c2"))
 draw_string(font, Vector2(22, 57), "Space: cast   A: auto loop   Cross = fixed world foot anchor", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
 for row in range(2):
  var base_y := 245.0 if row == 0 else 445.0
  for i in range(4):
   var direction: String = DIRECTIONS[i]
   var world := Vector2(115 + i * 200, base_y)
   draw_line(world + Vector2(-60, 0), world + Vector2(60, 0), Color("718477"))
   draw_line(world - Vector2(0, 5), world + Vector2(0, 5), Color("ffd68b"))
   var action := "idle" if row == 0 or not casting else "cast"
   var clip: Dictionary = catalog[action][direction]
   var index := 0 if row == 0 else frame_at(clip, elapsed * 1000.0)
   var anchor := Vector2(float(clip.anchor[0]), float(clip.anchor[1]))
   draw_texture(images[action][direction][index], world - anchor)
   var label := "%s / %s / f%02d" % [direction, action, index]
   draw_string(font, Vector2(world.x - 85, base_y + 27), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
 draw_string(font, Vector2(22, 96), "Top: formal Idle reference | Bottom: live non-looping Cast / recovery", HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
 draw_string(font, Vector2(22, 500), "Release cues are visual suggestions; choose actual hit timing per skill.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("dfc88f"))
