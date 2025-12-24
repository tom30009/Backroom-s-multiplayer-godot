class_name Inventory
extends Node

const MAX_SLOTS = 12 # <-- ЛИМИТ

var items: Array[ItemData] = []
signal inventory_updated

# Функция возвращает true, если предмет удалось добавить
func add_item(item: ItemData) -> bool:
	if items.size() >= MAX_SLOTS:
		print("ИНВЕНТАРЬ ПОЛОН! Не могу подобрать ", item.name)
		return false # Места нет
		
	items.append(item)
	print("Подобран предмет: " + item.name)
	inventory_updated.emit()
	return true

func has_item(item_name: String) -> bool:
	for i in items:
		if i.name == item_name:
			return true
	return false

# RPC для клиентов (вызывается сервером)
@rpc("any_peer", "call_local", "reliable") 
func add_item_rpc(item_path: String):
	# Клиенту проверки не нужны, он просто отображает то, что сказал сервер
	var item = load(item_path) as ItemData
	if item:
		items.append(item)
		inventory_updated.emit()

# Вызывается, когда мы кликаем по слоту в UI
func use_item_by_index(index: int):
	# Проверка на ошибки
	if index < 0 or index >= items.size(): return
	
	var item = items[index]
	var used_successfully = false
	
	# СМОТРИМ ТИП ПРЕДМЕТА
	match item.type:
		ItemData.Type.BATTERY:
			var player = get_parent()
			# Теперь мы проверяем результат функции
			if player.has_method("recharge_battery"):
				# Если зарядка прошла успешно (вернуло true) -> удаляем предмет
				if player.recharge_battery(50.0):
					used_successfully = true
				else:
					# Если вернуло false -> НЕ удаляем
					used_successfully = false
				
		ItemData.Type.CONSUMABLE:
			# Тут будет логика для еды/аптечек
			print("Съели: ", item.name)
			used_successfully = true
			
		ItemData.Type.KEY:
			print("Ключи нельзя использовать просто так, ими открывают двери!")
			used_successfully = false # Не тратим ключ при клике
			
	# Если предмет использован — удаляем его
	if used_successfully:
		items.remove_at(index)
		inventory_updated.emit() # Обновляем UI

