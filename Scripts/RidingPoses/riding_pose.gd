class_name RidingPose
extends Resource

@export_category("Velocidade")
@export var useBikeBlend : bool = true
@export var blendStartSpeed : float = 5.0
@export var blendFullSpeed : float = 25.0
@export var blendSmoothing : float = 4.0

@export_category("Assento")
@export var seatOffsetLow : Vector3 = Vector3(0, -0.95, 0)
@export var seatOffsetHigh : Vector3 = Vector3(0, -0.88, 0)

@export_category("Tronco")
@export var bendAxis : Vector3 = Vector3.RIGHT
@export var spineWeights : Array[float] = [0.7, 0.3, 0.0]
@export var spineBendLowDeg : float = 10.0
@export var spineBendHighDeg : float = 40.0
@export var pelvisTiltLowDeg : float = 0.0
@export var pelvisTiltHighDeg : float = 20.0
@export var headTiltLowDeg : float = -5.0
@export var headTiltHighDeg : float = -30.0
