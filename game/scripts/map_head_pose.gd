extends SkeletonModifier3D
## A small upward gaze keeps faces readable under the fixed RPG map camera.

var head: int = -1


func _ready() -> void:
	head = get_skeleton().find_bone("Head")


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	var pose := skeleton.get_bone_global_pose(head)
	pose.basis = Basis(Vector3.BACK, 0.42) * pose.basis
	skeleton.set_bone_global_pose(head, pose)
