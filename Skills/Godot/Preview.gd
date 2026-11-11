extends Node2D
const VFX = preload("res://SectVFX/SectVFX.gd")
var fx: Node2D
var label: Label
var selected := 4
var direction := "east"
var running := true
var clock := 0.0
var changed := true
var light := false
var incoming := true
var duration := 0.0
var auto_next := false
var action_reference: RefCounted
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("303833"))
	fx = VFX.new()
	add_child(fx)
	label = Label.new()
	label.position = Vector2(20,16)
	label.add_theme_font_size_override("font_size",20)
	add_child(label)
	replay()
func replay() -> void:
	var skill: Dictionary = fx.catalog[selected]
	fx.position = Vector2(350,570)
	var dir: Vector2 = {"east":Vector2.RIGHT,"west":Vector2.LEFT,"north":Vector2.UP,"south":Vector2.DOWN}[direction]
	if direction == "west": fx.position.x = 710
	if direction == "south": fx.position.y = 340
	var aim: Vector2 = dir*(165 if skill.mode in ["bell","guardian","palm","ring"] else 240)
	var options := {"demo_incoming":incoming,"show_caster":false}
	if skill.mode == "beam":
		fx.position.x = 100 if direction != "west" else 910
		options.contact_offsets = [dir*390,dir*216,dir*320+dir.orthogonal()*110]
		options.contact_offsets.pop_back() # Off-axis target omitted from this simple gallery.
	if skill.mode == "array":
		fx.position = Vector2(360,610)
		aim = Vector2(200,-90)
	if skill.id == "06_dash":
		action_reference = load("res://Examples/Hanyue/ExistingActionFrames.gd").new(direction)
		options.show_caster = true
		options.caster_frame_provider = action_reference.frame_at
	assert(fx.play_skill(skill.id,direction,aim,options)==OK)
	clock = 0
	changed = true
	label.text = "%02d / 21   %s · %s\n[ / ] skill | SPACE replay | Arrows facing | G glow | B backdrop | I demo incoming\nENTER pause | A auto-next | All visuals use delivered PNG / shaders; no town or combat." % [selected+1,{"玄霄剑宗":"Xuanxiao","寒月宫":"Hanyue","赤焰刀门":"Chiyan","碧竹山庄":"Bizhu","百花谷":"Baihua","幽冥教":"Youming","金刚寺":"Jingang"}[skill.sect],skill.id]
	queue_redraw()
func _draw() -> void:
	for x in range(0,1024,64): draw_line(Vector2(x,110),Vector2(x,768),Color(1,1,1,.035))
	for y in range(128,768,64): draw_line(Vector2(0,y),Vector2(1024,y),Color(1,1,1,.035))
	if is_instance_valid(fx) and is_instance_valid(fx.context):
		draw_circle(fx.context.player.position,4,Color(.6,.7,.62))
		draw_circle(fx.context.selected_target.position,4,Color(.75,.64,.43))
func _process(delta: float) -> void:
	if not running: return
	clock += delta
	var mode: String = fx.catalog[selected].mode
	if mode == "array" and clock > 2 and changed:
		fx.boundary_attempt(Vector2(118,0))
		changed = false
	if not fx.playing and clock > 2.0:
		duration += delta
		if duration > .6:
			if auto_next: selected = (selected+1)%21
			duration = 0
			replay()
	queue_redraw()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_BRACKETLEFT: selected = posmod(selected-1,21); replay()
		KEY_BRACKETRIGHT: selected = (selected+1)%21; replay()
		KEY_SPACE: replay()
		KEY_G: fx.set_glow(not fx.glow_enabled)
		KEY_I: incoming = not incoming; replay()
		KEY_A: auto_next = not auto_next
		KEY_ENTER: running = not running; fx.playing = running
		KEY_B:
			light = not light
			RenderingServer.set_default_clear_color(Color("b2ab91") if light else Color("303833"))
	var directions := {KEY_LEFT:"west",KEY_RIGHT:"east",KEY_UP:"north",KEY_DOWN:"south"}
	if directions.has(event.keycode): direction = directions[event.keycode]; replay()
