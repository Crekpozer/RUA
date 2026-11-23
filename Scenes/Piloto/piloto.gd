extends Node3D

@export var bike : Node3D

@export_category("Postura")
@export var seatOffset : Vector3 = Vector3(0, -0.95, 0)
@export var bendAxis : Vector3 = Vector3.RIGHT
@export var spineWeights : Array[float] = [0.7, 0.3, 0.0]
@export_range(-90, 90) var spineBendDeg : float = 25.0
@export_range(-60, 60) var headTiltDeg : float = -15.0

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

func _ready() -> void:
	skeleton = find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for boneName in ["DEF-spine.001", "DEF-spine.002", "DEF-spine.003"]:
		spineBones.append(skeleton.find_bone(boneName))
	headBone = skeleton.find_bone("DEF-spine.006")
	
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

func _process(_delta: float) -> void:
	if seat:
		global_transform = seat.global_transform * Transform3D(Basis.IDENTITY, seatOffset)
	for pair in pairs:
		pair[1].global_transform = pair[0].global_transform
	_apply_posture()

func _apply_posture() -> void:
	var axis := bendAxis.normalized()
	var total := deg_to_rad(spineBendDeg)
	for i in spineBones.size():
		var b := spineBones[i]
		if b >= 0:
			var weight := spineWeights[i] if i < spineWeights.size() else 0.0
			skeleton.set_bone_pose_rotation(b, Quaternion(axis, total * weight))
	if headBone >= 0:
		skeleton.set_bone_pose_rotation(headBone, Quaternion(axis, deg_to_rad(headTiltDeg)))
