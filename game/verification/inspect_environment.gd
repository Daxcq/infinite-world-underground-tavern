extends SceneTree
func _initialize() -> void:
	for key: String in ClassDB.class_get_integer_constant_list("Environment"):
		if key.contains("REFLECT"): print(key, "=", ClassDB.class_get_integer_constant("Environment",key))
	quit()
