extends "res://app/art_boot.gd"
## W10 connects the accepted presentation to scene-owned audio.

var soundscape: WorldAudio
var submit_ms: Array[float] = []
var _audio_snapshot: Dictionary = {}
var _closing_audio: bool = false


func _ready() -> void:
	super._ready()
	hud.attach_dialogs(self)
	soundscape = WorldAudio.new()
	soundscape.name = "WorldAudio"
	add_child(soundscape)
	soundscape.configure(preferences.values)
	soundscape.sync_world(document.state)
	_audio_snapshot = document.snapshot()
	if qa_mode:
		saves.directory = "user://qa_w10_native"
		if "--w10-save-probe" in OS.get_cmdline_user_args():
			_start_save(0, "第十周发布版存档探针")
	if qa_mode and "--w10-settings-zoom" in OS.get_cmdline_user_args():
		_zoom_settings_probe.call_deferred()
	hud.set_status("林间坡地 · 声音与功能联调 / 设置中可分别调整环境、操作和音乐音量")


func _apply_preferences() -> void:
	super._apply_preferences()
	if soundscape != null:
		soundscape.configure(preferences.values)


func _on_published(snapshot: Dictionary, prepared: Dictionary) -> void:
	super._on_published(snapshot, prepared)
	if soundscape != null and snapshot == document.state:
		soundscape.sync_world(snapshot)
		var family: String = WorldAudio.change_family(_audio_snapshot, snapshot)
		if not family.is_empty():
			soundscape.play_effect(family)
		_audio_snapshot = snapshot.duplicate(true)


func _on_action(action: StringName) -> void:
	if soundscape != null:
		soundscape.play_effect("ui", 3 if action in [&"undo", &"redo"] else 1)
	super._on_action(action)


func _save_completed(operation: String, result: Dictionary) -> void:
	super._save_completed(operation, result)
	if soundscape != null and operation in ["save", "load"] and result.get("ok", false):
		soundscape.play_effect("ui", 2)


func _submit_async(candidate: Dictionary, label: String) -> void:
	var start: int = Time.get_ticks_usec()
	super._submit_async(candidate, label)
	submit_ms.append(float(Time.get_ticks_usec() - start) / 1000)
	if submit_ms.size() > 100:
		submit_ms.pop_front()


func _delivery_metrics() -> Dictionary:
	var result: Dictionary = super._delivery_metrics()
	result["submit_main_ms"] = submit_ms
	result["audio_driver"] = AudioServer.get_driver_name()
	result["settings_rect"] = [
		hud.settings.position.x, hud.settings.position.y, hud.settings.size.x, hud.settings.size.y
	]
	result["native_window_size"] = [get_window().size.x, get_window().size.y]
	result["audio_events"] = soundscape.sequence if soundscape != null else 0
	return result


func _zoom_settings_probe() -> void:
	hud.settings.popup_centered()
	hud.scale_control.value = 1.5


func _request_quit() -> void:
	if _closing_audio:
		return
	_closing_audio = true
	if soundscape != null:
		soundscape.shutdown()
		soundscape.queue_free()
		soundscape = null
		# Let the audio mixer consume the stopped voices before engine teardown.
		await get_tree().create_timer(0.4, true, false, true).timeout
	super._request_quit()
