class_name Inventory
extends Node

const MAX_SLOTS = 12

var items: Array[ItemData] = []
signal inventory_updated

# Функция возвращает true, если предмет удалось добавить
func add_item(item: ItemData) -> bool:
	if items.size() >= MAX_SLOTS:
		print("ИНВЕНТАРЬ ПОЛОН! Не могу подобрать ", item.name)
		return false
		
	items.append(item)
	print("Подобран предмет: " + item.name)
	inventory_updated.emit()
	return true

# Проверка наличия предмета (для дверей)
func has_item(item_name: String) -> bool:
	for i in items:
		if i.name == item_name:
			return true
	return false

# RPC для клиентов (визуальное добавление)
@rpc("any_peer", "call_local", "reliable") 
func add_item_rpc(item_path: String):
	# Проверка отправителя (опционально)
	# if multiplayer.get_remote_sender_id() != 1: return

	var item = load(item_path) as ItemData
	if item:
		items.append(item)
		inventory_updated.emit()

# Использование предмета
func use_item_by_index(index: int):
	if index < 0 or index >= items.size(): return
	
	var item = items[index]
	var used_successfully = false
	
	match item.type:
		ItemData.Type.BATTERY:
			var player = get_parent()
			# Пытаемся зарядить фонарик
			if player.has_method("recharge_battery"):
				# Если зарядили (вернуло true) - удаляем предмет
				if player.recharge_battery(50.0):
					used_successfully = true
				else:
					used_successfully = false # Батарейка полная, не тратим
					
		ItemData.Type.CONSUMABLE:
			print("Съели: ", item.name)
			used_successfully = true
			
		ItemData.Type.KEY:
			print("Ключ нельзя использовать, им открывают двери!")
			used_successfully = false
			
	if used_successfully:
		items.remove_at(index)
		inventory_updated.emit()

# Вызывается сервером при смерти
func drop_all_items(drop_position: Vector3):
	# Находим уровень (корневую ноду)
	# ВАЖНО: Путь "/root/level" должен совпадать с именем корня твоей сцены!
	# Если сцена называется "Level0", то пиши "/root/Level0".
	# Универсальный способ - искать по группе или брать get_tree().current_scene
	var level = get_tree().current_scene
	
	if not level.has_method("spawn_dropped_item"):
		print("ОШИБКА: Сцена уровня не имеет метода spawn_dropped_item")
		return

	print("Инвентарь: Выбрасываем ", items.size(), " предметов...")

	for item in items:
		var type_string = ""
		
		# Определяем, что это за предмет
		match item.type:
			ItemData.Type.KEY:
				type_string = "key"
			ItemData.Type.BATTERY:
				type_string = "battery"
			# Если добавишь записки, не забудь: 
			# ItemData.Type.NOTE: type_string = "note"
		
		if type_string != "":
			level.spawn_dropped_item(type_string, drop_position)
	
	# Очищаем инвентарь после сброса
	items.clear()
	inventory_updated.emit()