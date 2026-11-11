@tool
extends "res://UI/TooltipButton.gd"

@export var artwork:Texture2D:
	set(value):artwork = value;queue_redraw()
@export var quantity := 0
@export var show_cooldown := true
var cooldown := 0.0
var cooldown_total := 3.0
var selected := false

func _ready() -> void:
	super._ready()
	theme_type_variation = "IconSlot"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not Engine.is_editor_hint():set_process(true)

func start_cooldown(seconds:float=3.0) -> void:
	if disabled or cooldown>0:return
	cooldown_total = maxf(seconds,.1);cooldown = cooldown_total;disabled = true;queue_redraw()

func _process(delta:float) -> void:
	if Engine.is_editor_hint():return
	if cooldown>0:
		cooldown = maxf(0,cooldown-delta)
		if cooldown<=0:disabled = false
		queue_redraw()

func _draw() -> void:
	var edge := minf(size.x,size.y)-16
	var rect := Rect2((size-Vector2.ONE*edge)/2,Vector2.ONE*edge)
	if artwork!=null:draw_texture_rect(artwork,rect,false,Color(.4,.42,.43) if disabled and cooldown<=0 else Color.WHITE)
	if selected:draw_rect(Rect2(Vector2(3,3),size-Vector2(6,6)),Color("e5c180"),false,2)
	if cooldown>0:
		draw_rect(Rect2(rect.position,Vector2(rect.size.x,ceilf(rect.size.y*cooldown/cooldown_total))),Color(0.03,.06,.08,.82))
		if show_cooldown:
			var value := str(ceili(cooldown));var font := get_theme_font("font")
			var width := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,24).x
			draw_string_outline(font,Vector2((size.x-width)/2,size.y/2+8),value,HORIZONTAL_ALIGNMENT_LEFT,-1,24,3,Color.BLACK)
			draw_string(font,Vector2((size.x-width)/2,size.y/2+8),value,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("fff0cc"))
	if quantity>0:draw_string(get_theme_font("font"),Vector2(size.x-38,size.y-10),str(quantity),HORIZONTAL_ALIGNMENT_RIGHT,28,18,Color("f5dfac"))
