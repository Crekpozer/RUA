@tool
extends Node3D

func _ready() -> void:
	var skeleton := find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_reparent_bone(skeleton, "DEF-handfingers.L", "DEF-hand.L")
	_reparent_bone(skeleton, "DEF-handfingers.R", "DEF-hand.R")
	_reparent_bone(skeleton, "DEF-forearm.L.002", "DEF-hand.L")
	_reparent_bone(skeleton, "DEF-forearm.R.002", "DEF-hand.R")
	
	# Conferência: o pai dos dedos deve ser DEF-hand.L
	var i := skeleton.find_bone("DEF-handfingers.L")
	print("Pai dos dedos: ", skeleton.get_bone_name(skeleton.get_bone_parent(i)))

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
