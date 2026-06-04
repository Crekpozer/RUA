extends CanvasLayer

# Objetos
# Carro
var vehicleReference : SportsBike

# Interface
# Estatistica
var motorInputValue : Label
var accelerationValue
var accelerationValueLabel : Label
var formatedAcceleration : String
var kmVelocityValue
var kmVelocityValueLable : Label
var formatedVelocity : String
var msVelocity


func _ready() -> void:
	vehicleReference = %SportsBike
	motorInputValue = %MotorInputLabelText
	accelerationValueLabel = %AccelerationLabelText
	kmVelocityValueLable = %VelocityLabelText

func _process(_delta: float) -> void:
	motorInputValue.text = str(vehicleReference.motorInput)
	accelerationValue = vehicleReference.accelerationForce
	formatedAcceleration = "%.1f" %accelerationValue
	accelerationValueLabel.text = formatedAcceleration
	
	# Atualizar velocidade de m/s em km/h
	msVelocity = vehicleReference.velocity
	kmVelocityValue = msVelocity * 3.6
	formatedVelocity = "%.1f" %kmVelocityValue
	kmVelocityValueLable.text = formatedVe