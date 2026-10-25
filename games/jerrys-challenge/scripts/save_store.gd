extends RefCounted

# Stable user:// location across executable versions. Never write play saves in builds/.
static var session_backed_up: Dictionary = {}

static func read_json(path: String):
	if not FileAccess.file_exists(path): return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

static func valid_family(data) -> bool:
	if not data is Dictionary or data.get("version") != 1: return false
	if not data.get("items") is Array or not (data.get("wallet") is int or data.get("wallet") is float): return false
	if data.wallet < 0 or not data.get("shop", {}) is Dictionary: return false
	for item in data.items:
		if not item is Dictionary or not item.has_all(["uid", "kind", "room", "cell", "dir"]): return false
		if not item.cell is Array or item.cell.size() != 2 or item.room not in ["home", "inventory"]: return false
	return true

static func read_family(path: String) -> Dictionary:
	for candidate in [path, path + ".bak", path + ".bak2"]:
		var data = read_json(candidate)
		if valid_family(data):
			return {"data": data, "recovered": candidate != path, "invalid": false}
	return {"data": {}, "recovered": false, "invalid": FileAccess.file_exists(path)}

static func write_family(path: String, data: Dictionary) -> Error:
	if not valid_family(data): return ERR_INVALID_DATA
	var absolute := ProjectSettings.globalize_path(path)
	var folder := absolute.get_base_dir()
	DirAccess.make_dir_recursive_absolute(folder)
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if not valid_family(read_json(temporary)): return ERR_FILE_CORRUPT
	if not session_backed_up.has(absolute):
		if FileAccess.file_exists(absolute):
			var backups := folder.path_join("backups")
			DirAccess.make_dir_recursive_absolute(backups)
			var stamp := "%d_%d" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]
			var prefix := "family_home_" if valid_family(read_json(absolute)) else "damaged_family_home_"
			var error := DirAccess.copy_absolute(absolute, backups.path_join(prefix + stamp + ".json"))
			if error != OK: return error
			var names: Array[String] = []
			for name in DirAccess.get_files_at(backups):
				if name.begins_with("family_home_") and name.ends_with(".json"): names.append(name)
			names.sort()
			while names.size() > 30:
				DirAccess.remove_absolute(backups.path_join(names.pop_front()))
		session_backed_up[absolute] = true
	# Preserve two known-good revisions. A damaged primary never replaces its backup.
	if valid_family(read_json(absolute)):
		if valid_family(read_json(absolute + ".bak")):
			var error := DirAccess.copy_absolute(absolute + ".bak", absolute + ".bak2")
			if error != OK: return error
		var error := DirAccess.copy_absolute(absolute, absolute + ".bak")
		if error != OK: return error
	return DirAccess.rename_absolute(temporary, absolute)

static func automated_run_safe() -> bool:
	var args := OS.get_cmdline_args()
	var automated := OS.get_cmdline_user_args().has("--verify")
	for arg in args: automated = automated or arg == "--script" or arg.begins_with("--script=")
	for arg in OS.get_cmdline_user_args(): automated = automated or arg.begins_with("--capture=")
	if not automated: return true
	var expected := OS.get_environment("YILIN_GAME_QA_DIR").replace("\\", "/").trim_suffix("/")
	var actual := OS.get_user_data_dir().replace("\\", "/")
	return not expected.is_empty() and actual.begins_with(expected + "/")
