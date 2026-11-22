extends "res://tests/test_case.gd"

const MainScript = preload("res://src/main.gd")


func test_alt_f4_matches_quit_shortcut_and_requests_quit() -> void:
	var ev_keycode := InputEventKey.new()
	ev_keycode.keycode = KEY_F4
	ev_keycode.alt_pressed = true
	ev_keycode.pressed = true
	assert_true(MainScript.is_quit_shortcut(ev_keycode), "Alt+F4 via keycode matches quit shortcut")

	var ev_physical := InputEventKey.new()
	ev_physical.physical_keycode = KEY_F4
	ev_physical.alt_pressed = false
	ev_physical.pressed = true
	assert_true(MainScript.is_quit_shortcut(ev_physical, true), "Alt+F4 via physical_keycode and alt_held matches quit shortcut")

	var ev_shift := InputEventKey.new()
	ev_shift.keycode = KEY_F4
	ev_shift.alt_pressed = true
	ev_shift.shift_pressed = true
	ev_shift.pressed = true
	assert_true(MainScript.is_quit_shortcut(ev_shift), "Alt+F4 works even when Shift (let-out) is held")

	var main: Node = MainScript.new()
	main._input(ev_keycode)
	assert_true(main._quitting, "Alt+F4 in _input sets _quitting on Main")
	free_node(main)

	var main_wm: Node = MainScript.new()
	main_wm._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_true(main_wm._quitting, "NOTIFICATION_WM_CLOSE_REQUEST sets _quitting on Main")
	free_node(main_wm)


func test_non_quit_events_do_not_trigger_quit() -> void:
	var plain_f4 := InputEventKey.new()
	plain_f4.keycode = KEY_F4
	plain_f4.pressed = true
	assert_true(not MainScript.is_quit_shortcut(plain_f4), "Plain F4 without Alt does not quit")

	var released_alt_f4 := InputEventKey.new()
	released_alt_f4.keycode = KEY_F4
	released_alt_f4.alt_pressed = true
	released_alt_f4.pressed = false
	assert_true(not MainScript.is_quit_shortcut(released_alt_f4), "Key release Alt+F4 does not quit")

	var ctrl_alt_f4 := InputEventKey.new()
	ctrl_alt_f4.keycode = KEY_F4
	ctrl_alt_f4.alt_pressed = true
	ctrl_alt_f4.ctrl_pressed = true
	ctrl_alt_f4.pressed = true
	assert_true(not MainScript.is_quit_shortcut(ctrl_alt_f4), "Ctrl+Alt+F4 does not quit")

	var meta_alt_f4 := InputEventKey.new()
	meta_alt_f4.keycode = KEY_F4
	meta_alt_f4.alt_pressed = true
	meta_alt_f4.meta_pressed = true
	meta_alt_f4.pressed = true
	assert_true(not MainScript.is_quit_shortcut(meta_alt_f4), "Meta+Alt+F4 does not quit")

	var alt_e := InputEventKey.new()
	alt_e.keycode = KEY_E
	alt_e.alt_pressed = true
	alt_e.pressed = true
	assert_true(not MainScript.is_quit_shortcut(alt_e), "Alt+E does not quit")

	var mouse_btn := InputEventMouseButton.new()
	assert_true(not MainScript.is_quit_shortcut(mouse_btn), "Non-key events do not quit")

	var main: Node = MainScript.new()
	main._input(plain_f4)
	assert_true(not main._quitting, "Plain F4 in _input does not set _quitting")
	free_node(main)
