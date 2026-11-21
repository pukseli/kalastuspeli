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
