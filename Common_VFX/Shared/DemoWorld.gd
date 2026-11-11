extends Node2D

@export var skill_id:=""
var spec:Dictionary
var available:Array=[]
var entities:Node2D
var player:CharacterBody2D
var camera:Camera2D
var training:Node2D
var overview:=false
var camera_follow:=true

func _ready() -> void:
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 for e in JSON.parse_string(FileAccess.get_file_as_string("res://catalog.json")):
  if ResourceLoader.exists("res://"+e.scene):available.append(e)
 assert(not available.is_empty())
 if skill_id=="":skill_id=available[0].id
 for e in available:
  if e.id==skill_id:spec=e
 assert(not spec.is_empty(),"Missing selected skill")
 RenderingServer.set_default_clear_color(Color("26332f"))
 var keys:=[[KEY_A,KEY_LEFT],[KEY_D,KEY_RIGHT],[KEY_W,KEY_UP],[KEY_S,KEY_DOWN]]
 for i in range(4):
  var action:String=["move_left","move_right","move_up","move_down"][i]
  if not InputMap.has_action(action):InputMap.add_action(action)
  for key in keys[i]:
   var event:=InputEventKey.new()
   event.physical_keycode=key
   InputMap.action_add_event(action,event)
 entities=Node2D.new()
 entities.y_sort_enabled=true
 add_child(entities)
 player=CharacterBody2D.new()
 player.set_script(load("res://Shared/Player.gd"))
 player.motion_mode=CharacterBody2D.MOTION_MODE_FLOATING
 var actor_data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://Shared/actor.json"))
 var frames:=SpriteFrames.new()
 frames.remove_animation("default")
 for animation in actor_data.animations:
  var clip:Dictionary=actor_data.animations[animation]
  frames.add_animation(animation)
  frames.set_animation_speed(animation,clip.fps)
  frames.set_animation_loop(animation,clip.loop)
  for path in clip.files:frames.add_frame(animation,load("res://"+path))
 player.animated_sprite=AnimatedSprite2D.new()
 player.animated_sprite.centered=false
 player.animated_sprite.sprite_frames=frames
 player.add_child(player.animated_sprite)
 for direction in actor_data.anchors_px:
  var point:Array=actor_data.anchors_px[direction]
  player.animation_anchors[direction]=Vector2(point[0],point[1])
 var shadow:=Polygon2D.new()
 var points:=PackedVector2Array()
 for i in range(24):points.append(Vector2(cos(i*TAU/24)*16,sin(i*TAU/24)*5))
 shadow.polygon=points
 shadow.color=Color(0,0,0,.28)
 shadow.z_index=-1
 player.add_child(shadow)
 var collider:=CollisionShape2D.new()
 var circle:=CircleShape2D.new()
 circle.radius=7
 collider.shape=circle
 collider.position=Vector2(0,-5)
 player.add_child(collider)
 entities.add_child(player)
 var dummy_texture:Texture2D=load("res://Shared/training_wood_dummy.png")
 for pos in [Vector2(1536,1120),Vector2(1536,1080),Vector2(1650,1090)]:
  var dummy:=StaticBody2D.new()
  dummy.position=pos
  dummy.set_meta("asset_id","training_wood_dummy")
  var sprite:=Sprite2D.new()
  sprite.texture=dummy_texture
  sprite.centered=false
  sprite.position=-Vector2(dummy_texture.get_width()/2.0,dummy_texture.get_height()-8)
  dummy.add_child(sprite)
  var shape:=CollisionShape2D.new()
  var size:=RectangleShape2D.new()
  size.size=Vector2(24,20)
  shape.shape=size
  shape.position=Vector2(0,-5)
  dummy.add_child(shape)
  entities.add_child(dummy)
 for rect in [Rect2(900,700,1272,20),Rect2(900,1580,1272,20),Rect2(900,700,20,900),Rect2(2152,700,20,900)]:
  var wall:=StaticBody2D.new()
  wall.position=rect.get_center()
  var shape:=CollisionShape2D.new()
  var box:=RectangleShape2D.new()
  box.size=rect.size
  shape.shape=box
  wall.add_child(shape)
  entities.add_child(wall)
 camera=Camera2D.new()
 add_child(camera)
 training=Node2D.new()
 training.set_script(load("res://"+spec.source) if skill_id in ["suodi","wanjian","sword"] else load("res://Shared/TrainingCore.gd"))
 training.world=self
 add_child(training)
 camera.force_update_scroll()
 DisplayServer.window_set_title("Wuxia Common VFX — "+spec.name_en)
 queue_redraw()

func _physics_process(_delta:float) -> void:
 if camera_follow and is_instance_valid(player):camera.position=player.position+Vector2(0,-128)

func _draw() -> void:
 draw_rect(Rect2(900,700,1272,900),Color("38433b"))
 for x in range(900,2173,64):draw_line(Vector2(x,700),Vector2(x,1600),Color(1,1,1,.045))
 for y in range(700,1601,64):draw_line(Vector2(900,y),Vector2(2172,y),Color(1,1,1,.045))
