extends Interactable

@export var item_data: ItemData

@rpc("any_peer", "call_local", "reliable")
func _server_interact():
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1
	
	var player_node = get_tree().current_scene.find_child(str(sender_id), true, false)
	
	if player_node:
		var inventory = player_node.get_node_or_null("Inventory")
		if inventory:
			# ШАГ 1: Пробуем добавить предмет на СЕРВЕРЕ
			# (Сервер хранит копию инвентаря игрока, поэтому может проверить лимит)
			var success = inventory.add_item(item_data)
			
			if success:
				# ШАГ 2: Если влезло -> Синхронизируем с клиентом (чтобы он увидел иконку)
				# ВАЖНО: Если sender_id == 1 (Хост), у него уже добавилось в шаге 1 (call_local не нужен тут),
				# но чтобы не усложнять, просто отправим RPC только КЛИЕНТУ, если это не хост.
				
				if sender_id != 1:
					inventory.add_item_rpc.rpc_id(sender_id, item_data.resource_path)
				
				# ШАГ 3: Удаляем предмет из мира
				_destroy_self.rpc()
			else:
				# Места нет - ничего не делаем, предмет остается лежать
				print("Сервер: У игрока нет места.")

@rpc("authority", "call_local", "reliable")
func _destroy_self():
	queue_free()