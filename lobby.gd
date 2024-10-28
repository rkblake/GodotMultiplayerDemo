extends Control

@export var game_scene: PackedScene

@onready var left_players_text: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/LeftPlayers
@onready var right_players_text: RichTextLabel = $MarginContainer/VBoxContainer/HBoxContainer/RightPlayers
@onready var chat: RichTextLabel = $MarginContainer/VBoxContainer/Chat
@onready var chat_prompt: LineEdit = $MarginContainer/VBoxContainer/ChatPrompt
@onready var label: Label = $MarginContainer/VBoxContainer/Label

var left_players: Array = []
var right_players: Array = []
var players_ready = {}

func _ready():
	if !multiplayer.is_server():
		label.text = "Code: " + Network.code if Network.code != "" else "No code"
		return
	if !OS.has_feature(Network.DEDICATED_SERVER): add_left(1)
	Network.peer_connected.connect(_on_player_join)
	multiplayer.peer_disconnected.connect(_on_player_leave)
	Network.status = Network.NET_STATUS.LOBBY


func _on_player_join(peer_id):
	if peer_id == 1 and OS.has_feature(Network.DEDICATED_SERVER):
		return
	if multiplayer.is_server():
		send_server_message.rpc(Network.get_player_name(peer_id) + " has joined")
		left_players.append(peer_id)
		sync_players.rpc(left_players, right_players)

func _on_player_leave(peer_id):
	if multiplayer.is_server():
		players_ready[multiplayer.get_remote_sender_id()] = false
		send_server_message.rpc(Network.get_player_name(peer_id) + " has left")
	left_players.erase(peer_id)
	right_players.erase(peer_id)
	update_players()

@rpc('any_peer', 'call_local', 'reliable')
func sync_players(new_left_players: Array, new_right_players: Array) -> void:
	left_players = new_left_players
	right_players = new_right_players
	update_players()

@rpc('any_peer', 'call_local', 'reliable')
func add_left(peer_id) -> void:
	left_players.append(peer_id)
	update_players()

@rpc('any_peer', 'call_local', 'reliable')
func move_left() -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not peer_id in right_players:
		return
	right_players.erase(peer_id)
	left_players.append(peer_id)
	update_players()

func _on_move_left_pressed() -> void:
	move_left.rpc()

@rpc('any_peer', 'call_local', 'reliable')
func move_right() -> void:
	var peer_id = multiplayer.get_remote_sender_id()
	if not peer_id in left_players:
		return
	left_players.erase(peer_id)
	right_players.append(peer_id)
	update_players()

func _on_move_right_pressed() -> void:
	move_right.rpc()


func _on_ready_pressed(toggle: bool) -> void:
	player_ready.rpc(toggle)

@rpc('call_local', 'reliable')
func start_game():
	get_tree().change_scene_to_packed(game_scene)

@rpc('any_peer', 'call_local', 'reliable')
func player_ready(ready: bool):
	#if multiplayer.is_server():
	players_ready[multiplayer.get_remote_sender_id()] = ready
	var num_ready = 0
	for v in players_ready.values():
		if v:
			num_ready += 1
	if num_ready == left_players.size() + right_players.size() and multiplayer.is_server():
		start_game.rpc()
	update_players()

func update_players() -> void:
	var prefix = "[ul]\n"
	var suffix = "[/ul]"
	var names = ""

	for player_id in left_players:
		names += escape_bbcode(Network.get_player_name(player_id)) + (" (Ready)" if player_id in players_ready and players_ready[player_id] else "") + "\n"
	for _i in range(5-len(left_players)):
		names += "Empty\n"
	left_players_text.text = prefix + names + suffix

	names = ""
	for player_id in right_players:
		names += escape_bbcode(Network.get_player_name(player_id)) + (" (Ready)" if player_id in players_ready and players_ready[player_id] else "") + "\n"
	for _i in range(5-len(right_players)):
		names += "Empty\n"
	right_players_text.text = prefix + names + suffix

func escape_bbcode(bbcode_text):
	return bbcode_text.replace("[", "[lb]")

@rpc('any_peer', 'call_local', 'reliable')
func send_message(msg: String) -> void:
	chat.append_text('[b]' + \
				escape_bbcode(Network.get_player_name(multiplayer.get_remote_sender_id())) + \
				":[/b] " + \
				escape_bbcode(msg) + "\n")

@rpc('any_peer', 'call_local', 'reliable')
func send_server_message(msg: String) -> void:
	chat.append_text('[b]' + msg + '[/b]\n')

func _on_chat_prompt_text_submitted(new_text: String) -> void:
	if new_text == '': return
	send_message.rpc(new_text)
	chat_prompt.text = ''
