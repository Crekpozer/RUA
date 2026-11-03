extends Node3D

@onready var target : Node3D = %SportsBike
@export var followSpeed : float = 6.0

func _process(delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, target.rotation.y, delta * followSpeed)
