extends Node

const LOCAL_PORT := 9000
const EXTERN_PORT := 9000
const BIND_ADDRESS := "*"
const SERVER_ADDRESS := "192.168.1.178"
#const SERVER_ADDRESS := "127.0.0.1"
const MAX_CLIENTS := 10
const DEDICATED_SERVER := "dedicated_server"

var local_port: int
var bind_address: String
var max_clients: int

var enet_peer := ENetMultiplayerPeer.new()
var http_client := HTTPClient.new()
var player_names := {}
var code := ""
var thread: Thread

enum NET_STATUS {LOBBY, IN_GAME, FINISHED}
var status := NET_STATUS.LOBBY

signal peer_connected

class MatchInfo:
	var code: String
	var num_players: int
	var max_players: int
	var private: bool

class HttpResp:
	var data: Dictionary
	var err: Error

func get_env_or(env: String, default: Variant) -> Variant:
	var res: Variant = OS.get_environment(env)
	return (res if res else default)

func _ready() -> void:
	bind_address = get_env_or('BIND_ADDRESS', BIND_ADDRESS)
	local_port = get_env_or('LOCAL_PORT', LOCAL_PORT)
	max_clients = get_env_or('MAX_CLIENTS', MAX_CLIENTS)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	http_client.blocking_mode_enabled = true

	if OS.has_feature(Network.DEDICATED_SERVER):
		thread = Thread.new()
		thread.start(healthcheck)

func client_join_ip(extern_port:=EXTERN_PORT, server_address:=SERVER_ADDRESS) -> Error:
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_server_connected)
	multiplayer.server_disconnected.connect(_on_server_disconnect)
	var err := enet_peer.create_client(server_address, extern_port)
	if err:
		printerr('Failed to connect to server: ' + str(err))
		return err
	multiplayer.multiplayer_peer = enet_peer

	return OK

func client_join_match(join_code: String, extern_port:=EXTERN_PORT, server_address:=SERVER_ADDRESS) -> Error:
	var res = http_connect()
	if res:
		return res
	var resp := http_post('/join-match', {"code": join_code, "password": ""})
	if resp.err:
		printerr("failed to join online match")
		return resp.err

	client_join_ip(extern_port, server_address)

	return OK

func client_create_match(max_players: int, private: bool, extern_port:=EXTERN_PORT, server_address:=SERVER_ADDRESS) -> Error:
	var res = http_connect()
	if res:
		return res
	var resp := http_post('/create-match', {"max_players": max_players, "private": private})
	if resp.err:
		printerr("Failed to create online match")
		return resp.err

	code = resp.data['code']

	client_join_ip(extern_port, server_address)

	return OK

func server_create_match() -> Error:
	enet_peer.set_bind_ip(bind_address if bind_address else "*")
	var err := enet_peer.create_server(local_port, max_clients)
	if err:
		printerr('Failed to host server: ' + error_string(err))
		return err
	multiplayer.multiplayer_peer = enet_peer

	return OK

func get_matches() -> Array[MatchInfo]:
	var res = http_connect()
	if res:
		return []
	var resp := http_get('/get-matches', {})
	if resp.err:
		return []
	var matches: Array[MatchInfo] = []
	for m in resp.data['matches']:
		var new_match := MatchInfo.new()
		new_match.code = m['code']
		new_match.max_players = m['maxPlayers']
		new_match.num_players = m['numPlayers']
		new_match.private = m['private']
		matches.append(new_match)
	return matches

func get_player_name(peer_id: int) -> String:
	if player_names.has(peer_id):
		return player_names[peer_id]
	return str(peer_id)

@rpc('any_peer', 'call_local', 'reliable')
func set_player_name(new_name: String) -> void:
	player_names[multiplayer.get_remote_sender_id()] = new_name
	sync_player_names.rpc(player_names)
	peer_connected.emit(multiplayer.get_remote_sender_id())

@rpc('any_peer', 'reliable')
func sync_player_names(new_names) -> void:
	player_names.merge(new_names)

func _on_peer_connected(peer_id: int) -> void:
	print("%d: %d connected" % [multiplayer.get_unique_id(), peer_id])

func _on_peer_disconnected(peer_id: int) -> void:
	print("%d: %d disconnected" % [multiplayer.get_unique_id(), peer_id])

func _on_server_connected() -> void:
	print(str(multiplayer.get_unique_id()) + ": connected to server")

func reset() -> void:
	enet_peer = ENetMultiplayerPeer.new()
	multiplayer.multiplayer_peer = null

func _on_connection_failed() -> void:
	print(str(multiplayer.get_unique_id()) + ": failed to connect to server")
	reset()

func _on_server_disconnect() -> void:
	print(str(multiplayer.get_unique_id()) + ": disconnected from server")
	reset()

func healthcheck() -> void:
	var client = StreamPeerTCP.new()
	if client.connect_to_host("", 9001) != OK:
		printerr("failed to start healthcheck")
		return
	#tcp_server.listen(9001, "*")
	#while !tcp_server.is_connection_available(): pass
	#var stream := tcp_server.take_connection()
	print("healthcheck connected")
	while client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		client.poll()
		while client.get_available_bytes() > 0:
			var msg = client.get_utf8_string(client.get_available_bytes()).strip_escapes()
			if msg == "keepalive":
				client.put_utf8_string(NET_STATUS.keys()[status].to_lower())
			elif msg == "shutdown":
				get_tree().quit()
	printerr("lost connection to host. shutting down")
	#get_tree().quit(1)

func http_wait_for_status(h: HTTPClient, s: int, to: float) -> Error:
	var t := 0.0
	while t < to:
		h.poll()
		if h.get_status() == s:
			return OK
		t += get_process_delta_time()
	printerr("http timeout")
	return ERR_TIMEOUT

func http_connect() -> Error:
	http_client.connect_to_host("http://"+SERVER_ADDRESS, 8000)
	var res = http_wait_for_status(http_client, HTTPClient.STATUS_CONNECTED, 30)
	if res:
		printerr("Failed to connect to http server")
	return res

func http_request(method: HTTPClient.Method, endpoint: String, fields: Dictionary) -> HttpResp:
	var ret := HttpResp.new()
	var query = http_client.query_string_from_dict(fields)
	var headers = ["Content-Length: 0"]
	var result = http_client.request(method, endpoint+"?"+query, headers)
	var res = http_wait_for_status(http_client, HTTPClient.STATUS_BODY, 30)
	if res:
		ret.err = res
		return ret
	var resp_code = http_client.get_response_code()
	if resp_code != 200:
		printerr("Got Status %d from server" % resp_code)
		ret.err = ERR_QUERY_FAILED
		return ret
	var resp_body = http_client.read_response_body_chunk() # TODO: wait for more chunks
	var json_string = resp_body.get_string_from_utf8()
	var parsed_json = JSON.parse_string(json_string)
	if !parsed_json:
		ret.err = ERR_INVALID_DATA
		printerr("invalid json")
		return ret
	ret.data = parsed_json
	return ret

func http_get(endpoint: String, fields: Dictionary) -> HttpResp:
	return http_request(HTTPClient.METHOD_GET, endpoint, fields)

func http_post(endpoint: String, fields: Dictionary) -> HttpResp:
	return http_request(HTTPClient.METHOD_POST, endpoint, fields)
