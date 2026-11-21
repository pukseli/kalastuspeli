extends SceneTree


func _initialize() -> void:
	var test_files: Array[String] = []
	for file_name in DirAccess.get_files_at("res://tests/"):
		if file_name.begins_with("test_") and file_name.ends_with(".gd") and file_name != "test_case.gd":
			test_files.append(file_name)
	test_files.sort()

	var total_tests := 0
	var failed_tests := 0

	for file_name in test_files:
		var script: GDScript = load("res://tests/" + file_name)
		var inst = script.new()
		var method_names: Array[String] = []
		for method_info in script.get_script_method_list():
			var method_name: String = method_info["name"]
			if method_name.begins_with("test_"):
				method_names.append(method_name)
		method_names.sort()

		for method_name in method_names:
			total_tests += 1
			var before_count: int = inst.failures.size()
			inst.call(method_name)
			if inst.failures.size() == before_count:
				print("[PASS] %s::%s" % [file_name, method_name])
			else:
				failed_tests += 1
				for i in range(before_count, inst.failures.size()):
					print("[FAIL] %s::%s: %s" % [file_name, method_name, inst.failures[i]])

	print("[SUMMARY] %d tests, %d failed" % [total_tests, failed_tests])
	if failed_tests > 0 or total_tests == 0:
		quit(1)
	else:
		quit(0)
