extends NavigationObstacle3D

@export var domain = Constants.Match.Navigation.Domain.TERRAIN
@export var path_height_offset = 0.0

const PixelSprite = preload("res://source/match/units/traits/PixelSprite.gd")
## Anteil der Sprite-Kantenlaenge, der als Boden-Grundflaeche eines Gebaeudes gilt
const FOOTPRINT_FACTOR = 0.4
## Radius liegt etwas ueber der Wegfindungs-Grundflaeche, damit Einheiten (Agentenradius 0.9) das Gebaeude "beruehren" koennen
const ADHERENCE_RING = 0.4

@onready var _match = find_parent("Match")
@onready var _unit = get_parent()


func _ready():
	_fit_footprint_to_sprite()
	await get_tree().process_frame  # wait for navigation to be operational
	set_navigation_map(_match.navigation.get_navigation_map_rid_by_domain(domain))
	_align_unit_position_to_navigation()
	_affect_navigation_if_needed()


func _exit_tree():
	if affect_navigation_mesh:
		remove_from_group(Constants.Match.Navigation.DOMAIN_TO_GROUP_MAPPING[domain])
		MatchSignals.schedule_navigation_rebake.emit(domain)


func _align_unit_position_to_navigation():
	_unit.global_transform.origin = (
		NavigationServer3D.map_get_closest_point(
			get_navigation_map(), get_parent().global_transform.origin
		)
		- Vector3(0, path_height_offset, 0)
	)


func _affect_navigation_if_needed():
	if affect_navigation_mesh:
		add_to_group(Constants.Match.Navigation.DOMAIN_TO_GROUP_MAPPING[domain])
		MatchSignals.schedule_navigation_rebake.emit(domain)


## Grundflaeche (Wegfindungs-Hindernis, Auswahl-, Ziel- und Platzierungsradius) an die
## sichtbare Sprite-Groesse des Gebaeudes anpassen, damit Einheiten nicht unter/in Gebaeude laufen.
func _fit_footprint_to_sprite():
	if domain != Constants.Match.Navigation.Domain.TERRAIN:
		return
	if not "type" in _unit or not _unit.type in PixelSprite.ANIM_BUILDING_TYPES:
		return
	var footprint = (
		PixelSprite.ANIM_WORLD_SIZES.get(_unit.type, 4.0)
		* PixelSprite.BUILDING_SCALE
		* FOOTPRINT_FACTOR
	)
	footprint = max(footprint, radius - ADHERENCE_RING)
	var points = PackedVector3Array()
	for i in range(8):
		var angle = TAU * i / 8.0
		points.append(Vector3(sin(angle), 0.0, -cos(angle)) * footprint)
	vertices = points
	radius = footprint + ADHERENCE_RING
	for sibling in _unit.get_children():
		if sibling != self and ("radius" in sibling) and sibling.name in ["Selection", "Targetability"]:
			sibling.radius = footprint + ADHERENCE_RING
