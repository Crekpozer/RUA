extends RigidBody3D
class_name SportsBike

# Rodas
@export var wheels : Array[RaycastWheel] # Para registrar as rodas

# Configuração de Direção Arcade e Inclinação
@export_category("Direção Arcade")
@export var turnSpeed : float = 3.0
@export var leanAmount : float = 0.4
@export var steerSmoothing : float = 6.0
@export var lowSpeedTurnFactor : float = 0.8

@export var visualMesh : Node3D
@export var collisionShape : CollisionShape3D

@export_category("Estabilização")
@export var rollStiffness : float = 7000.0
@export var rollDamping : float = 2000.0

@export_category("Curva pela inclinação")
@export var leanTurnInfluence : float = 1.0
@export var blendStartSpeed : float = 4.0
@export var blendFullSpeed : float = 10.0
@export var leanTurnGain : float = 4.0

var steerInput : float = 0.0
var headingAngle : float = 0.0 # Direção para onde está indo

# Configuração do Motor
@export_category("Motor")
@export var acceleration : float = 600.0
@export var deceleration : float = 200.0
@export var maxSpeed : float = 20.0 # 20 m/s = 72 km/h
@export var accelerationCurve : Curve

var currentAccelerationForce : float = 0.0
var motorInput : float = 0.0
var currentSpeed : float = 0.0
var grounded : bool = false
var directTurnRate : float = 0.0
var leanTurnRate : float = 0.0
var leanBlend : float = 0.0

func _ready() -> void:
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.2, 0)

func _physics_process(delta: float) -> void:
	
	# Reseta o grounded a cada frame antes de checar as rodas
	grounded = false
	
	currentSpeed = linear_velocity.dot(-global_basis.z)
	currentAccelerationForce = 0.0
	
	motorInput = Input.get_axis("break", "accelerate")
	steerInput = Input.get_axis("steer_right","steer_left")
	
	# Configura o input de direção no frame fisíco para maior fluidez
	var rawSteerInput := Input.get_axis("steer_right","steer_left")
	steerInput = move_toward(steerInput, rawSteerInput, steerSmoothing * delta)
	
	for wheel in wheels:
		# Trava de segurança: Se o slot do array estiver vazio, pula
		# para a proxima roda
		if wheel == null: continue
		
		wheel.force_raycast_update()
		
		if wheel.is_colliding():
			grounded = true
		
		DoSingleWheelSuspension(wheel)
		DoSingleWheelAcceleration(wheel, delta)
	
	if grounded:
		var speedFactor := lerpf(lowSpeedTurnFactor, 1.0, clampf(absf(currentSpeed) / 5.0, 0.0, 1.0))
		var reverseSign := -1.0 if currentSpeed < -0.1 else 1.0
		
		# Giro direto pelo código, em rad/s
		directTurnRate = steerInput * turnSpeed * speedFactor * reverseSign
		# Giro que a inclinação real do corpo produziria, em rad/s
		leanTurnRate = 9.8 * tan(rotation.z) / maxf(absf(currentSpeed), 1.0)
		# Quanto a inclinação comanda a curva (0 a 1)
		leanBlend = clampf(inverse_lerp(blendStartSpeed, blendFullSpeed, absf(currentSpeed)), 0.0, 1.0) * leanTurnInfluence
		
		var finalTurnRate := lerpf(directTurnRate, leanTurnRate * leanTurnGain * reverseSign, leanBlend)
		headingAngle += finalTurnRate * delta
		rotation.y = headingAngle
	else:
		headingAngle = rotation.y
	
	# Trava da velocidade em trilho
	# Trava da velocidade em trilho (mantém a velocidade vertical)
	if grounded:
		var rightDirection := Vector3.RIGHT.rotated(Vector3.UP, rotation.y)
		
		var leanSpeedFactor := clampf(absf(currentSpeed) / maxSpeed, 0.0, 1.0)
		var targetRoll := steerInput * leanAmount * leanSpeedFactor
		var rollError := targetRoll - rotation.z
		var rollSpeed := angular_velocity.dot(global_basis.z)
		var rollTorque := rollStiffness * rollError - rollDamping * rollSpeed
		apply_torque(global_basis.z * rollTorque)
		
		linear_velocity -= rightDirection * linear_velocity.dot(rightDirection)


# Calcula a velocidade relativa para aplicar o amortecimento
func GetPointVelocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)

func DoSingleWheelAcceleration(ray : RaycastWheel, delta : float) -> void:
	var forwardDirection := -ray.global_basis.z
	var wheelSpeed := forwardDirection.dot(linear_velocity)
	
	if ray.wheel:
				ray.wheel.rotate_x(-wheelSpeed * delta / ray.wheelRadius)
	
	if ray.is_colliding() and ray.isMotor:
		var contact := ray.wheel.global_position
		var forcePosition := contact - global_position
		
		if motorInput != 0:
			var speedRatio := wheelSpeed / maxSpeed
			speedRatio = clampf(speedRatio, 0.0, 1.0)
			currentAccelerationForce = accelerationCurve.sample_baked(speedRatio)
			var forceVector := forwardDirection * acceleration * motorInput * currentAccelerationForce
			apply_force(forceVector, forcePosition)
		elif abs(wheelSpeed) > 0.02 and motorInput == 0:
			var dragForceVector = global_basis.z * deceleration * signf(wheelSpeed)
			apply_force(dragForceVector, forcePosition)

func DoSingleWheelSuspension(ray : RaycastWheel) -> void:
	
	if ray.is_colliding():
		var contact := ray.get_collision_point()
		var springUpDirection := ray.global_transform.basis.y
		var springLength := ray.global_position.distance_to(contact) - ray.wheelRadius
		var offset := ray.restDistance - springLength
		
		if ray.wheel:
			ray.wheel.position.y = -springLength
		
		var springForce := maxf(ray.springStrength * offset, 0.0)
		
		# Força do amortecedor = amortecedor * velocidade relativa
		var worldVelocity := GetPointVelocity(contact)
		var relativeVelocity := springUpDirection.dot(worldVelocity)
		var springDampForce := ray.springDamping * relativeVelocity
		
		var forceVector := (springForce - springDampForce) * springUpDirection
		
		contact = ray.wheel.global_position # Altera a posição do ponto de contato para o centro da roda
		var forcePositionOffset := contact - global_position
		apply_force(forceVector, forcePositionOffset)
		
	elif ray.wheel:
		ray.wheel.position.y = lerpf(ray.wheel.position.y, -(ray.restDistance + ray.overExtend), 0.8)
