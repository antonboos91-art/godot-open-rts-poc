## Höhenlagen der Karte: Plateaus mit Rampen und Klippen, als einfache Funktion (kein Höhenbild).
## Alle Rechner kennen dieselbe Funktion, deshalb braucht es keine Synchronisierung.
##
## Ein Plateau ist ein Kreis mit einer Rampe in eine Richtung. Außerhalb des Kreises fällt das
## Gelände entweder steil ab (Klippe, nicht begehbar: über 45 Grad) oder flach über die Rampe
## (rund 11 Grad). Die Wegfindung (Navigationsmesh) leitet daraus selbst ab, wo man gehen kann.
##
## Höhenvorteil: Wer unten steht, sieht und trifft Ziele oben nicht (siehe can_see()), außer es
## fliegt oder steht selbst oben; Wachtürme und Flieger geben Sicht nach oben.
extends RefCounted

const CLIFF_LENGTH_M = 1.6
const RAMP_LENGTH_M = 16.0
const RAMP_HALF_ANGLE = 0.30  # Bogenmaß: Rampe ist rund 34 Grad breit
const RAMP_BLEND_ANGLE = 0.18
const VISION_HEIGHT_TOLERANCE_M = 1.2

## Alle Plateaus: [{"center": Vector2, "radius": float, "height": float, "ramp_dir": Vector2}]
static var plateaus = []
static var active = false


static func clear():
	plateaus = []
	active = false


static func add_plateau(center, radius, height, ramp_dir):
	plateaus.append(
		{"center": center, "radius": radius, "height": height, "ramp_dir": ramp_dir.normalized()}
	)
	active = true


## Höhe des Geländes an Weltposition (x, z).
static func at(x, z):
	if not active:
		return 0.0
	var p = Vector2(x, z)
	var h = 0.0
	for plateau in plateaus:
		var offset = p - plateau["center"]
		var distance = offset.length()
		var edge = distance - plateau["radius"]
		if edge <= 0.0:
			h = max(h, plateau["height"])
			continue
		if edge >= RAMP_LENGTH_M:
			continue
		var angle = abs(angle_difference(offset.angle(), plateau["ramp_dir"].angle()))
		var ramp_weight = clampf((RAMP_HALF_ANGLE + RAMP_BLEND_ANGLE - angle) / RAMP_BLEND_ANGLE, 0.0, 1.0)
		var fall_length = lerpf(CLIFF_LENGTH_M, RAMP_LENGTH_M, ramp_weight)
		var t = clampf(1.0 - edge / fall_length, 0.0, 1.0)
		h = max(h, plateau["height"] * smoothstep(0.0, 1.0, t))
	return h


static func at_vec(position):
	return at(position.x, position.z)


static func max_height():
	var result = 0.0
	for plateau in plateaus:
		result = max(result, plateau["height"])
	return result


## Schnittpunkt eines Strahls mit dem Gelände (Klick auf den Boden); null, wenn nichts getroffen wird.
static func ray_intersection(origin, direction):
	if not active:
		return null
	if direction.y >= -0.001:
		return null
	var step = 0.5
	var t = 0.0
	var previous = origin
	var last_above = origin
	for i in 4000:
		var point = origin + direction * t
		if point.y <= at(point.x, point.z):
			# zwischen last_above und point verfeinern
			var low = max(0.0, t - step)
			var high = t
			for j in 12:
				var mid = (low + high) / 2.0
				var q = origin + direction * mid
				if q.y <= at(q.x, q.z):
					high = mid
				else:
					low = mid
			var hit = origin + direction * high
			return Vector3(hit.x, at(hit.x, hit.z), hit.z)
		t += step
		previous = point
	return null


## Sichtlinie nach Höhe: Bodeneinheiten sehen Ziele auf höherem Gelände nicht.
## "viewer_flying" und "target_flying" kommen von den Einheiten (Luft ignoriert Höhen).
static func can_see(viewer_position, viewer_flying, target_position, target_flying):
	if not active or viewer_flying or target_flying:
		return true
	var viewer_height = at(viewer_position.x, viewer_position.z)
	var target_height = at(target_position.x, target_position.z)
	return target_height <= viewer_height + VISION_HEIGHT_TOLERANCE_M


## Luft (und Wachtürme, die nur Sicht geben) ignorieren Höhen.
static func is_flying(node):
	if not "movement_domain" in node:
		return true
	return node.movement_domain == Constants.Match.Navigation.Domain.AIR


## Kurzform für zwei Spielobjekte.
static func can_see_node(viewer, target):
	if not active:
		return true
	return can_see(
		viewer.global_position, is_flying(viewer), target.global_position, is_flying(target)
	)
