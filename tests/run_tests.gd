extends SceneTree

func _init() -> void:
	print("[TEST] Starting headless test runner...")
	var failed := false

	var rendering_method = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	if rendering_method != "gl_compatibility":
		print("[FAIL] Expected rendering/renderer/rendering_method == 'gl_compatibility', got: %s" % str(rendering_method))
		failed = true

	var viewport_width = ProjectSettings.get_setting("display/window/size/viewport_width")
	if viewport_width != 960:
		print("[FAIL] Expected display/window/size/viewport_width == 960, got: %s" % str(viewport_width))
		failed = true

	var viewport_height = ProjectSettings.get_setting("display/window/size/viewport_height")
	if viewport_height != 540:
		print("[FAIL] Expected display/window/size/viewport_height == 540, got: %s" % str(viewport_height))
		failed = true

	if failed:
		quit(1)
		return

	print("[PASS] Slice 0 environment & project settings verified.")
	quit(0)
