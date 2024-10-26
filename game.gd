extends Node2D

@export var player_scene: PackedScene

@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

func _ready():
	spawner.spawn_function = spawn_player
	if multiplayer.is_server():
		await get_tree().create_timer(1.0).timeout # waiting for all clients to change scenes
		var peers = multiplayer.get_peers()
		if not OS.has_feature(Network.DEDICATED_SERVER):
			peers.append(multiplayer.get_unique_id())
		for peer in peers:
			spawner.spawn({'id':peer})

func spawn_player(data: Dictionary) -> Node:
	var player = player_scene.instantiate()
	player.name = str(data['id'])
	var theta = randf_range(0, TAU)
	player.position = Vector2(cos(theta), sin(theta))*400
	return player
