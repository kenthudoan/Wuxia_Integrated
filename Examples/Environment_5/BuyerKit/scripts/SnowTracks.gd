extends Node2D

const STEP_DISTANCE=22.0
const HOLD_SECONDS=8.0
const FADE_SECONDS=4.0
const MAX_MARKS=256
const SOLE=[Vector2(-6,-2),Vector2(-4,-3),Vector2(3,-3),Vector2(6,-2),Vector2(7,0),Vector2(6,2),Vector2(3,3),Vector2(-4,3),Vector2(-6,2)]
var terrain:Node2D
var actor:CharacterBody2D
var marks:Array[Dictionary]=[]
var clock:=0.0
var previous:=Vector2.ZERO
var stride:=0.0
var left_foot:=true


func _ready() -> void:
	z_index=-6
	previous=terrain.to_local(actor.global_position)
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta:float) -> void:
	clock+=delta
	var changed:=not marks.is_empty()
	while not marks.is_empty() and clock-float(marks[0].born)>=HOLD_SECONDS+FADE_SECONDS:
		marks.pop_front()
	var current:=terrain.to_local(actor.global_position)
	var travel:=current-previous
	var distance:=travel.length()
	# Teleports and scene transitions must not draw a trail across the map.
	if distance>64.0:
		stride=0.0;left_foot=true
	elif distance>0.01:
		var direction:=travel/distance
		var cursor:=previous
		var remaining:=STEP_DISTANCE-stride
		while distance>=remaining:
			cursor+=direction*remaining;distance-=remaining
			stamp(cursor,direction)
			stride=0.0;remaining=STEP_DISTANCE
		stride+=distance
	previous=current
	if changed or not marks.is_empty():queue_redraw()


func stamp(at:Vector2,direction:Vector2) -> void:
	var angle:=snappedf(direction.angle(),PI/4.0)
	var forward:=Vector2.RIGHT.rotated(angle)
	var side:=Vector2(-forward.y,forward.x)
	var point:Vector2=(at+side*(-5.0 if left_foot else 5.0)).round()
	left_foot=not left_foot
	for sample in [point,point+forward*8,point-forward*7,point+side*5,point-side*5]:
		if not terrain.is_snow_at(sample):return
	marks.append({"position":point,"angle":angle,"born":clock,"left":not left_foot})
	if marks.size()>MAX_MARKS:marks.pop_front()


func opacity(mark:Dictionary) -> float:
	return clampf(1.0-(clock-float(mark.born)-HOLD_SECONDS)/FADE_SECONDS,0.0,1.0)


func _draw() -> void:
	for mark in marks:
		var alpha:=opacity(mark)
		var outline:=PackedVector2Array()
		for vertex in SOLE:outline.append((vertex.rotated(mark.angle)+mark.position).round())
		draw_colored_polygon(outline,Color(0.54,0.64,0.7,alpha*0.74))
		var hollow:=PackedVector2Array()
		for vertex in SOLE:hollow.append(((vertex*Vector2(0.78,0.6)+Vector2(0,-1)).rotated(mark.angle)+mark.position).round())
		draw_colored_polygon(hollow,Color(0.68,0.77,0.81,alpha*0.86))
		var rim:=PackedVector2Array()
		for vertex in [Vector2(-5,3),Vector2(3,4),Vector2(6,2)]:rim.append((vertex.rotated(mark.angle)+mark.position).round())
		draw_polyline(rim,Color(0.98,0.99,0.97,alpha*0.9),2.0,false)
