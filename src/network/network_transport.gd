class_name NetworkTransport
extends RefCounted


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
