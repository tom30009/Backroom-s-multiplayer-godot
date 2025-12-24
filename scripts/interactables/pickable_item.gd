extends Interactable

@export var item_data: ItemData

# Эта функция вызывается, когда игрок нажимает "E"
@rpc("any_peer", "call_local", "reliable")
func _server_interact():
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1
	
	print("СЕРВЕР: Запрос на подбор от ID: ", sender_id) # <--- ОТЛАДКА 1
	
	var player_node = get_tree().current_scene.find_child(str(sender_id), true, false)
	
	if player_node:
		# Обрати внимание: тут должно быть имя точно как в сцене!
		var inventory = player_node.get_node_or_null("Inventory") 
		
		if inventory:
			print("СЕРВЕР: Инвентарь найден! Отправляю предмет...") # <--- ОТЛАДКА 2
			inventory.add_item_rpc.rpc_id(sender_id, item_data.resource_path)
			_destroy_self.rpc()
		else:
			print("ОШИБКА: Игрок найден, но нода Inventory не найдена!") # <--- ЕСЛИ ТУТ
			
			# 2. Удаляем предмет У ВСЕХ
			# Вызываем функцию _destroy_self на всех подключенных компах
			_destroy_self.rpc()

# Эта функция выполнится на всех компьютерах (сервере и клиентах)
@rpc("authority", "call_local", "reliable")
func _destroy_self():
	queue_free()