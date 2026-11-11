extends Node2D

var catalog:Dictionary
var items:Array
var index:=0
var world:Node2D
var item:Node2D
var actor:CharacterBody2D
var camera:Camera2D
var hud:Label
var outline:Line2D
var debug_visible:=false
var auto_check:=false

func _ready() -> void:
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://BuyerKit/expansion/catalog.json"))
	items=catalog.items
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var floor_sprite:=Sprite2D.new()
	floor_sprite.texture=load("res://BuyerKit/terrain/City_file.png")
	floor_sprite.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_sprite.region_enabled=true
	floor_sprite.region_rect=Rect2(0,0,8192,8192)
	floor_sprite.z_index=-20
	add_child(floor_sprite)
	world=Node2D.new();world.y_sort_enabled=true;add_child(world)
	actor=CharacterBody2D.new();actor.name="ReferenceWalker";actor.motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
	actor.set_script(load("res://BuyerKit/scripts/Walker.gd"))
	var collider:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=7
	collider.shape=circle;collider.position=Vector2(0,-5);actor.add_child(collider)
	var picture:=Sprite2D.new();picture.texture=load(catalog.reference_actor.file);picture.centered=false
	picture.position=-Vector2(catalog.reference_actor.anchor_px[0],catalog.reference_actor.anchor_px[1]);actor.add_child(picture)
	world.add_child(actor)
	camera=Camera2D.new();add_child(camera)
	outline=Line2D.new();outline.z_index=10;outline.width=2;outline.default_color=Color(1,0.25,0.15,0.9);add_child(outline)
	var ui:=CanvasLayer.new();add_child(ui)
	var font:Font=load("res://BuyerKit/expansion/fonts/font.otf")
	var panel:=Panel.new();panel.position=Vector2(12,10);panel.size=Vector2(1508,144);ui.add_child(panel)
	hud=Label.new();hud.position=Vector2(24,18);hud.add_theme_font_override("font",font);hud.add_theme_font_size_override("font_size",20);ui.add_child(hud)
	var controls:=HBoxContainer.new();controls.position=Vector2(20,970);ui.add_child(controls)
	for label in ["上一项 / PgUp","下一项 / PgDn","前方 / F","后方 / B","碰撞 / C","1×近看 / Z","返回五地图 / Esc"]:
		var button:=Button.new();button.text=label;button.add_theme_font_override("font",font)
		button.pressed.connect(func():command(label));controls.add_child(button)
	select_item(0)
func select_item(next:int) -> void:
	index=posmod(next,items.size())
	if is_instance_valid(item):item.free()
	var row:Dictionary=items[index]
	item=load(row.prefab).instantiate();world.add_child(item)
	actor.position=Vector2(0,35);actor.velocity=Vector2.ZERO
	var box:Array=row.visible_bbox;var anchor:Array=row.anchor_px
	var top:float=(float(box[1])-float(anchor[1]))*float(row.world_scale)
	camera.position=Vector2(0,top/2.0+50)
	camera.zoom=Vector2.ONE*(0.5 if row.kind=="building" else 1.0)
	outline.clear_points()
	if row.collision_rect_local!=null:
		var r:Array=row.collision_rect_local;var s:float=row.world_scale
		var a:=Vector2(r[0],r[1])*s;var b:=Vector2(r[0]+r[2],r[1]+r[3])*s
		outline.points=PackedVector2Array([a,Vector2(b.x,a.y),b,Vector2(a.x,b.y),a])
	outline.visible=debug_visible
	update_hud()

func update_hud() -> void:
	var row:Dictionary=items[index]
	var door:="" if row.door_world_height==null else " | 门高约 %spx / 人物118px"%row.door_world_height
	hud.text="%d/%d · %s %s | 世界比例 %s× | 相机 %s×%s\nWASD/方向键移动；金色脚点为半径7px测试体，人物仅复用原待机帧\n%s；门只是实体外立面，不含室内传送、寻路或交互"%[index+1,items.size(),row.id,row.name,row.world_scale,camera.zoom.x,door,"可穿行装饰 / 低地面层" if row.collision_rect_local==null else "按根节点脚点Y排序 / 基部碰撞"]

func command(label:String) -> void:
	if label.contains("上一项"):select_item(index-1)
	elif label.contains("下一项"):select_item(index+1)
	elif label.contains("前方"):actor.position=Vector2(0,35)
	elif label.contains("后方"):
		var row:Dictionary=items[index]
		actor.position=Vector2(0,-80 if row.collision_rect_local==null else float(row.collision_rect_local[1])*float(row.world_scale)-30)
	elif label.contains("碰撞"):debug_visible=not debug_visible;outline.visible=debug_visible
	elif label.contains("近看"):
		camera.zoom=Vector2.ONE if camera.zoom.x<1 else Vector2.ONE*0.5
		camera.position=actor.position+Vector2(0,-260);update_hud()
	elif label.contains("返回"):get_tree().change_scene_to_file("res://BuyerKit/Viewer.tscn")

func _unhandled_key_input(event:InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or auto_check:return
	match event.keycode:
		KEY_PAGEUP:select_item(index-1)
		KEY_PAGEDOWN:select_item(index+1)
		KEY_F:command("前方")
		KEY_B:command("后方")
		KEY_C:command("碰撞")
		KEY_Z:command("近看")
		KEY_R:select_item(index)
		KEY_ESCAPE:command("返回")
