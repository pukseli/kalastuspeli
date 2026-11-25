extends "res://tests/test_case.gd"


func test_given_same_item_config_instance_when_apply_items_repeated_then_layout_not_rebuilt() -> void:
	var state := GameState.new()
	var world := WorldView.new()
	world.configure_holders(state.item_config)
	var initial_rebuilds := world.boat_view.layout_rebuild_count
	assert_true(initial_rebuilds >= 1, "Initial holder configuration builds layout once")

	for _i in range(20):
		world.apply_game_state(state, "", 1)

	assert_eq(world.boat_view.layout_rebuild_count, initial_rebuilds, "Repeated apply_game_state with same ItemConfig skips layout rebuild")
	free_node(world)


func test_given_fish_jumping_and_diving_when_toggled_then_same_fish_and_lure_nodes_reused() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	var world := WorldView.new()

	var item := state.get_holder_item("rod_-3")
	var rod := state.get_rod_state(item.id)
	rod.planer.line_out = 20.0
	rod.planer.state = PlanerBoard.STATE_TROLLING
	rod.trail_factor = 1.0
	var fish := fish_sim.force_bite(state, rod_sim, item.id, FishState.SPECIES_PIKE, 5.0)
	fish.surfaced = false
	fish.jump_progress = 0.0

	# 1) Submerged: lure visible, fish hidden
	world.apply_game_state(state, "", 1)
	assert_eq(world.get_visible_lure_count(), 1, "Submerged hooked rod shows 1 lure")
	assert_eq(world.get_visible_fish_count(), 0, "Submerged fish is not visible")
	var lure_node := world.lures_container.get_node_or_null("Lure_%s" % item.id) as Node3D
	assert_true(lure_node != null, "Lure node created")
	var lure_id_before := lure_node.get_instance_id()

	# 2) Jump: fish visible, lure hidden
	fish.jump_progress = 0.5
	world.apply_game_state(state, "", 1)
	assert_eq(world.get_visible_lure_count(), 0, "Jumping fish hides lure")
	assert_eq(world.get_visible_fish_count(), 1, "Jumping fish is visible")
	var fish_node := world.fishes_container.get_node_or_null("Fish_%s" % item.id) as Node3D
	assert_true(fish_node != null, "Fish node created on jump")
	var fish_id_before := fish_node.get_instance_id()

	# 3) Dive back under water, then jump again -> exact same Node3D instances reused
	fish.jump_progress = 0.0
	world.apply_game_state(state, "", 1)
	assert_eq(world.get_visible_lure_count(), 1, "Diving fish re-shows lure")
	assert_eq(world.get_visible_fish_count(), 0, "Diving fish hides fish node")

	fish.jump_progress = 0.5
	world.apply_game_state(state, "", 1)
	var lure_after := world.lures_container.get_node_or_null("Lure_%s" % item.id) as Node3D
	var fish_after := world.fishes_container.get_node_or_null("Fish_%s" % item.id) as Node3D
	assert_eq(lure_after.get_instance_id(), lure_id_before, "Lure Node3D instance is reused across jump toggle")
	assert_eq(fish_after.get_instance_id(), fish_id_before, "Fish Node3D instance is reused across jump toggle")

	free_node(world)


func test_given_unchanged_planer_and_fish_state_when_applied_twice_then_materials_not_reassigned() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	var world := WorldView.new()

	var item := state.get_holder_item("rod_-3")
	var rod := state.get_rod_state(item.id)
	rod.planer.line_out = 18.0
	rod.planer.state = PlanerBoard.STATE_TRIPPED
	rod.trail_factor = 1.0
	var fish := fish_sim.force_bite(state, rod_sim, item.id, FishState.SPECIES_PIKE, 5.0)
	fish.surfaced = true

	world.apply_game_state(state, "", 1)
	var count_after_first := world.material_assign_count
	assert_true(count_after_first > 0, "First apply assigns materials to planer and fish")

	world.apply_game_state(state, "", 1)
	assert_eq(world.material_assign_count, count_after_first, "Second apply with unchanged state performs zero redundant material assignments")

	free_node(world)


func test_given_hooked_fish_bending_rod_when_trolling_lines_drawn_then_line_starts_at_visual_3d_rod_tip() -> void:
	var state := GameState.new()
	var rod_sim := RodSimulator.new()
	var fish_sim := FishSimulator.new()
	var world := WorldView.new()

	var item := state.get_holder_item("rod_-3")
	var rod := state.get_rod_state(item.id)
	rod.planer.line_out = 18.0
	rod.planer.state = PlanerBoard.STATE_TRIPPED
	rod.trail_factor = 1.0
	var fish := fish_sim.force_bite(state, rod_sim, item.id, FishState.SPECIES_ORCA, 4000.0)
	fish.fight_phase = 0.7
	fish.drag_rate = 1.5

	world.apply_game_state(state, "", 1)

	var unbent_core_tip := rod_sim.get_rod_tip_world(state, item)
	var visual_tip := world.boat_view.get_visual_rod_tip_world(item, state)
	var line_start := world.get_line_start_world(item.id)

	assert_almost_eq(line_start.distance_to(visual_tip), 0.0, 0.001, "Trolling line starts at visual 3D rod tip")
	assert_true(line_start.distance_to(unbent_core_tip) > 0.15, "Bent visual 3D rod tip differs significantly (>0.15m) from rigid unbent core tip")

	free_node(world)


func test_given_prompt_inputs_unchanged_when_applied_then_hud_prompts_remain_accurate() -> void:
	var state := GameState.new()
	var p1 := state.ensure_player(1)
	p1.local_position = Vector3(-1.3, CrewSimulator.DECK_SURFACE_Y, 0.8)
	var world := WorldView.new()

	world.apply_game_state(state, "Net: OFFLINE", 1)
	var first_prompt := world.prompt_label.text
	var first_line_prompt := world.line_prompt_label.text
	assert_eq(first_prompt, "[E] Poimi vapa (-3)", "Prompt label shows rod_-3 pickup")

	world.apply_game_state(state, "Net: OFFLINE", 1)
	assert_eq(world.prompt_label.text, first_prompt, "Prompt label remains identical on repeated frame")
	assert_eq(world.line_prompt_label.text, first_line_prompt, "Line prompt label remains identical on repeated frame")

	free_node(world)
