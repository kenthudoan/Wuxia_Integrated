extends CharacterBody2D

var sprite: Sprite2D
var matched_texture: Texture2D
var matched_anchor := Vector2.ZERO
var animated_sprite: AnimatedSprite2D
var animation_anchors: Dictionary = {}
var animation_enabled := true
var automated := false
var forced_direction := Vector2.ZERO
var facing := "south"
var speed_multiplier := 1.0
const DIRECTIONS := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]


func _physics_process(_delta: float) -> void:
    var direction := forced_direction if automated else Input.get_vector("move_left", "move_right", "move_up", "move_down")
    velocity = direction.normalized() * 180.0 * speed_multiplier
    move_and_slide()
    if animation_enabled:
        if not direction.is_zero_approx():
            facing = DIRECTIONS[posmod(roundi(direction.angle()/(PI/4.0)),8)]
        animated_sprite.position = -animation_anchors[facing]
        # Use actual travel: a held key against a wall does not keep walking in place.
        animated_sprite.play(("walk_" if get_real_velocity().length_squared()>1.0 else "idle_")+facing)


func set_animation_enabled(enabled: bool) -> void:
    animation_enabled = enabled
    sprite.visible = not enabled
    animated_sprite.visible = enabled
    if not enabled:
        animated_sprite.stop()
