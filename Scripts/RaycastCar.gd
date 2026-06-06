extends RigidBody3D
class_name SportsBike

# Rodas
@export var wheels : Array[RaycastWheel] # Para registrar as rodas


# Configuração de Direção Arcade e Inclinação
@export_category("Direção Arcade")
@export var gripStrength : float = 10.0
@export var turnSpeed : float = 3.0
@export var leanAmount : float = 0.4
@export var visualMesh : Node3D
@export var collisionShape : CollisionShape3D

var steerInput : float = 0.0
var headingAngle : float = 0.0 # Direção para onde está indo

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
	# Input direto de aceleração e freio
	if event.is_action_pressed("accelerate"):
		motorInput = 1
	elif  event.is_action_released("accelerate"):
		motorInput = 0
	
	if event.is_action_pressed("break"):
		motorInput = -1 # Faz o carro andar para atrás
	elif event.is_action_released("break"):
		motorInput = 0

func _physics_process(delta: float) -> void:
	# Reseta o grounded a cada frame antes de checar as rodas
	grounded = false
	
	# Configura o input de direção no frame fisíco para maior fluidez
	steerInput = Input.get_axis("steer_right","steer_left")
	
	for wheel in wheels:
		# Trava de segurança: Se o slot do array estiver vazio, pula
		# para a proxima roda
		if wheel == null: continue
		
		if wheel.is_colliding():
			grounded = true
		
		wheel.force_raycast_update()
		DoSingleWheelSuspension(wheel)
		DoSingleWheeelAcceleration(wheel)
	
	# Walaber's Rotação por Heading
	if grounded:
		# Acumula o angulo para onde a moto DEVE olhar
		headingAngle += steerInput * turnSpeed * delta
		# Força a rotação y do RigidBody a seguir o andgulo do hoverboard de forma absoluta
		rotation.y = headingAngle
	
	# Trava da velocidade em trilho
	if grounded:
		var forwardDirection := -global_basis.z
		# Calcula a velocidade puramente na direção qie a moto está apontando
		var forwardSpeed = linear_velocity.dot(forwardDirection)
		
		# Sobrescreve a velocidade linear do RigidBody.
		# Isso elimina 100% de qualquer força centrípeda ou deslizamento lateral.
		linear_velocity = forwardDirection * forwardSpeed
	
	# Inclinação visual
	if visualMesh or collisionShape:
		# O sinal negativo garante que ela deite para o lado interno da curva
		var targetRotationZ = -steerInput * leanAmount
		
		if visualMesh:
			visualMesh.rotation.z = lerp(visualMesh.rotation.z, targetRotationZ, delta * 10.0)
		if collisionShape:
			collisionShape.rotation.z = lerp(collisionShape.rotation.z, targetRotationZ, delta * 10.0)
	
	# Controle de massa
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
	
	if ray.wheel:
		ray.wheel.rotate_x(-velocity * get_process_delta_time() * 2 * PI * ray.wheelRadius)
	
	if ray.is_colliding() and ray.isMotor:
		var contact := ray.wheel.global_position
		var forcePosition := contact - global_position
		
		if motorInput != 0:
			var speedRatio := velocity / maxSpeed
			speedRatio = clampf(speedRatio, 0.0, 1.0)
			accelerationForce = accelerationCurve.sample_baked(speedRatio)
			var forceVector := forwardDirection * acceleration * motorInput * accelerationForce
			apply_force(forceVector, forcePosition)
		elif abs(velocity) > 0.02 and motorInput == 0:
			var dragForceVector = global_basis.z * deceleration * signf(velocity)
			apply_force(dragForceVector, forcePosition)

func DoSingleWheelSuspension(ray : RaycastWheel) -> void:
	
	if ray.is_colliding():
		ray.target_position.y = -(ray.restDistance + ray.wheelRadius + ray.overExtend)
		var contact := ray.get_collision_point()
		var springUpDirectional := ray.global_transform.basis.y
		var springLenth := ray.global_position.distance_to(contact) - ray.wheelRadius
		var offset := ray.restDistance - springLenth
		
		if ray.wheel:
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
