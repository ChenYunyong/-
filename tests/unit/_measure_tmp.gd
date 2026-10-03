## 临时校验脚本（本批用完即删，不入版本库）。
extends SceneTree


func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/preparation/preparation.tscn")
	print("PACKED=", packed)
	if packed == null:
		quit(1)
		return
	var scene: Node = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for name: String in ["RegionLeft", "RegionCenter", "RegionRight", "RegionBottom", "RegionAction"]:
		var node: Control = scene.find_child(name, true, false) as Control
		print("%s pos=%s size=%s visible=%s filter=%d" % [name, node.position, node.size, node.visible, node.mouse_filter])
	var button: Button = scene.find_child("ButtonStartCombat", true, false) as Button
	print("BUTTON pos=%s size=%s min=%s variation=%s text=%s" % [
		button.position, button.size, button.get_combined_minimum_size(), button.theme_type_variation, button.text])
	print("NARROW_BEFORE=", scene.call(&"is_narrow_layout"))
	scene.call(&"apply_layout_for", Vector2(180.0, 320.0))
	print("NARROW_AFTER=", scene.call(&"is_narrow_layout"))
	for name: String in ["RegionLeft", "RegionCenter", "RegionRight", "RegionBottom", "RegionAction"]:
		var node: Control = scene.find_child(name, true, false) as Control
		print("N %s pos=%s size=%s visible=%s" % [name, node.position, node.size, node.visible])
	print("N BUTTON pos=%s size=%s" % [button.position, button.size])
	scene.call(&"apply_layout_for", Vector2(320.0, 180.0))
	print("WIDE_AGAIN=", scene.call(&"is_narrow_layout"))
	print("W BUTTON pos=%s size=%s" % [button.position, button.size])
	var left: Control = scene.find_child("RegionLeft", true, false) as Control
	print("W LEFT filter=", left.mouse_filter)
	quit(0)
