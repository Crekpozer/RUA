extends RigidBody3D
class_name SportsBike

# Rodas
@export var wheels : Array[RaycastWheel] # Para registrar as rodas

# Configuração de Direção Arcade e Inclinação
@export_category("Direção Arcade")
@export var turnSpeed : float = 3.0
@export var leanAmount : float = 0.4
@export var steerSmoothing : float = 6.0
@export var lowSpeedTurnFactor : float = 0.0
@export var wheelbase : float = 1.4
@export var pathSteerRatio : float = 0.35
@export var maxLateralAccel : float = 9.0

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
@export var brakeForce : float = 6000.0
@export var brakeMinSpeed : float = 0.5
@export var maxReverseSpeed : float = 5.0
var forceAtGround : float = 3.0

@export_category("Guidão")
@export var handlebar : Node3D
@export var maxHandlebarAngle : float = 1.0
@export var handlebarSpeed : float = 10.0
@export var handlebarFadeSpeed : float = 20.0

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
	
	# Ângulo de direção, usado pelo guidão e pela curva
	var speedFade := 1.0 - clampf(absf(currentSpeed) / handlebarFadeSpeed, 0.0, 1.0) * 0.8
	var steerAngle := steerInput * maxHandlebarAngle * speedFade
	
	if grounded:
		var reverseSign := -1.0 if currentSpeed < -0.1 else 1.0
		
		# Giro pelo ângulo do guidão (na ré inverte sozinho, pelo sinal da velocidade)
		var rawTurnRate := currentSpeed * tan(steerAngle * pathSteerRatio) / wheelbase
		var turnLimit := maxLateralAccel / maxf(absf(currentSpeed), 1.0)
		directTurnRate = clampf(rawTurnRate, -turnLimit, turnLimit)
		
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
	
		if handlebar:
			handlebar.rotation.y = lerp_angle(handlebar.rotation.y, steerAngle, delta * handlebarSpeed)

# Calcula a velocidade relativa para aplicar o amortecimento
func GetPointVelocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_position)

func DoSingleWheelAcceleration(ray : RaycastWheel, delta : float) -> void:
	var forwardDirection := -ray.global_basis.z
	var wheelSpeed := forwardDirection.dot(linear_velocity)
	
	if ray.wheel:
		ray.wheel.rotate_x(-wheelSpeed * delta / ray.wheelRadius)
	
	if not ray.is_colliding():
		return
	
	var wheelCenter := ray.wheel.global_position if ray.wheel else ray.global_position
	var forcePoint := wheelCenter.lerp(ray.get_collision_point(), forceAtGround)
	var forcePosition := forcePoint - global_position
	
	# Freio: age em todas as rodas, contra o movimento
	if motorInput < 0.0 and wheelSpeed > brakeMinSpeed:
		var brakeVector := -forwardDirection * brakeForce * absf(motorInput) / wheels.size()
		apply_force(brakeVector, forcePosition)
		return
	
	# Motor: só a roda motriz
	if not ray.isMotor:
		return
	
	if motorInput != 0.0:
		# Limite da ré
		if motorInput < 0.0 and wheelSpeed < -maxReverseSpeed:
			return
		var speedRatio := clampf(wheelSpeed / maxSpeed, 0.0, 1.0)
		currentAccelerationForce = accelerationCurve.sample_baked(speedRatio)
		apply_force(forwardDirection * acceleration * motorInput * currentAccelerationForce, forcePosition)
	elif absf(wheelSpeed) > 0.02:
		apply_force(global_basis.z * deceleration * signf(wheelSpeed), forcePosition)

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
