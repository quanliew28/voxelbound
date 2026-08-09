extends RefCounted
class_name Settings
## Minimal persisted settings (user://settings.cfg) — zero assets.
## Currently: mouse sensitivity. Extend with more keys as needed.

const PATH := "user://settings.cfg"
const DEFAULT_SENSITIVITY: float = 0.0022


static func load_sensitivity() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		return float(cfg.get_value("controls", "sensitivity", DEFAULT_SENSITIVITY))
	return DEFAULT_SENSITIVITY


static func save_sensitivity(value: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("controls", "sensitivity", value)
	cfg.save(PATH)
