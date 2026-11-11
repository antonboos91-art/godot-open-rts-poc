## Echte Einheiten-Kollision: bewegliche Einheiten schieben sich gegenseitig auseinander (auch im Stand,
## auch beim Schiessen), sodass sich keine Figuren und Fahrzeuge mehr ueberlappen. Bodeneinheiten werden
## zusaetzlich aus Gebaeuden herausgeschoben und auf dem Navigationsnetz gehalten. Flieger kollidieren
## nur untereinander. Koerperradius nach sichtbarer Groesse (Fahrzeug-Sprites sind deutlich groesser
## als der Navigations-Radius). Laeuft nur auf dem Host; Clients bekommen die Positionen synchronisiert.
extends Node

const CELL = 4.0
## Anteil der Ueberlappung, der pro Durchgang aufgeloest wird (weich, kein Zittern)
const RELAX = 0.55
## Einheiten, die sich gerade aktiv bewegen, werden weniger geschoben als stehende
const MOVING_WEIGHT = 0.35

var _tick = 0

@onready var _match = get_parent()


static func body_radius(unit):
	if unit.has_meta("body_radius"):
		return unit.get_meta("body_radius")
	var r = 0.5
	var vehicle = unit.get_node_or_null("SpriteVehicle")
	if vehicle != null and "_meta" in vehicle and vehicle._meta is Dictionary:
		r = float(vehicle._meta.get("ortho", 3.6)) * vehicle._s() * 0.4
	else:
		match unit.type:
			"Infantry":
				var v = unit.variant
				r = 0.8 if (v.ends_with("kampfhund") or v.ends_with("panther") or v.ends_with("kodiak")) else 0.5
			"Worker":
				r = 1.1
			"Tank":
				r = 1.3
			"Helicopter":
				r = 1.4
			"Drone":
				r = 1.0
			_:
				r = unit.radius if unit.radius != null else 0.6
	r = clamp(r, 0.4, 2.6)
	unit.set_meta("body_radius", r)
	return r


## Ziel der aktuellen Aktion (auch verschachtelt), z. B. das zu reparierende Fahrzeug
static func _action_target(unit):
	var action = unit.get("action")
	var depth = 0
	while action != null and is_instance_valid(action) and depth < 6:
		var t = action.get("_target_unit")
		if t != null and is_instance_valid(t):
			return t
		action = action.get("_sub_action")
		depth += 1
	return null


static func _is_idle(unit):
	var action = unit.get("action")
	if action == null:
		return true
	return action.has_method("is_idle") and action.is_idle()


func _physics_process(_delta):
	if Network.is_client():
		return
	_tick += 1
	if _tick % 2 != 0:
		return
	var movers = []
	var structures = []
	for u in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(u) or not u.is_inside_tree():
			continue
		if u.get_node_or_null("Movement") != null:
			movers.append(u)
		elif u.has_method("is_constructed"):
			structures.append(u)
	var resources = get_tree().get_nodes_in_group("resource_units")
	if movers.is_empty():
		return
	# Raster fuer schnelle Nachbarsuche
	var grid = {}
	var info = []
	for u in movers:
		var p = u.global_position
		var mv = u.get_node("Movement")
		var moving = mv.target_position != Vector3.INF and not mv.is_navigation_finished()
		var entry = [u, Vector2(p.x, p.z), body_radius(u), u.movement_domain, moving, Vector2.ZERO, _action_target(u)]
		info.append(entry)
		var key = Vector2i(floor(p.x / CELL), floor(p.z / CELL))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(entry)
	for a in info:
		var key = Vector2i(floor(a[1].x / CELL), floor(a[1].y / CELL))
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var bucket = grid.get(key + Vector2i(dx, dy))
				if bucket == null:
					continue
				for b in bucket:
					if b == a or a[3] != b[3] or a[0].get_instance_id() > b[0].get_instance_id():
						continue
					# wer gerade mit dem anderen arbeitet (reparieren, einsteigen, folgen), darf ihn beruehren
					if a[6] == b[0] or b[6] == a[0]:
						continue
					var d = b[1] - a[1]
					var dist = d.length()
					var min_d = a[2] + b[2]
					if dist >= min_d:
						continue
					var n = d / dist if dist > 0.001 else Vector2(cos(a[0].get_instance_id()), sin(a[0].get_instance_id()))
					var overlap = (min_d - dist) * RELAX
					var wa = 0.5
					if a[4] and not b[4]:
						wa = MOVING_WEIGHT
					elif b[4] and not a[4]:
						wa = 1.0 - MOVING_WEIGHT
					var wb = 1.0 - wa
					a[5] -= n * overlap * wa
					b[5] += n * overlap * wb
	# Bodeneinheiten aus Gebaeuden heraus
	var terrain = Constants.Match.Navigation.Domain.TERRAIN
	for a in info:
		# Sammler muessen an Rohstoffe und Raffinerien andocken: nicht aus Gebaeuden\/Feldern schieben
		if a[3] != terrain or a[0].type == "Worker":
			continue
		for s in structures:
			if a[6] == s:
				continue
			var sp = Vector2(s.global_position.x, s.global_position.z)
			var fp = (s.radius - 0.4) if s.radius != null else 1.0
			var d = a[1] + a[5] - sp
			var dist = d.length()
			var min_d = fp + a[2] * 0.7
			if dist < min_d and dist > 0.001:
				a[5] += d / dist * (min_d - dist) * RELAX
		for r in resources:
			if not is_instance_valid(r):
				continue
			var rp = Vector2(r.global_position.x, r.global_position.z)
			var d2 = a[1] + a[5] - rp
			var dist2 = d2.length()
			var min_d2 = 0.6 + a[2] * 0.5
			if dist2 < min_d2 and dist2 > 0.001:
				a[5] += d2 / dist2 * (min_d2 - dist2) * RELAX
	# anwenden, auf dem Navigationsnetz halten
	for a in info:
		if a[5].length_squared() < 0.00001:
			continue
		var u = a[0]
		var target = u.global_position + Vector3(a[5].x, 0, a[5].y)
		if a[3] == terrain:
			var map = _match.navigation.get_navigation_map_rid_by_domain(terrain)
			var snapped = NavigationServer3D.map_get_closest_point(map, target)
			target = Vector3(snapped.x, u.global_position.y, snapped.z)
		u.global_position = target
		# Einheiten ohne Befehl (nur Startverteilung / Wartet auf Ziele) nicht zurueck in die Ueberlappung laufen lassen
		if not a[4] or _is_idle(u):
			var mv = u.get_node_or_null("Movement")
			if mv != null and _is_idle(u):
				mv.stop()
