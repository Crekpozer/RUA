extends RayCast3D
class_name RaycastWheel

@export var springStrength : float  = 3000.0 # Força da mola
@export var springDamping : float = 100.0 # força dop amortecedor
@export var restDistance : float = 0.3 # Posição de descanço da mola
@export var overExtend : float = 0.1 # Empurrão da mola em direção ao chão
@export var wheelRadius : float = 0.4 # Tamanho da roda

@export var isMotor : bool = false # Indica se a roda impulsiona o carro ou não


@onready var wheel : Node3D = get_child(0) # Pega o primeiro filho na lista, a roda
