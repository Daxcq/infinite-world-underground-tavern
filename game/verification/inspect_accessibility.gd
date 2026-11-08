extends SceneTree
func _initialize() -> void:
	var button := Button.new()
	for field: Dictionary in button.get_property_list():
		if String(field.name).begins_with("accessibility"): print(field.name)
	button.free()
	quit()
