extends "res://tests/test_case.gd"


func test_forward_inertia_glides_after_throttle_release() -> void:
	var boat := BoatState.new()
	var input := PlayerInput.new()
	var sim := BoatSimulator.new()

	# Accelerate forward first
	input.throttle = 1.0
	for _i in range(40):
		sim.step(boat, input, BoatSimulator.FIXED_DELTA)

	var speed_before_release := boat.forward_speed
	assert_true(speed_before_release > 4.0, "Boat should accelerate to over 4 m/s")

	# Release throttle - boat must glide forward due to inertia
	input.throttle = 0.0
	var z_at_release := boat.world_position.z
	for _i in range(30):
		sim.step(boat, input, BoatSimulator.FIXED_DELTA)

	assert_true(boat.forward_speed > 2.0, "Boat forward_speed should glide with low drag, remaining > 2.0 m/s")
	assert_true(boat.world_position.z < z_at_release - 1.5, "Boat should continue traveling along -Z due to inertia")


func test_lateral_drag_damps_faster_than_forward_drag() -> void:
	var boat := BoatState.new()
	var input := PlayerInput.new()
	var sim := BoatSimulator.new()

	# Heading 0 -> forward is -Z, lateral/right is +X
	boat.heading = 0.0
	var initial_speed := 4.0
	boat.velocity = Vector2(initial_speed, -initial_speed)
	boat.forward_speed = initial_speed

	input.throttle = 0.0
	input.steering = 0.0

	# Step 20 ticks of water resistance
	for _i in range(20):
		sim.step(boat, input, BoatSimulator.FIXED_DELTA)

	var fwd_dir := Vector2(-sin(boat.heading), -cos(boat.heading))
	var right_dir := Vector2(cos(boat.heading), -sin(boat.heading))
	var final_fwd := boat.velocity.dot(fwd_dir)
	var final_lat := boat.velocity.dot(right_dir)

	assert_true(final_lat < final_fwd, "Lateral speed must damp faster than forward speed")
	assert_true(final_lat < initial_speed * 0.4, "Lateral speed should be strongly damped by lateral_drag")
	assert_true(final_fwd > initial_speed * 0.7, "Forward speed should be preserved longer by low forward_drag")


func test_turn_faster_with_throttle_than_coasting() -> void:
	var sim := BoatSimulator.new()

	# Scenario A: Turning with throttle (vectored thrust active)
	var boat_thrust := BoatState.new()
	boat_thrust.forward_speed = 5.0
	boat_thrust.velocity = Vector2(0.0, -5.0)
	var input_thrust := PlayerInput.new()
	input_thrust.throttle = 1.0
	input_thrust.steering = 1.0

	# Scenario B: Turning while coasting with zero throttle (passive rudder effect only)
	var boat_coast := BoatState.new()
	boat_coast.forward_speed = 5.0
	boat_coast.velocity = Vector2(0.0, -5.0)
	var input_coast := PlayerInput.new()
	input_coast.throttle = 0.0
	input_coast.steering = 1.0

	for _i in range(25):
		sim.step(boat_thrust, input_thrust, BoatSimulator.FIXED_DELTA)
		sim.step(boat_coast, input_coast, BoatSimulator.FIXED_DELTA)

	assert_true(boat_thrust.heading > boat_coast.heading * 1.5, "Boat with throttle should turn substantially faster than coasting")
	assert_true(boat_thrust.angular_velocity > boat_coast.angular_velocity, "Angular velocity with throttle should exceed coasting angular velocity")


func test_reverse_throttle_acts_as_brake_and_inverts_torque() -> void:
	var sim := BoatSimulator.new()

	# Test braking with reverse
	var boat_brake := BoatState.new()
	boat_brake.forward_speed = 6.0
	boat_brake.velocity = Vector2(0.0, -6.0)
	var input_brake := PlayerInput.new()
	input_brake.throttle = -1.0

	var boat_coast := BoatState.new()
	boat_coast.forward_speed = 6.0
	boat_coast.velocity = Vector2(0.0, -6.0)
	var input_coast := PlayerInput.new()
	input_coast.throttle = 0.0

	for _i in range(20):
		sim.step(boat_brake, input_brake, BoatSimulator.FIXED_DELTA)
		sim.step(boat_coast, input_coast, BoatSimulator.FIXED_DELTA)

	assert_true(boat_brake.forward_speed < boat_coast.forward_speed, "Reverse throttle should decelerate boat faster than coasting")

	# Test reverse torque direction
	var boat_rev := BoatState.new()
	boat_rev.forward_speed = 0.0
	var input_rev := PlayerInput.new()
	input_rev.throttle = -1.0
	input_rev.steering = 1.0  # Steer left

	for _i in range(15):
		sim.step(boat_rev, input_rev, BoatSimulator.FIXED_DELTA)

	assert_true(boat_rev.angular_velocity < 0.0, "Reverse throttle should produce reverse torque when steering")


func test_physics_parameters_are_configurable() -> void:
	var sim := BoatSimulator.new()
	assert_true(sim.config != null, "BoatSimulator should expose a Config instance")

	sim.config.engine_power = 24.0
	var boat := BoatState.new()
	var input := PlayerInput.new()
	input.throttle = 1.0

	for _i in range(20):
		sim.step(boat, input, BoatSimulator.FIXED_DELTA)

	assert_true(boat.forward_speed > 5.0, "Increasing engine_power should increase acceleration")
