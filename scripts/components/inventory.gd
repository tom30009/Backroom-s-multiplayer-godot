class_name Inventory
extends Node
var items: Array[ItemData] = []
signal inventory_updated

func add_item(item: ItemData):
	items.append(item)
	print("Подобран предмет: " + item.name)
	inventory_updated.emit()

func has_item(item_name: String) -> bool:
	for i in items:
		if i.name == item_name:
			return true
	return false


@rpc("any_peer", "call_local", "reliable") 
func add_item_rpc(item_path: String):
	# (Опционально) Защита от читеров: проверяем, что команду прислал Сервер
	if multiplayer.get_remote_sender_id() != 1:
		return 

	var item = load(item_path) as ItemData
	if item:
		add_item(item)