extends "res://tests/test_case.gd"


func test_boat_accelerates_and_clamps_max_speed() -> void:
	var boat := BoatState.new()
	var input := PlayerInput.new()
	var sim := BoatSimulator.new()
	input.throttle = 1.0
	for _i in range(120):
		sim.step(boat, input, BoatSimulator.FIXED_DELTA)
	assert_almost_eq(boat.forward_speed, BoatSimulator.BOAT_MAX_SPEED, 0.001, "Boat should reach and clamp at max speed 8.0 m/s")
	assert_true(boat.world_position.z < -10.0, "Boat should travel forward along -Z axis")


func test_water_drag_stops_boat() -> void:
	var boat := BoatState.new()
	var input := PlayerInput.new()
	var sim := BoatSimulator.new()
	boat.forward_speed = 5.0
	input.throttle = 0.0
	for _i in range(180):
		sim.step(boat, input, BoatSimulator.FIXED_DELTA)
	assert_almost_eq(boat.forward_speed, 0.0, 0.001, "Water drag should bring boat forward_speed to 0.0")


func test_boat_steering_changes_heading_and_direction() -> void:
	var boat := BoatState.new()
	var input := PlayerInput.new()
	var sim := BoatSimulator.new()
	input.throttle = 1.0
	input.steering = 1.0
	for _i in range(60):
		sim.step(boat, input, BoatSimulator.FIXED_DELTA)
	assert_true(boat.heading > 0.5, "Steering left (+1.0) should increase heading radians")
	assert_true(boat.world_position.x < -0.5, "Turning left while moving forward should shift world_position.x negative")


func test_boat_state_serialization_roundtrip() -> void:
	var boat := BoatState.new()
	boat.world_position = Vector3(12.5, 0.0, -34.25)
	boat.heading = 1.25
	boat.forward_speed = 6.5
	var restored_boat := BoatState.new()
	restored_boat.from_dict(boat.to_dict())
	assert_almost_eq(restored_boat.world_position.x, 12.5, 0.001, "Restored world_position.x")
	assert_almost_eq(restored_boat.world_position.z, -34.25, 0.001, "Restored world_position.z")
	assert_almost_eq(restored_boat.heading, 1.25, 0.001, "Restored heading")
	assert_almost_eq(restored_boat.forward_speed, 6.5, 0.001, "Restored forward_speed")

	var input := PlayerInput.new()
	input.throttle = 0.75
	input.steering = -0.5
	var restored_input := PlayerInput.new()
	restored_input.from_dict(input.to_dict())
	assert_almost_eq(restored_input.throttle, 0.75, 0.001, "Restored throttle")
	assert_almost_eq(restored_input.steering, -0.5, 0.001, "Restored steering")


func test_world_and_boat_view_sync_transform() -> void:
	var world := WorldView.new()
	var boat := BoatState.new()
	boat.world_position = Vector3(4.0, 0.0, -9.0)
	boat.heading = 0.6
	world.apply_state(boat)
	assert_true(world.boat_view != null, "WorldView should instantiate BoatView")
	assert_almost_eq(world.boat_view.position.x, 4.0, 0.001, "BoatView position.x matches BoatState")
	assert_almost_eq(world.boat_view.position.z, -9.0, 0.001, "BoatView position.z matches BoatState")
	assert_almost_eq(world.boat_view.rotation.y, 0.6, 0.001, "BoatView rotation.y matches BoatState.heading")
	free_node(world)
