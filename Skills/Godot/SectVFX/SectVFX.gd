extends Node2D
## Add at the caster's ground position. The entire SectVFX/ folder is portable.
signal contact(skill: String, ground_world: Vector2)
signal support(skill: String)
signal caster_motion(skill: String, from_world: Vector2, to_world: Vector2)
signal finished(skill: String)
const CONTEXT = preload("res://SectVFX/VisualContext.gd")
const CATALOG_PATH = "res://SectVFX/catalog.json"
const STEP := 1.0/60.0
var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
var skill_id := ""
var context: Node2D
var playing := false
var seeking := false
var elapsed := 0.0
var accumulator := 0.0
var glow_enabled := true
var saved: Dictionary = {}
var done_emitted := false
var origin := Vector2.ZERO

func play_skill(id: String, facing: String = "east", target_offset: Vector2 = Vector2(216,0), options: Dictionary = {}) -> Error:
	var entry: Dictionary = {}
	for record in catalog:
		if record.id == id: entry = record
	if entry.is_empty() or facing not in ["east","west","north","south"]: return ERR_INVALID_PARAMETER
	for key in ["contact_offsets","ally_offsets"]:
		if options.has(key):
			if not options[key] is Array: return ERR_INVALID_PARAMETER
			for point in options[key]:
				if not point is Vector2: return ERR_INVALID_PARAMETER
	if options.has("ally_offsets") and options.ally_offsets.size()!=2: return ERR_INVALID_PARAMETER
	for key in ["endpoint_resolver","path_blocker","movement_resolver","caster_frame_provider"]:
		if options.has(key) and not options[key] is Callable: return ERR_INVALID_PARAMETER
	if options.has("caster_texture") and not options.caster_texture is Texture2D: return ERR_INVALID_PARAMETER
	if options.has("caster_anchor") and not options.caster_anchor is Vector2: return ERR_INVALID_PARAMETER
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://"+entry.file))
	if spec.has("direction_phases"):
		var phase_direction: String = {"north":"up","south":"down"}.get(facing,"right")
		spec.phases = spec.direction_phases[phase_direction]
	stop()
	skill_id = id
	origin = global_position
	saved = {"id":id,"facing":facing,"target":target_offset,"options":options.duplicate()}
	context = CONTEXT.new()
	context.host = self
	add_child(context)
	# The original visual math uses world ground coordinates; keep a private identity space.
	context.top_level = true
	context.global_transform = Transform2D.IDENTITY
	context.setup(spec,origin,facing,target_offset,options)
	var effect := Node2D.new()
	effect.set_script(load("res://"+spec.runtime_script))
	context.effect = effect
	effect.world = context
	effect.facing = {"east":Vector2.RIGHT,"west":Vector2.LEFT,"north":Vector2.UP,"south":Vector2.DOWN}[facing]
	context.add_child(effect)
	effect.set_process(false)
	if "send_mock_dart" in effect: effect.send_mock_dart = options.get("demo_incoming",false)
	effect.play(spec,origin,context.selected_target)
	effect.set_glow_enabled(glow_enabled)
	elapsed = 0
	accumulator = 0
	done_emitted = false
	playing = true
	sync_array_frames()
	return OK

func stop() -> void:
	playing = false
	if is_instance_valid(context):
		if is_instance_valid(context.effect):
			context.effect.clear()
			context.effect.free()
		remove_child(context)
		context.queue_free()
	context = null

func advance(seconds: float) -> void:
	assert(seconds >= 0)
	if not is_instance_valid(context): return
	var remaining := seconds
	while remaining > .0000001 and context.effect.active:
		var dt := minf(STEP,remaining)
		context.effect._process(dt)
		elapsed += dt
		remaining -= dt
		sync_array_frames()
		# Reapply the switch after new pieces are spawned; source code assumes glow starts on.
		if not glow_enabled: context.effect.set_glow_enabled(false)
	if not context.effect.active and not done_emitted:
		done_emitted = true
		playing = false
		if not seeking: finished.emit(skill_id)

func seek(seconds: float) -> void:
	if saved.is_empty(): return
	seeking = true
	if seconds < elapsed:
		var args := saved.duplicate()
		assert(play_skill(args.id,args.facing,args.target,args.options)==OK)
	playing = false
	advance(maxf(0,seconds-elapsed))
	seeking = false

func sync_array_frames() -> void:
	if skill_id != "01_array" or not is_instance_valid(context): return
	var fx: Node2D = context.effect
	for piece in fx.pieces:
		piece.node.pause()
		var records: Array = fx.skill.phases[piece.phase].frames
		var duration := 0.0
		for record in records: duration += float(record.duration)
		var age: float = maxf(0,fx.elapsed-piece.born)
		if piece.phase == "projectile": age = fmod(age,duration)
		var selected: int = records.size()-1
		for i in range(records.size()):
			if age < float(records[i].duration):
				selected = i
				break
			age -= float(records[i].duration)
		piece.node.frame = selected

func set_glow(enabled: bool) -> void:
	glow_enabled = enabled
	if is_instance_valid(context): context.effect.set_glow_enabled(enabled)

func update_target(offset_from_original_caster: Vector2) -> void:
	if is_instance_valid(context): context.selected_target.position = origin+offset_from_original_caster

func boundary_attempt(step: Vector2) -> Vector2:
	if not is_instance_valid(context): return Vector2.ZERO
	context.effect.try_move_target(step)
	return context.selected_target.position-origin

func incoming_contact() -> bool:
	if not is_instance_valid(context) or not context.effect.active: return false
	var fx: Node2D = context.effect
	var mode: String = context.spec.mode
	var window: Vector2 = {"orbit":Vector2(.25,4.2),"decoy":Vector2(.30,2.0),"rebound":Vector2(.45,2.3),"bell":Vector2(.78,2.6),"guardian":Vector2(.78,2.5)}.get(mode,Vector2.ZERO)
	if window==Vector2.ZERO or fx.elapsed<window.x or fx.elapsed>window.y: return false
	match mode:
		"orbit":
			if fx.deflected or not is_instance_valid(fx.sword): return false
			fx.deflected = true
			fx.deflect_time = fx.elapsed
			fx.attack_start = fx.sword.global_position
			fx.attack_end = context.selected_target.position+Vector2(0,-52)
			fx.punishments_fired = 1
			fx.spawn("impact",fx.attack_start,.75,.45)
			fx.spawn("hit_star",fx.attack_start,.8,.5)
		"decoy":
			if fx.decoy_burst: return false
			fx.burst_decoy()
		"rebound":
			if fx.incoming_contact: return false
			fx.incoming_contact = true
			fx.contact_time = fx.elapsed
		"bell", "guardian":
			if fx.incoming_contact: return false
			fx.incoming_contact = true
			fx.deflect_time = fx.elapsed
			if mode == "bell": fx.emit_wave()
			else:
				fx.counter_count = 1
				fx.punishments_fired = 1
				fx.begin_pressure("counter")
		_: return false
	return true

func emit_contact(at: Vector2) -> void:
	if not seeking: call_deferred("emit_signal","contact",skill_id,at)
func emit_motion(from: Vector2, to: Vector2) -> void:
	if not seeking and from != to: call_deferred("emit_signal","caster_motion",skill_id,from,to)
func _process(delta: float) -> void:
	if not playing: return
	accumulator += delta
	while accumulator >= STEP and playing:
		advance(STEP)
		accumulator -= STEP
func _exit_tree() -> void: stop()
