extends CharacterBody2D


const SPEED = 100.0
const JUMP_VELOCITY = -400.0
var animation_follow := "down"
var animation_stat := "idle"

@export var attack_state := false
var is_attack := false

@onready var animated_spirte_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	animated_spirte_2d.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	
func _physics_process(_delta: float) -> void:
	if is_attack:
		return
	var input_direction = Input.get_vector("left","right","up","down")
	velocity = input_direction * SPEED
	if Input.is_action_just_pressed("attack"):
		is_attack = true
		update_animation(Vector2.ZERO)
		return
		
	move_and_slide()
	update_animation(input_direction)
	
	
func update_animation(input_direction:Vector2) -> void:
	if input_direction.x > 0:
		animation_follow = "right"
	elif input_direction.x < 0:
		animation_follow = "left"
	elif input_direction.y > 0:
		animation_follow = "down"
	elif input_direction.y < 0:
		animation_follow = "up"
	
	if is_attack:
			animation_stat = "attack"
	else:
		if input_direction == Vector2.ZERO:
			animation_stat = "idle"
		else:
			animation_stat = "run"
	
	animated_spirte_2d.play(animation_stat+"_"+animation_follow)
	
	pass


func _on_animated_sprite_2d_animation_finished() -> void:
	is_attack = false
	pass # Replace with function body.
