extends Resource

@export var color = Color.BLUE
@export var controller = Constants.PlayerType.SIMPLE_CLAIRVOYANT_AI
@export var spawn_index_offset = 0
@export var team = 0  # 0 = kein Team (jeder gegen jeden)
@export var peer_id = 0  # 0 = KI oder lokaler Spieler offline
