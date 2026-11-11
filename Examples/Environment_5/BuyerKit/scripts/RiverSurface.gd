extends Node2D

@export var profile:Array
@export var paving:Texture2D
@export var paving_strip_enabled:=true
var water:ImageTexture
var coping:ImageTexture
var face:ImageTexture


func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	var source:Image=load("res://assets/river_bridge/source.png").get_image()
	water=ImageTexture.create_from_image(source.get_region(Rect2i(944,240,112,512)))
	coping=ImageTexture.create_from_image(source.get_region(Rect2i(859,755,19,32)))
	face=ImageTexture.create_from_image(source.get_region(Rect2i(878,755,9,32)))
	assert(profile.front()[0]==448 and profile.back()[0]==2688)
	var surface:=Polygon2D.new()
	var points:=PackedVector2Array();var uv:=PackedVector2Array()
	for side in [0,1]:
		var rows:Array=range(448,2688,16)
		if side==1:rows.reverse()
		for y in rows:
			var banks:=edges(y+8)
			for dy in ([0,16] if side==0 else [16,0]):
				points.append(Vector2(banks[side],y+dy))
				uv.append(Vector2(side*water.get_width(),y+dy-448))
	surface.polygon=points;surface.uv=uv;surface.texture=water
	# Mirrored wrap is continuous at the sample boundary; no repeated vertical stripe.
	surface.texture_repeat=CanvasItem.TEXTURE_REPEAT_MIRROR
	add_child(surface)
	var masonry:=Node2D.new();masonry.draw.connect(draw_banks);add_child(masonry)
	queue_redraw()


func edges(y:float) -> Vector2:
	for i in range(profile.size()-1):
		var a:Array=profile[i];var b:Array=profile[i+1]
		if a[0]<=y and y<=b[0]:
			var phase:float=(y-a[0])/float(b[0]-a[0])
			return Vector2(roundf(lerpf(a[1],b[1],phase)/2)*2,roundf(lerpf(a[2],b[2],phase)/2)*2)
	assert(false,"River sample outside profile")
	return Vector2.ZERO


func texture_patch(area:Rect2,texture:Texture2D,phase:Vector2) -> void:
	draw_texture_rect_region(texture,area,Rect2(phase,area.size),Color.WHITE,false,false)


func _draw() -> void:
	# Re-pave only the old straight channel strip, keeping the world's tile phase.
	if paving_strip_enabled:
		texture_patch(Rect2(2208,448,384,2240),paving,Vector2(2208,448).posmodv(paving.get_size()))


func draw_banks() -> void:
	var canvas:Node2D=get_child(1)
	for y in range(448,2688,16):
		var banks:=edges(y+8)
		var left:float=banks.x;var right:float=banks.y
		# The same 16px profile strips define water collision; the banks remain walkable.
		for patch in [[left-27,19,coping],[left-8,9,face],[right,9,face],[right+9,19,coping]]:
			canvas.draw_texture_rect_region(patch[2],Rect2(patch[0],y,patch[1],16),
				Rect2(0,y%32,patch[1],16),Color.WHITE,false,false)
		canvas.draw_rect(Rect2(left,y,2,16),Color(0.04,0.08,0.08,0.55))
		canvas.draw_rect(Rect2(right-2,y,2,16),Color(0.04,0.08,0.08,0.38))
	# shortcut: native static ripple texture, not fluid simulation or an animated water shader.
