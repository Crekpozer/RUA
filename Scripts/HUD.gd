extends CanvasLayer

@onready var vehicle : SportsBike = %SportsBike
@onready var motorInputText : Label = %MotorInputLabelText
@onready var groundedText : Label = %GroundedLabelText
@onready var accelerationText : Label = %AccelerationLabelText
@onready var velocityText : Label = %VelocityLabelText
@onready var leanLeftBar : ProgressBar = %LeanLeftBar
@onready var leanRightBar : ProgressBar = %LeanRightBar
@onready var turnRatioBar : ProgressBar = %TurnRatioBar

func _process(_delta: float) -> void:
	motorInputText.text = str(vehicle.motorInput)
	groundedText.text = "Sim" if vehicle.grounded else "Não"
	accelerationText.text = "%.1f" % vehicle.currentAccelerationForce
	velocityText.text = "%.1f" % (vehicle.currentSpeed * 3.6)
	
	var rollDeg := rad_to_deg(vehicle.rotation.z)
	leanLeftBar.value = maxf(rollDeg, 0.0)
	leanRightBar.value = maxf(-rollDeg, 0.0)
	
	turnRatioBar.value = vehicle.leanBlend
