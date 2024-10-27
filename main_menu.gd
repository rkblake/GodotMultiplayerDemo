extends Control

@onready var create_match: Button = $CenterContainer/VBoxContainer/CreateMatch
@onready var join_match: Button = $CenterContainer/VBoxContainer/HBoxContainer/JoinMatch
@onready var browse_games: Button = $CenterContainer/VBoxContainer/BrowseGames
@onready var quit: Button = $CenterContainer/VBoxContainer/Quit
@onready var host_local: Button = $CenterContainer/VBoxContainer/HostLocal
@onready var code: LineEdit = $CenterContainer/VBoxContainer/HBoxContainer/Code
@onready var create_match_modal: PopupPanel = $CreateMatchModal
@onready var create: Button = $CreateMatchModal/VBoxContainer/Create
@onready var max_players: SpinBox = %MaxPlayers
@onready var private_toggle: CheckButton = %PrivateToggle
@onready var username: LineEdit = $CenterContainer/VBoxContainer/Username
@onready var show_local: Button = $CenterContainer/VBoxContainer/JoinLocal
@onready var join_local: Button = $JoinIpModal/VBoxContainer/Join
@onready var ip: LineEdit = %IP
@onready var port: SpinBox = %Port

@export var lobby_scene: PackedScene
@export var game_browser_scene: PackedScene

func _ready() -> void:
	if OS.has_feature(Network.DEDICATED_SERVER):
		print("Running dedicated server")
		Network.server_create_match()
		await get_tree().process_frame
		get_tree().change_scene_to_packed(lobby_scene)
	else:
		create_match.pressed.connect(func(): create_match_modal.popup())
		join_match.pressed.connect(_on_join_pressed)
		#host_local.pressed.connect(func(): Network.server_create_match(); get_tree().change_scene_to_packed(lobby_scene))
		browse_games.pressed.connect(func(): get_tree().change_scene_to_packed(game_browser_scene))
		quit.pressed.connect(func(): get_tree().quit())
		create.pressed.connect(_on_create_pressed)
		#multiplayer.connected_to_server.connect(_on_connect_server)
		show_local.pressed.connect(func(): $JoinIpModal.popup())
		#join_local.pressed.connect(func(): Network.client_join_ip(port.value, ip.text); get_tree().change_scene_to_packed(lobby_scene))
		multiplayer.connected_to_server.connect(_on_connect_server)


#func _on_username_text_changed(new_text: String) -> void:
	#Network.set_player_name(new_text)

func _on_host_local_pressed() -> void:
	if len(username.text) == 0: print("enter a username"); return
	Network.server_create_match()
	Network.set_player_name.rpc(username.text)
	get_tree().change_scene_to_packed(lobby_scene)

func _on_join_local_pressed() -> void:
	if len(username.text) == 0: print("enter a username"); return
	Network.client_join_ip(port.value, ip.text)
	#Network.set_player_name.rpc(username.text)
	#await get_tree().process_frame
	#get_tree().change_scene_to_packed(lobby_scene)

func _on_create_pressed() -> void:
	if len(username.text) == 0: print("enter a username"); return
	Network.client_create_match(int(max_players.value), private_toggle.toggle_mode)
	#Network.set_player_name.rpc(username.text)
	await get_tree().process_frame
	get_tree().change_scene_to_packed(lobby_scene)

func _on_join_pressed() -> void:
	if len(username.text) == 0: print("enter a username"); return
	Network.client_join_match(code.text)
	#Network.set_player_name.rpc(username.text)
	#await get_tree().process_frame
	#get_tree().change_scene_to_packed(lobby_scene)

func _on_connect_server() -> void:
	Network.set_player_name.rpc(username.text)
	get_tree().change_scene_to_packed(lobby_scene)
