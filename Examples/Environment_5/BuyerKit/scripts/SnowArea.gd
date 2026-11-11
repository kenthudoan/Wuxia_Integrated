extends Node2D

@export var exclusions:Array[PackedVector2Array]=[]
@export var snow_size:=Vector2(4096,3072)

func is_snow_at(point:Vector2) -> bool:
	if not Rect2(Vector2.ZERO,snow_size).has_point(point):return false
	for polygon in exclusions:
		if Geometry2D.is_point_in_polygon(point,polygon):return false
	return true

func bind_actor(actor:CharacterBody2D) -> void:
	var tracks:=Node2D.new();tracks.name="SnowFootprints"
	tracks.set_script(load("res://BuyerKit/scripts/SnowTracks.gd"))
	tracks.terrain=self;tracks.actor=actor;add_child(tracks)
