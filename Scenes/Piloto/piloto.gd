extends Node3D

func _ready() -> void:
	var skeleton := find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for boneName in ["DEF-hand.L", "DEF-handfingers.L", "DEF-handfingers.L.001", "DEF-handfingers.L.002", "DEF-forearm.L.002", "DEF-forearm.L.003", "DEF-forearm.L.004"]:
		var boneIndex := skeleton.find_bone(boneName)
		var parentIndex := skeleton.get_bone_parent(boneIndex)
		print(boneName, " -> pai: ", skeleton.get_bone_name(parentIndex) if parentIndex >= 0 else "nenhum")
