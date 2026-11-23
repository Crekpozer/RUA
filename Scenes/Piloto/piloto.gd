extends Node3D

@export var bike : SportsBike

# nome do marcador na moto -> nome do marcador no piloto
const MAP := {
	"HandL": "TargetHandL",
	"HandR": "TargetHandR",
	"FootL": "TargetFootL",
	"FootR": "TargetFootR",
	"KneeL": "PoleKneeL",
	"KneeR": "PoleKneeR",
	"ElbowL": "PoleElbowL",
	"ElbowR": "PoleElbowR",
}

var seat : Node3D
var pairs : Array = []
var skeleton : Skeleton3D
var spineBones : Array[int] = []
var headBone : int = -1
var pelvisBone : int = -1
var speedBlend : float = 0.0

func _ready() -> void:
	skeleton = find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for boneName in ["DEF-spine.001", "DEF-spine.002", "DEF-spine.003"]:
		spineBones.append(skeleton.find_bone(boneName))
	headBone = skeleton.find_bone("DEF-spine.006")
	pelvisBone = skeleton.find_bone("DEF-spine")
	
	if bike == null:
		push_warning("Piloto: o campo Bike não foi atribuído")
		return
	seat = bike.find_child("Seat", true, false) as Node3D
	for bikeName in MAP:
		var source := bike.find_child(bikeName, true, false) as Node3D
		var target := get_node_or_null(MAP[bikeName]) as Node3D
		if source == null or target == null:
			push_warning("Piloto: marcador não encontrado (%s ou %s)" % [bikeName, MAP[bikeName]])
			continue
		pairs.append([source, target])

func _process(delta: float) -> void:
	if bike == null or bike.ridingPose == null:
		return
	var pose := bike.ridingPose
	
	# Mistura baixa/alta velocidade: usa o medidor da moto ou os limites do arquivo
	var target := bike.handlingBlend if pose.useBikeBlend else clampf(inverse_lerp(pose.blendStartSpeed, pose.blendFullSpeed, absf(bike.currentSpeed)), 0.0, 1.0)
	speedBlend = lerpf(speedBlend, target, 1.0 - exp(-pose.blendSmoothing * delta))
	
	if seat:
		var offset := pose.seatOffsetLow.lerp(pose.seatOffsetHigh, speedBlend)
		global_transform = seat.global_transform * Transform3D(Basis.IDENTITY, offset)
	for pair in pairs:
		pair[1].global_transform = pair[0].global_transform
	_apply_posture(pose)

func _apply_posture(pose : RidingPose) -> void:
	var axis := pose.bendAxis.normalized()
	var total := deg_to_rad(lerpf(pose.spineBendLowDeg, pose.spineBendHighDeg, speedBlend))
	for i in spineBones.size():
		var b := spineBones[i]
		if b >= 0:
			var weight := pose.spineWeights[i] if i < pose.spineWeights.size() else 0.0
			skeleton.set_bone_pose_rotation(b, Quaternion(axis, total * weight))
	if headBone >= 0:
		var headDeg := lerpf(pose.headTiltLowDeg, pose.headTiltHighDeg, speedBlend)
		skeleton.set_bone_pose_rotation(headBone, Quaternion(axis, deg_to_rad(headDeg)))
	
	if pelvisBone >= 0:
		var pelvisDeg := lerpf(pose.pelvisTiltLowDeg, pose.pelvisTiltHighDeg, speedBlend)
		skeleton.set_bone_pose_rotation(pelvisBone, Quaternion(axis, deg_to_rad(pelvisDeg)))
