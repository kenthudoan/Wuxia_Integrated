extends Node2D
## Private visual markers only; no game actor, damage, health or physics dependency.
class MotionAnchor extends Node2D:
	var context: Node2D
	func move_and_collide(step: Vector2) -> Variant:
		var before := position
		var wanted := position + step
		var actual: Vector2 = context.resolve_motion(before,wanted)
		position = actual
		context.host.emit_motion(before,actual)
		return true if actual.distance_to(wanted) > .01 else null
class Contacts extends Node:
	var context: Node2D
	var dummies: Array = []
	func hit(marker: Node2D, _legacy_amount: int, _legacy_flag: bool) -> void:
		if marker.visible: context.host.emit_contact(marker.position)
	func blocked(from: Vector2, marker: Node2D) -> bool:
		return not marker.visible or context.path_blocked(from,marker.position)
var host: Node2D
var player: MotionAnchor
var entities: Node2D
var caster_preview: Sprite2D
var caster_facing := "east"
var caster_actions: Dictionary = {}
var training: Contacts
var ally_markers: Array = []
var selected_target: Node2D
var effect: Node2D
var spec: Dictionary
var options: Dictionary
var origin := Vector2.ZERO

func setup(data: Dictionary, at: Vector2, direction: String, aim: Vector2, settings: Dictionary) -> void:
	spec = data
	options = settings
	origin = at
	caster_facing = direction
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	player = MotionAnchor.new()
	player.context = self
	player.position = at
	add_child(player)
	caster_preview = Sprite2D.new()
	caster_preview.centered = false
	caster_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var actor: Dictionary = spec.get("caster",{})
	if options.has("caster_texture"):
		caster_preview.texture = options.caster_texture
	elif actor.has("file"):
		caster_preview.texture = load("res://"+actor.file)
	var anchor: Vector2 = options.get("caster_anchor",Vector2(actor.get("anchor",[64,104])[0],actor.get("anchor",[64,104])[1]))
	caster_preview.position = -anchor
	caster_preview.visible = options.get("show_caster",false)
	player.add_child(caster_preview)
	training = Contacts.new()
	training.context = self
	add_child(training)
	var offsets: Array = options.get("contact_offsets",[aim])
	for offset in offsets:
		var marker := Node2D.new()
		marker.position = at+offset
		marker.set_meta("training_hp",300) # Legacy visual gate only; never decremented.
		add_child(marker)
		training.dummies.append(marker)
	selected_target = Node2D.new()
	selected_target.position = at+aim
	selected_target.set_meta("training_hp",300)
	add_child(selected_target)
	if training.dummies.is_empty():
		selected_target.visible = false
	elif (training.dummies[0].position-selected_target.position).length()<.01:
		selected_target.free()
		selected_target = training.dummies[0]
	var allies: Array = options.get("ally_offsets",[Vector2(-82,12),Vector2(86,18)])
	for offset in allies:
		var marker := Node2D.new()
		marker.position = at+offset
		marker.set_meta("test_hp",60) # Private pulse marker, not buyer health.
		add_child(marker)
		ally_markers.append(marker)
	if spec.get("has_spin_action",false): caster_actions["ring"] = true

func current_caster_action() -> Dictionary:
	return spec.get("motion_flags_by_facing",{}).get(caster_facing,{})
func sync_caster_action(elapsed: float) -> void:
	var provider: Callable = options.get("caster_frame_provider",Callable())
	if not provider.is_valid(): return
	var frame: Variant = provider.call(elapsed)
	assert(frame is Dictionary and frame.get("texture") is Texture2D and frame.get("anchor") is Vector2,"caster_frame_provider must return texture:Texture2D and anchor:Vector2")
	caster_preview.texture = frame.texture
	caster_preview.position = -frame.anchor
func restore_caster_idle() -> void:
	if is_instance_valid(caster_preview): caster_preview.modulate = Color.WHITE
func apply_heal(_legacy_amount: int) -> void:
	if not host.seeking: host.call_deferred("emit_signal","support",host.skill_id)
func trace_endpoint(from: Vector2, to: Vector2) -> Vector2:
	var resolver: Callable = options.get("endpoint_resolver",Callable())
	if not resolver.is_valid(): return to
	var result: Variant = resolver.call(from,to)
	assert(result is Vector2,"endpoint_resolver must return Vector2")
	return result
func path_blocked(from: Vector2, to: Vector2) -> bool:
	var resolver: Callable = options.get("path_blocker",Callable())
	if resolver.is_valid(): return bool(resolver.call(from,to))
	return trace_endpoint(from,to).distance_to(to) > .01
func resolve_motion(from: Vector2, wanted: Vector2) -> Vector2:
	var resolver: Callable = options.get("movement_resolver",Callable())
	if not resolver.is_valid(): return wanted
	var result: Variant = resolver.call(from,wanted)
	assert(result is Vector2,"movement_resolver must return Vector2")
	return result
