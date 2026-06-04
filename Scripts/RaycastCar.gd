extends RigidBody3D
class_name SportsBike

# Rodas
# Lista de rodas
@export var wheels : Array[RaycastWheel] # Para registrar as rodas


# Configuração de Direção Arcade e Inclinação
@export_category("Direção Arcade")
@export var gripStrength : float = 10.0
@export var turnSpeed : float = 3.0
@export var leanAmount : float = 0.4
@export var visualMesh : Node3D
@export var collisionShape : CollisionShape3D
var steerInput : float = 0.0

# Configuração do Motor
@export_category("Motor")
@export var acceleration : float = 600.0
@export var deceleration : float = 200.0
@export var maxSpeed : float = 20.0 # 30m/s, 44m/h
@export var accelerationCurve : Curve

var accelerationForce : float
var motorInput : int = 0
var velocity : float
var grounded : bool = false

func _unhandled_input(event: InputEvent) -> void:
	
	if event.is_action_pressed("steer_left"):
		steerInput = 1.0
	elif event.is_action_pressed("steer_right"):
		steerInput = -1.0
	elif event.is_action_released("steer_left") or event.is_action_released("steer_right"):
		steerInput = Input.get_axis("steer_right", "steer_left")
	
	if event.is_action_pressed("accelerate"):
		motorInput = 1
	elif  event.is_action_released("accelerate"):
		motorInput = 0
	
	if event.is_action_pressed("break"):
		motorInput = -1 # Faz o carro andar para atrás
	elif event.is_action_released("break"):
		motorInput = 0

func _physics_process(_delta: float) -> void:
	# Reseta o grounded a cada frame antes de checar as rodas
	grounded = false
	
	for wheel in wheels:
		# Trava de segurança: Se o slot do array estiver vazio, pula
		# para a proxima roda
		if wheel == null: continue
		
		if wheel.is_colliding():
			grounded = true
		
		wheel.force_raycast_update()
		DoSingleWheelSuspension(wheel)
		DoSingleWheeelAcceleration(wheel)
		ApplyLateralFriction()
	
	if grounded:
		# Gira a moto direto no eixo Y (arcade puro)
		apply_torque(Vector3(0, steerInput * turnSpeed * mass, 0))
	
	if grounded:
		center_of_mass = Vector3.ZERO
	else:
		center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		center_of_mass = Vector3.ZERO * 0.5

# Calcula a velocidade relativa para aplicar o amortecimento
func GetPointVelocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)

func DoSingleWheeelAcceleration(ray : RaycastWheel) -> void:
	
	var forwardDirection := -ray.global_basis.z
	velocity = forwardDirection.dot(linear_velocity)
	# tamanho da roda = 2 * pi * r
	ray.wheel.rotate_x(-velocity * get_process_delta_time() * 2 * PI * ray.wheelRadius)
	
	if ray.is_colliding() and ray.isMotor:
		var contact := ray.wheel.global_position
		var forcePosition := contact - global_position
		
		
		if ray.isMotor and motorInput:
			var speedRatio := velocity / maxSpeed
			accelerationForce = accelerationCurve.sample_baked(speedRatio)
			var forceVector := forwardDirection * acceleration * motorInput * accelerationForce
			apply_force(forceVector, forcePosition)
		elif abs(velocity) > 0.02 and not motorInput:
			var dragForceVector = global_basis.z * deceleration * signf(velocity)
			apply_force(dragForceVector, forcePosition)

func DoSingleWheelSuspension(ray : RaycastWheel) -> void:
	
	if ray.is_colliding():
		
		ray.target_position.y = -(ray.restDistance + ray.wheelRadius + ray.overExtend)
		var contact := ray.get_collision_point()
		# Vetor que aponta para cima da pespectiva da roda
		var springUpDirectional := ray.global_transform.basis.y
		# Posição da mola
		var springLenth := ray.global_position.distance_to(contact) - ray.wheelRadius
		var offset := ray.restDistance - springLenth
		
		ray.wheel.position.y = -springLenth
		
		var springForce := ray.springStrength * offset
		
		# Força do amortecedor = amortecedor * velocidade relativa
		var worldVelocity := GetPointVelocity(contact)
		var relativeVelocity := springUpDirectional.dot(worldVelocity)
		var springDampForce := ray.springDamping * relativeVelocity
		
		var forceVector := (springForce - springDampForce) * ray.get_collision_normal()
		
		contact = ray.wheel.global_position # Altera a posição do ponto de contato para o centro da roda
		var forcePositionOffset := contact - global_position
		apply_force(forceVector, forcePositionOffset)

func ApplyLateralFriction() -> void:
	# Pega o vetor que apronta para a direita da moto
	var rightDirectional = global_transform.basis.x
	
	# Calcula a velocidade que a moto está deslizando de lado
	var lateralVelocity = rightDirectional.dot(linear_velocity)
	
	# Aplica uma força contraria para segurar as rodas no asfalto
	var gripForce = -rightDirectional * lateralVelocity * mass * gripStrength
	apply_central_force(gripForce)
