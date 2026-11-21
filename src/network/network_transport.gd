class_name NetworkTransport
extends RefCounted

const BACKEND_ENET: String = "enet"

var backend: String = BACKEND_ENET


static func is_supported_backend(backend_name: String) -> bool:
	return backend_name.to_lower().strip_edges() == BACKEND_ENET


func create_host(port: int, max_clients: int = 4) -> MultiplayerPeer:
	var selected := backend.to_lower().strip_edges()
	match selected:
		BACKEND_ENET:
			return create_host_peer(port, max_clients)
		_:
			push_error("NetworkTransport: unsupported backend '%s'" % backend)
			return null


func create_client(address: String, port: int) -> MultiplayerPeer:
	var selected := backend.to_lower().strip_edges()
	match selected:
		BACKEND_ENET:
			return create_client_peer(address, port)
		_:
			push_error("NetworkTransport: unsupported backend '%s'" % backend)
			return null


func create_host_peer(port: int, max_clients: int = 4) -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("*")
	var err := peer.create_server(port, max_clients)
	if err != OK:
		push_error("NetworkTransport: failed to create host peer on port %d (err %d)" % [port, err])
		return null
	return peer


func create_client_peer(address: String, port: int) -> ENetMultiplayerPeer:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		push_error("NetworkTransport: failed to create client peer for %s:%d (err %d)" % [address, port, err])
		return null
	return peer
