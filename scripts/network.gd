extends Node
# Autoload (name it "Network"). Handles hosting/joining (2 players max) and starting the game.
# Host = Human (peer id 1). Client = Mosquito.

signal players_changed(count: int)
signal join_failed
signal connection_lost

const PORT := 9999
const MAX_PLAYERS := 2
const LOBBY_SCENE := "res://scenes/lobby.tscn"
const GAME_SCENE := "res://scenes/game.tscn"  # <- change if your game scene lives elsewhere

var player_count: int = 0
var mosquito_id: int = 0
var online: bool = false
# Solo debug mode (no network). "human" or "mosquito". Empty = normal online game.
var debug_role: String = ""


func start_debug(role: String) -> void:
	leave()
	debug_role = role
	get_tree().change_scene_to_file(GAME_SCENE)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_host() -> bool:
	return online and multiplayer.is_server()


func host_game(port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	# max_clients = 1 -> the server refuses any third connection
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	player_count = 1
	mosquito_id = 0
	players_changed.emit(player_count)
	return OK


func join_game(ip: String, port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	online = true
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	# Never leave the peer null: Godot then errors on is_multiplayer_authority()
	# and nothing can move. The offline peer is the engine's normal "no network" state.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	online = false
	player_count = 0
	mosquito_id = 0


func start_game() -> void:
	if is_host() and player_count == MAX_PLAYERS:
		_start_game.rpc()


@rpc("authority", "call_local", "reliable")
func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func go_to_lobby() -> void:
	debug_role = ""
	leave()
	get_tree().change_scene_to_file(LOBBY_SCENE)


# --- connection callbacks ---

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		mosquito_id = id
		player_count = 2
		players_changed.emit(player_count)


func _on_peer_disconnected(_id: int) -> void:
	if multiplayer.is_server():
		mosquito_id = 0
		player_count = 1
		players_changed.emit(player_count)
		if get_tree().current_scene and get_tree().current_scene.scene_file_path == GAME_SCENE:
			connection_lost.emit()


func _on_connected_to_server() -> void:
	mosquito_id = multiplayer.get_unique_id()
	player_count = 2
	players_changed.emit(player_count)


func _on_connection_failed() -> void:
	leave()
	join_failed.emit()


func _on_server_disconnected() -> void:
	leave()
	connection_lost.emit()
