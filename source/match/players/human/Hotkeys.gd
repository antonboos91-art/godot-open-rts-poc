## Frei belegbare Tastenkürzel. Standardbelegung unten; wer etwas ändern will, legt die Datei
## user://hotkeys.cfg an (Abschnitt [keys], z. B. `stop="Ctrl+S"` ist nicht möglich, nur Einzeltasten:
## `stop="S"`). Die Datei wird beim ersten Start mit den Standardwerten angelegt.
extends RefCounted

const CONFIG_PATH = "user://hotkeys.cfg"
const DEFAULTS = {
	"stop": "X",
	"attack_move": "F",
	"sell": "Delete",
	"idle_worker": "F1",
	"select_army": "F2",
	"subgroup": "Tab",
	"macro": "Z",
	"cast": "C",
	"observer_overlay": "F10",
	"camera_1": "F5",
	"camera_2": "F6",
	"camera_3": "F7",
	"camera_4": "F8",
	"produce_1": "Y",
	"produce_2": "U",
	"produce_3": "I",
	"produce_4": "O",
	"produce_5": "H",
	"produce_6": "J",
	"produce_7": "K",
	"produce_8": "L",
}

## Aktive Untergruppe (Variante) der aktuellen Auswahl, "" = alle. Siehe HotkeyController.
static var active_subgroup = ""
static var _codes = {}


static func keycode(action):
	if _codes.is_empty():
		_load()
	return _codes.get(action, KEY_NONE)


static func matches(event, action, allow_echo = false):
	if not event is InputEventKey or not event.pressed or (event.echo and not allow_echo):
		return false
	var code = keycode(action)
	return code != KEY_NONE and (event.keycode == code or event.physical_keycode == code)


static func label(action):
	return OS.get_keycode_string(keycode(action))


static func _load():
	var config = ConfigFile.new()
	var loaded = config.load(CONFIG_PATH) == OK
	for action in DEFAULTS:
		var name = str(config.get_value("keys", action, DEFAULTS[action])) if loaded else DEFAULTS[action]
		var code = OS.find_keycode_from_string(name)
		if code == KEY_NONE:
			code = OS.find_keycode_from_string(DEFAULTS[action])
		_codes[action] = code
		if not loaded:
			config.set_value("keys", action, DEFAULTS[action])
	if not loaded and DisplayServer.get_name() != "headless":
		config.save(CONFIG_PATH)
