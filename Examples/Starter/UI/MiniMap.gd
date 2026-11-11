@tool
extends Control

var player_position := Vector2(1616,2192)
var markers:Array = []
@export var use_town_markers := true

func _ready() -> void:
	custom_minimum_size = custom_minimum_size.max(Vector2(240,180))
	if use_town_markers and FileAccess.file_exists("res://UI/map.json"):markers = JSON.parse_string(FileAccess.get_file_as_string("res://UI/map.json")).markers
	queue_redraw()

func _draw() -> void:
	var fitted := Vector2(minf(size.x-24,(size.y-24)*4.0/3.0),size.y-24)
	fitted.y = fitted.x*3.0/4.0
	var area := Rect2((size-fitted)/2,fitted)
	draw_rect(area,Color("3c493a"))
	var scale_xy := area.size/Vector2(4096,3072)
	for rect in [Rect2(1800,0,400,3072),Rect2(0,1320,4096,360)]:
		draw_rect(Rect2(area.position+rect.position*scale_xy,rect.size*scale_xy),Color("927e59"))
	for marker in markers:
		var at := area.position+Vector2(marker.position[0],marker.position[1])*scale_xy
		draw_rect(Rect2(at.round()-Vector2(6,5),Vector2(12,10)),Color("c6b081"))
	var player := (area.position+player_position*scale_xy).round()
	draw_rect(Rect2(player-Vector2(4,4),Vector2(8,8)),Color("eddfaa"));draw_rect(Rect2(player-Vector2(7,7),Vector2(14,14)),Color("f0bc67"),false,2)
