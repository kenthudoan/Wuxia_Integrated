extends CharacterBody2D

var forced:=Vector2.ZERO
var automated:=false

func _physics_process(_delta:float) -> void:
	var direction:=forced if automated else Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	velocity=direction.normalized()*135;move_and_slide()

func _draw() -> void:
	draw_circle(Vector2(0,-7),10,Color("e4c479"));draw_arc(Vector2(0,-7),10,0,TAU,24,Color("34301e"),2)
