@tool
extends Node3D

const NEW_PARENTS := {
	"DEF-pelvis.L": "DEF-spine",
	"DEF-pelvis.R": "DEF-spine",
	"DEF-thigh.L": "DEF-pelvis.L",
	"DEF-thigh.R": "DEF-pelvis.R",
	"DEF-breast.L": "DEF-spine.003",
	"DEF-breast.R": "DEF-spine.003",
	"DEF-shoulder.L": "DEF-spine.003",
	"DEF-shoulder.R": "DEF-spine.003",
	"DEF-upper_arm.L": "DEF-shoulder.L",
	"DEF-upper_arm.R": "DEF-shoulder.R",
	"DEF-handfingers.L": "DEF-hand.L",
	"DEF-handfingers.R": "DEF-hand.R",
	"DEF-forearm.L.002": "DEF-hand.L",
	"DEF-forearm.R.002": "DEF-hand.R",
}

func _ready() -> void:
	var skeleton := find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for boneName in NEW_PARENTS:
		_reparent_bone(skeleton, boneName, NEW_PARENTS[boneName])
	for boneName in NEW_PARENTS:
		var i := skeleton.find_bone(boneName)
		if i >= 0:
			print(boneName, " -> pai: ", skeleton.get_bone_name(skeleton.get_bone_parent(i)))

func _reparent_bone(skeleton : Skeleton3D, boneName : String, newParentName : String) -> void:
	var bone := skeleton.find_bone(boneName)
	var newParent := skeleton.find_bone(newParentName)
	if bone < 0 or newParent < 0:
		push_warning("Osso não encontrado: %s ou %s" % [boneName, newParentName])
		return
	var globalRest := skeleton.get_bone_global_rest(bone)
	skeleton.set_bone_parent(bone, newParent)
	skeleton.set_bone_rest(bone, skeleton.get_bone_global_rest(newParent).affine_inverse() * globalRest)
	skeleton.reset_bone_pose(bone)
