extends "res://app/week_ten_boot.gd"
## Presentation refinement: contextual ribbon, adaptive far focus, GPU meadow.

var meadow: MeadowRenderer
var _focus_distance: float = -1


func _ready() -> void:
	super._ready()
	if qa_mode:
		saves.directory = "user://qa_garden_native"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--grass-density=") and qa_mode:
			_preference_changed(
				"grass_density", argument.trim_prefix("--grass-density=").to_float()
			)
	meadow = _create_meadow()
	meadow.name = "DynamicMeadow"
	world_view.add_child(meadow)
	meadow.set_density(preferences.values.get("grass_density", 0.45))
	meadow.request(document.state)
	wind_materials.append(meadow.material)
	_sync_wind(document.state)
	selected_buildings.clear()
	hud.sync(document.state, selected_buildings)
	_show_selection()
	tools.mode = "inspect"
	hud.set_active_tool("inspect")
	_apply_preferences()
	hud.set_status("点底部卡片开始建造 · 双指旋转 / 捏合缩放 · ⌥ + 左键平移")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--grass-density=") and qa_mode:
			_preference_changed(
				"grass_density", argument.trim_prefix("--grass-density=").to_float()
			)
		if argument == "--garden-no-focus" and qa_mode:
			_preference_changed("garden_focus", false)
		if argument.begins_with("--garden-tool=") and qa_mode:
			hud.open_group(argument.trim_prefix("--garden-tool="))


func _create_meadow() -> MeadowRenderer:
	return MeadowRenderer.new()


func _apply_preferences() -> void:
	if preferences != null:
		preferences.values.merge({"grass_density": 0.45, "garden_focus": true}, false)
	super._apply_preferences()
	if meadow != null:
		meadow.set_density(preferences.values["grass_density"])
	_focus_distance = -1
	_update_focus()


func _preference_changed(key: String, value: Variant) -> void:
	super._preference_changed("garden_focus" if key == "dof" else key, value)


func _process(delta: float) -> void:
	super._process(delta)
	_update_focus()


func _update_focus() -> void:
	if preferences == null or camera_rig == null or camera_rig.camera == null:
		return
	var attributes: CameraAttributesPractical = camera_rig.camera.attributes
	if attributes == null:
		return
	var focus: float = camera_rig.distance
	if (
		is_equal_approx(focus, _focus_distance)
		and attributes.dof_blur_far_enabled == preferences.values.get("garden_focus", true)
	):
		return
	_focus_distance = focus
	attributes.dof_blur_far_enabled = preferences.values.get("garden_focus", true)
	attributes.dof_blur_near_enabled = false
	attributes.dof_blur_far_distance = focus + 6.0
	attributes.dof_blur_far_transition = clampf(focus * 0.55, 10, 22)
	attributes.dof_blur_amount = 0.045


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	super._on_published(snapshot, prepared)
	if meadow != null:
		meadow.material.set_shader_parameter(
			"foliage_tint", GardenPalette.tint(snapshot["environment"], "foliage")
		)
		if meadow.material not in wind_materials:
			wind_materials.append(meadow.material)
		_sync_wind(snapshot)
		if snapshot == document.state:
			meadow.request(snapshot)


func enter_photo() -> bool:
	var entered: bool = super.enter_photo()
	if entered:
		hud.set_photo_mode(true)
	return entered


func exit_photo() -> void:
	var was_active: bool = photo_active
	super.exit_photo()
	if was_active and not photo_active:
		hud.set_photo_mode(false)


func _on_action(action: StringName) -> void:
	if action == &"select":
		if session.phase == EditSession.Phase.PENDING_COMMIT:
			hud.set_status("正在完成上一笔；Esc 可取消")
			return
		_cancel_edit()
		tools.mode = "inspect"
		hud.set_active_tool("inspect")
		hud.set_status("点击小屋或物件修改；空白处清除选择")
		return
	super._on_action(action)


func _unhandled_input(event: InputEvent) -> void:
	if (
		tools != null
		and tools.mode == "inspect"
		and not photo_active
		and not _busy()
		and session.phase != EditSession.Phase.PENDING_COMMIT
	):
		if (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
			and not event.alt_pressed
			and not event.shift_pressed
		):
			var origin: Vector3 = camera_rig.camera.project_ray_origin(event.position)
			var direction: Vector3 = camera_rig.camera.project_ray_normal(event.position)
			var nearest: float = INF
			var selected: String = ""
			for home: Dictionary in document.state["buildings"]:
				var p: Array = home["position"]
				var size: Array = home["size"]
				var bounds: AABB = AABB(
					Vector3(p[0] - size[0] * 0.5, p[1], p[2] - size[2] * 0.5),
					Vector3(size[0], size[1] + 2, size[2])
				)
				var hit: Variant = bounds.intersects_ray(origin, direction)
				if hit is Vector3 and origin.distance_to(hit) < nearest:
					nearest = origin.distance_to(hit)
					selected = home["id"]
			var object_id: String = ""
			for id_value: String in _instance_views:
				var shapes: Array[Node] = _instance_views[id_value].find_children(
					"*", "CollisionShape3D", true, false
				)
				for shape_node: CollisionShape3D in shapes:
					if not shape_node.shape is BoxShape3D:
						continue
					var size_value: Vector3 = shape_node.shape.size
					var bounds: AABB = (
						shape_node.global_transform * AABB(-size_value * 0.5, size_value)
					)
					var hit: Variant = bounds.intersects_ray(origin, direction)
					if hit is Vector3 and origin.distance_to(hit) < nearest:
						nearest = origin.distance_to(hit)
						object_id = id_value
						selected = ""
			if not object_id.is_empty():
				_select_buildings([])
				_select_objects([object_id])
				if hud.group != "edit":
					hud.open_group("edit", false)
			elif not selected.is_empty():
				_select_buildings([selected])
				if hud.group != "build":
					hud.open_group("build", false)
			else:
				_select_buildings([])
				super._on_action(&"select")
				super._unhandled_input(event)
				tools.mode = "inspect"
				if hud.group != "edit":
					hud.open_group("edit", false)
			get_viewport().set_input_as_handled()
			return
	super._unhandled_input(event)


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	if meadow != null:
		result["meadow_total"] = meadow.total
		result["meadow_visible"] = meadow.visible_count()
		result["meadow_batches"] = meadow.batches.size()
		result["meadow_worker_ms"] = meadow.worker_ms
		result["meadow_apply_max_ms"] = meadow.apply_max_ms
		result["meadow_rebuilt_chunks"] = meadow.rebuilt_chunks
		result["meadow_reused_chunks"] = meadow.reused_chunks
		result["grass_density"] = meadow.density
	result["garden_focus"] = (
		preferences.values.get("garden_focus", true) if preferences != null else true
	)
	return result


func _finish_smoke() -> void:
	var start: int = Time.get_ticks_msec()
	while meadow != null and meadow.is_busy() and Time.get_ticks_msec() - start < 15000:
		await get_tree().process_frame
	if meadow != null and meadow.is_busy():
		push_error("Meadow did not settle before capture")
		get_tree().quit(1)
		return
	super._finish_smoke()
