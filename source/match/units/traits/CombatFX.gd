## Kampfeffekte im StarCraft-Stil: leuchtende Laser (Shibas), Phaser-Strahlen (Katzen),
## Plasma-Geschosse (Baeren), Mündungsblitze mit Licht, Treffer-Funken und grosse Explosionen
## mit Feuerball, Druckwelle, Rauch, Truemmern und Brandfleck.
## Farben liegen ueber 1.0 (HDR), damit das Bloom der Umgebung sie leuchten laesst.
## Alles rein optisch, laeuft auf jedem Rechner selbst.
extends RefCounted

const Factions = preload("res://source/match/factions/Factions.gd")
const BEAM_SHADER = preload("res://source/shaders/3d/beam.gdshader")

const STYLE = {
	"shibas": {"kind": "laser", "color": Color(0.35, 0.85, 1.6), "sound": "laser_shot"},
	"katzen": {"kind": "phaser", "color": Color(1.3, 0.35, 1.8), "sound": "phaser_shot"},
	"baeren": {"kind": "plasma", "color": Color(1.9, 0.75, 0.2), "sound": "plasma_shot"},
	"core": {"kind": "laser", "color": Color(1.4, 1.2, 0.5), "sound": "laser_shot"},
}

static var _dot = null
static var _ring = null
static var _puff = null


static func style_for(unit):
	var faction = Factions.faction_of(unit.player) if is_instance_valid(unit) and "player" in unit else "core"
	return STYLE.get(faction, STYLE["core"])


static func _root(node):
	var tree = node.get_tree() if node != null and node.is_inside_tree() else null
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


## Soll der Effekt gezeigt werden? (Nebel des Krieges: Schuetze oder Ziel sichtbar)
static func visible_for(shooter, target):
	return (is_instance_valid(shooter) and shooter.visible) or (is_instance_valid(target) and target.visible)


## Ein Schuss im Stil des Volks von `from` nach `to`. scale: 1 = Infanterie, 2 = Panzer, 3 = Turm
static func shot(shooter, from, to, scale = 1.0, style = null):
	var root = _root(shooter)
	if root == null:
		return
	if style == null:
		style = style_for(shooter)
	var c = style["color"]
	SoundEffects.play(style["sound"], from)
	muzzle(root, from, c, 0.35 * scale)
	match style["kind"]:
		"phaser":
			beam(root, from, to, c, 0.13 * scale, 0.35, true)
			impact(root, to, c, 0.5 * scale)
		"plasma":
			bolt(root, from, to, c, 0.26 * scale, 1.0 * scale, 30.0, 0.8 * scale)
		_:
			bolt(root, from, to, c, 0.12 * scale, 1.8 * scale, 55.0, 0.5 * scale)


## Durchgehender Strahl (Laser/Phaser) mit Energie-Shader, blendet weich aus; wobble = Phaser-Flackern
static func beam(root, from, to, color, width, life, wobble = false):
	if from.distance_to(to) < 0.05:
		return
	var mi = _beam_mesh(color, width * 4.0, 0.35 if wobble else 0.12)
	root.add_child(mi)
	_beam_set(mi, from, to)
	var m = mi.material_override
	var tw = mi.create_tween()
	tw.tween_interval(life * 0.45)
	tw.tween_method(func(v): m.set_shader_parameter("intensity", v), 1.0, 0.0, life * 0.55)
	tw.tween_callback(mi.queue_free)


## Wanderndes Leuchtgeschoss (kurzer Energiestrahl); beim Einschlag Treffer-Effekt der Groesse impact_size
static func bolt(root, from, to, color, width, length, speed, impact_size):
	var dist = from.distance_to(to)
	if dist < 0.05:
		impact(root, to, color, impact_size)
		return
	var dir = (to - from) / dist
	var mi = _beam_mesh(color, width * 4.5, 0.08)
	root.add_child(mi)
	var light = OmniLight3D.new()
	light.light_color = Color(clamp(color.r, 0, 1), clamp(color.g, 0, 1), clamp(color.b, 0, 1))
	light.light_energy = 2.0
	light.omni_range = 2.5 + width * 10.0
	root.add_child(light)
	var l = min(length, dist)
	var tw = mi.create_tween()
	tw.tween_method(
		func(t):
			var head = from.lerp(to, t)
			var tail = head - dir * min(l, from.distance_to(head))
			_beam_set(mi, tail, head)
			if is_instance_valid(light):
				light.global_position = head,
		0.0, 1.0, max(dist / speed, 0.04)
	)
	tw.tween_callback(func(): impact(root, to, color, impact_size))
	tw.tween_callback(light.queue_free)
	tw.tween_callback(mi.queue_free)


static func _beam_mesh(color, width, flicker):
	var mi = MeshInstance3D.new()
	var q = QuadMesh.new()
	mi.mesh = q
	mi.custom_aabb = AABB(Vector3(-5000, -100, -5000), Vector3(10000, 200, 10000))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m = ShaderMaterial.new()
	m.shader = BEAM_SHADER
	var k = max(color.r, max(color.g, color.b))
	m.set_shader_parameter("color", Color(color.r / k, color.g / k, color.b / k, 1.0))
	m.set_shader_parameter("energy", 1.6 * k)
	m.set_shader_parameter("width", width)
	m.set_shader_parameter("flicker", flicker)
	m.set_shader_parameter("seed", randf() * 100.0)
	mi.material_override = m
	return mi


static func _beam_set(mi, from, to):
	var m = mi.material_override
	m.set_shader_parameter("start", from)
	m.set_shader_parameter("end", to)


## Mündungsblitz mit kurzem Licht
static func muzzle(root, at, color, size):
	_flash(root, at, color, size, 0.08)
	_light(root, at, color, 3.0 + size * 6.0, 2.0 + size * 6.0, 0.1)


## Treffer: Blitz, Funken, etwas Rauch
static func impact(root, at, color, size):
	_flash(root, at, color, size * 1.4, 0.12)
	_light(root, at, color, 2.0 + size * 8.0, 2.0 + size * 7.0, 0.18)
	_particles(root, at, Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 1.0), Color(color.r, color.g, color.b, 0.0),
		int(8 + size * 14), 0.35, 4.0 + size * 5.0, 0.06 + size * 0.05, Vector3(0, -9, 0), true, 80.0)
	if size > 0.5:
		_particles(root, at, Color(0.25, 0.24, 0.22, 0.5), Color(0.3, 0.3, 0.3, 0.0), 6, 1.0, 1.2, 0.5 * size, Vector3(0, 0.8, 0), false, 60.0)


## Grosse Explosion: Feuerball, Druckwelle am Boden, Rauchsaeule, Truemmer, Funken, Brandfleck
static func explosion(node, at, size = 1.0, color = Color(1.7, 0.65, 0.18)):
	var root = _root(node)
	if root == null:
		return
	SoundEffects.play("explosion_huge" if size >= 1.5 else "explosion_big", at)
	_flash(root, at + Vector3(0, 0.6 * size, 0), Color(2.2, 1.6, 0.9), 3.2 * size, 0.22)
	_light(root, at + Vector3(0, 1.0, 0), Color(1.0, 0.6, 0.25), 14.0 * size, 7.0 + 5.0 * size, 0.6)
	# Feuerball (additiv, HDR)
	_particles(root, at + Vector3(0, 0.4 * size, 0), Color(color.r, color.g, color.b, 1.0), Color(1.2, 0.2, 0.05, 0.0),
		int(44 * size), 0.45, 1.3 * size, 0.42 * size, Vector3(0, 2.2, 0), true, 180.0)
	# heisser Kern
	_particles(root, at + Vector3(0, 0.5 * size, 0), Color(1.9, 1.3, 0.7, 1.0), Color(1.4, 0.5, 0.1, 0.0),
		int(12 * size), 0.3, 0.6 * size, 0.8 * size, Vector3.ZERO, true, 180.0)
	# Funken und gluehende Truemmer
	_particles(root, at + Vector3(0, 0.3, 0), Color(2.4, 1.4, 0.5, 1.0), Color(1.0, 0.3, 0.05, 0.0),
		int(36 * size), 1.1, 9.0 * size, 0.07, Vector3(0, -12, 0), true, 75.0)
	# dunkle Rauchsaeule
	_particles(root, at + Vector3(0, 0.8 * size, 0), Color(0.16, 0.15, 0.14, 0.55), Color(0.28, 0.27, 0.26, 0.0),
		int(18 * size), 2.6, 1.6 * size, 1.4 * size, Vector3(0, 1.4, 0), false, 50.0)
	_shockwave(root, at, color, 2.8 * size)
	_scorch(root, at, 1.6 * size)


static func _cylinder(radius, length, color):
	var mi = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 8
	cyl.rings = 1
	mi.mesh = cyl
	mi.rotation.x = PI / 2  # Zylinder liegt entlang -Z (look_at-Richtung)
	mi.material_override = _additive(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _additive(color):
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color
	m.disable_receive_shadows = true
	return m


static func _flash(root, at, color, size, life):
	var flash = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(size, size)
	flash.mesh = q
	var m = _additive(Color(color.r, color.g, color.b, 1.0))
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = soft_dot()
	flash.material_override = m
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flash)
	flash.global_position = at
	var tw = flash.create_tween()
	tw.tween_property(flash, "scale", Vector3(1.6, 1.6, 1.6), life)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, life)
	tw.tween_callback(flash.queue_free)


static func _light(root, at, color, energy, light_range, life):
	var light = OmniLight3D.new()
	light.light_color = Color(clamp(color.r, 0, 1), clamp(color.g, 0, 1), clamp(color.b, 0, 1))
	light.light_energy = energy
	light.omni_range = light_range
	root.add_child(light)
	light.global_position = at
	var tw = light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, life)
	tw.tween_callback(light.queue_free)


static func _particles(root, at, c_start, c_end, amount, lifetime, velocity, size, gravity, additive, spread):
	var p = CPUParticles3D.new()
	p.one_shot = true
	p.amount = max(amount, 1)
	p.lifetime = lifetime
	p.explosiveness = 0.92
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = velocity * 0.35
	p.initial_velocity_max = velocity
	p.gravity = gravity
	p.damping_min = 1.5
	p.damping_max = 3.5
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.4
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0.6))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1, 1.3 if not additive else 0.4))
	p.scale_amount_curve = scale_curve
	var q = QuadMesh.new()
	q.size = Vector2(1, 1)
	p.mesh = q
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	# grosse Partikel (Feuer, Rauch) bekommen zerfaserte Rauchwolken-Textur und drehen sich zufaellig
	m.albedo_texture = puff_texture() if size > 0.15 else soft_dot()
	if size > 0.15:
		p.angle_min = 0.0
		p.angle_max = 360.0
		m.billboard_keep_scale = true
	# HDR-Farben: Verlauf normieren, Helligkeit ueber albedo_color (Bloom)
	var k = max(1.0, max(c_start.r, max(c_start.g, c_start.b)))
	if k > 1.0:
		c_start = Color(c_start.r / k, c_start.g / k, c_start.b / k, c_start.a)
		c_end = Color(c_end.r / k, c_end.g / k, c_end.b / k, c_end.a)
		m.albedo_color = Color(k, k, k, 1.0)
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var g = Gradient.new()
	g.set_color(0, c_start)
	g.set_color(1, c_end)
	p.color_ramp = g
	root.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _shockwave(root, at, color, radius):
	var ring = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(2, 2)
	q.orientation = PlaneMesh.FACE_Y
	ring.mesh = q
	var m = _additive(Color(color.r, color.g * 0.9, color.b * 0.8, 0.45))
	m.albedo_texture = ring_texture()
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	ring.global_position = at + Vector3(0, 0.08, 0)
	ring.scale = Vector3(0.2, 1, 0.2)
	var tw = ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(radius, 1, radius), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(ring.queue_free)


static func _scorch(root, at, radius):
	var scorch = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	scorch.mesh = q
	var m = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = soft_dot()
	m.albedo_color = Color(0.03, 0.025, 0.02, 0.75)
	scorch.material_override = m
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(scorch)
	scorch.global_position = at + Vector3(0, 0.03, 0)
	scorch.rotation.y = randf() * TAU
	var tw = scorch.create_tween()
	tw.tween_interval(14.0)
	tw.tween_property(m, "albedo_color:a", 0.0, 4.0)
	tw.tween_callback(scorch.queue_free)


static func soft_dot():
	if _dot == null:
		var g = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.add_point(0.25, Color(1, 1, 1, 0.55))
		g.add_point(0.6, Color(1, 1, 1, 0.12))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var t = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_dot = t
	return _dot


## Zerfaserte Rauch-/Feuerwolke: Rauschen mit weichem runden Rand
static func puff_texture():
	if _puff == null:
		var noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.06
		noise.fractal_octaves = 4
		var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var r = Vector2(x - 63.5, y - 63.5).length() / 64.0
				var n = noise.get_noise_2d(x, y) * 0.5 + 0.5
				var a = clamp((1.0 - r * 1.35) * (0.35 + n * 1.1), 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, pow(a, 1.2)))
		_puff = ImageTexture.create_from_image(img)
	return _puff


static func ring_texture():
	if _ring == null:
		var g = Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.add_point(0.72, Color(1, 1, 1, 0))
		g.add_point(0.9, Color(1, 1, 1, 1))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var t = GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 128
		t.height = 128
		_ring = t
	return _ring
