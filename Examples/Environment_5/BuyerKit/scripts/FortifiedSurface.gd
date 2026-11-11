extends Node2D

@export var kind:String="floor"
@export var area:=Rect2()
@export var materials:Dictionary
@export var outer:=false
@export var outward_left:=true


func _draw() -> void:
	match kind:
		"floor":
			draw_texture_rect(materials.floor,area,true,materials.get("floor_tint",Color(0.90,0.94,0.98)))
		"body":
			draw_texture_rect(materials.body,area,true,Color.WHITE if materials.has("pier_cap") else Color(0.86,0.85,0.82))
			if materials.has("pier_cap"):
				draw_texture_rect(materials.cap,Rect2(area.position+Vector2(0,16),Vector2(area.size.x,12)),true,Color(0.80,0.80,0.77))
			else:
				draw_texture_rect(materials.body,Rect2(area.position+Vector2(0,area.size.y-16),Vector2(area.size.x,16)),true,Color(0.65,0.65,0.64))
			draw_rect(Rect2(area.position,Vector2(area.size.x,4)),Color(0.09,0.10,0.11,0.45))
		"side":
			draw_texture_rect(materials.side,area,true,Color(0.82,0.82,0.80))
		"guard_h":
			draw_texture_rect(materials.get("guard",materials.body),area,true)
			draw_texture_rect(materials.cap,Rect2(area.position,Vector2(area.size.x,8 if materials.has("pier_cap") else 6)),true)
			draw_rect(Rect2(Vector2(0,0),Vector2(area.size.x,3)),Color(0.08,0.09,0.10,0.24))
			if outer:
				var approved:bool=materials.has("pier_cap")
				for x in range(8,int(area.size.x)-(40 if approved else 16),96 if approved else 48):
					var merlon:=Rect2(Vector2(x,area.position.y-(24 if approved else 16)),Vector2(40 if approved else 24,24 if approved else 16))
					draw_texture_rect(materials.get("guard",materials.body),merlon,true)
					draw_texture_rect(materials.cap,Rect2(merlon.position,Vector2(24,5)),true)
					if approved:
						draw_texture_rect(materials.cap,Rect2(merlon.position,Vector2(40,6)),true)
						draw_rect(Rect2(merlon.position+Vector2(16,9),Vector2(7,15)),Color("262725"))
		"guard_pier":
			draw_rect(Rect2(area.position+Vector2(40,10),Vector2(7,area.size.y-10)),Color(0.07,0.08,0.08,0.26))
			draw_texture_rect(materials.pier_shaft,Rect2(area.position+Vector2(0,80),Vector2(44,72)),true)
			draw_texture_rect(materials.pier_cap,Rect2(area.position,Vector2(44,80)),true)
			draw_texture_rect(materials.pier_foot,Rect2(area.position+Vector2(0,152),Vector2(44,24)),true)
		"guard_v":
			draw_texture_rect(materials.side,area,true)
			if materials.has("pier_cap"):
				draw_rect(Rect2(area.position,Vector2(3,area.size.y)),Color(0.12,0.14,0.15,0.50))
				for y in range(int(area.position.y)+16,-16,192):
					draw_texture_rect(materials.cap,Rect2(Vector2(0,y),Vector2(area.size.x,10)),true)
			if outer:
				for y in range(int(area.position.y)+8,-16,48):
					var x:float=-5 if outward_left else area.size.x-3
					draw_texture_rect(materials.cap,Rect2(Vector2(x,y),Vector2(8,24)),true)
		"stair":
			draw_texture_rect(materials.body,area,true,Color(0.69,0.69,0.67))
			for y in range(int(area.position.y),0,12):
				var step:=Rect2(Vector2(5,y),Vector2(area.size.x-10,8))
				draw_texture_rect(materials.get("tread",materials.body),step,true,Color.WHITE if materials.has("tread") else Color(0.86,0.94,1.0))
				draw_rect(Rect2(step.position+Vector2(0,8),Vector2(step.size.x,3)),Color(0.15,0.16,0.16))
			var rail:Texture2D=materials.get("rail",materials.cap)
			var rail_width:float=10 if materials.has("rail") else 5
			draw_texture_rect(rail,Rect2(area.position,Vector2(rail_width,area.size.y)),true)
			draw_texture_rect(rail,Rect2(Vector2(area.size.x-rail_width,area.position.y),Vector2(rail_width,area.size.y)),true)
		"shadow":
			draw_rect(area,Color(0.07,0.08,0.08,0.22))
