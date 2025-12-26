extends Interactable

@export var item_data: ItemData

# Локальный вход (когда нажали E)
func interact():
	_server_interact.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func _server_interact():
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1
	
	var player_node = get_tree().current_scene.find_child(str(sender_id), true, false)
	
	if player_node:
		var inventory = player_node.get_node_or_null("Inventory")
		if inventory:
			# Добавляем в инвентарь (Логика данных)
			var success = inventory.add_item(item_data)
			
			if success:
				# 1. Если это Клиент - отправляем ему RPC, чтобы обновилась иконка
				if sender_id != 1:
					inventory.add_item_rpc.rpc_id(sender_id, item_data.resource_path)
				
				# 2. Удаляем предмет из мира
				# ВАЖНО: Просто queue_free() на сервере!
				# MultiplayerSpawner сам скажет всем клиентам удалить этот предмет.
				queue_free() 
			else:
				print("Сервер: Инвентарь полон.")