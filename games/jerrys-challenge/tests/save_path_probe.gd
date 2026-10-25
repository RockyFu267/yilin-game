extends SceneTree

func _initialize() -> void:
	print("SAVE_PATH_PROBE: ", OS.get_user_data_dir())
	print("SAVE_ARGS_PROBE: ", OS.get_cmdline_args())
	print("SPINBOX_APPLY: ", ClassDB.class_has_method("SpinBox", "apply"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family-path="):
			var store = load("res://scripts/save_store.gd")
			print("EXISTING_FAMILY_VALID: ", store.valid_family(store.read_json(arg.trim_prefix("--family-path="))))
	quit()
