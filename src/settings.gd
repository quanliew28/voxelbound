extends RefCounted
class_name Settings
## Minimal persisted settings (user://settings.cfg) — zero assets.
## Currently: mouse sensitivity + UI scale. Extend with more keys as needed.

const PATH := "user://settings.cfg"
const DEFAULT_SENSITIVITY: float = 0.0022
const DEFAULT_UI_SCALE: float = 1.0
const UI_SCALE_MIN: float = 0.75
const UI_SCALE_MAX: float = 1.5


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


static func load_ui_scale() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		return clampf(float(cfg.get_value("display", "ui_scale", DEFAULT_UI_SCALE)), UI_SCALE_MIN, UI_SCALE_MAX)
	return DEFAULT_UI_SCALE


static func save_ui_scale(value: float) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("display", "ui_scale", clampf(value, UI_SCALE_MIN, UI_SCALE_MAX))
	cfg.save(PATH)
