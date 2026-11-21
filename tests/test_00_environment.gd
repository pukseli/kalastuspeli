extends "res://tests/test_case.gd"


func test_renderer_is_gl_compatibility() -> void:
	var rendering_method = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	assert_eq(rendering_method, "gl_compatibility", "rendering_method must be gl_compatibility")


func test_viewport_width_is_960() -> void:
	var viewport_width = ProjectSettings.get_setting("display/window/size/viewport_width")
	assert_eq(viewport_width, 960, "viewport_width must be 960")


func test_viewport_height_is_540() -> void:
	var viewport_height = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_eq(viewport_height, 540, "viewport_height must be 540")
