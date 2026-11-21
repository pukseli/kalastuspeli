extends RefCounted

var failures: Array[String] = []


func assert_true(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func assert_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])


func assert_almost_eq(actual: float, expected: float, eps: float, msg: String) -> void:
	if absf(actual - expected) > eps:
		failures.append("%s (expected %s +/- %s, got %s)" % [msg, str(expected), str(eps), str(actual)])


func free_node(node: Node) -> void:
	if node == null:
		return
	_clear_meshes_recursive(node)
	node.free()


func _clear_meshes_recursive(node: Node) -> void:
	for child in node.get_children():
		_clear_meshes_recursive(child)
	if node is MeshInstance3D:
		(node as MeshInstance3D).mesh = null
