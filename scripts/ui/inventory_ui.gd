extends Control

# Ссылка на сцену слота, чтобы мы могли создавать её копии
const SLOT_SCENE = preload("res://scenes/ui/inventory_slot.tscn")

@onready var grid = $Panel/GridContainer

func _ready():
	# При старте ищем игрока и его инвентарь
	# В сетевой игре важно найти ИМЕННО СВОЕГО игрока
	# Т.к. UI создается локально, мы можем просто подождать игрока.
	await get_tree().process_frame # Ждем кадр, чтобы игрок успел создаться
	
	var my_id = multiplayer.get_unique_id()
	var player = get_tree().current_scene.find_child(str(my_id), true, false)
	
	if player:
		var inventory = player.get_node("Inventory")
		if inventory:
			# Подписываемся на обновление данных
			inventory.inventory_updated.connect(update_display.bind(inventory))
			# Первый раз обновляем вручную
			update_display(inventory)

func update_display(inventory):
	# 1. Очищаем старые слоты
	for child in grid.get_children():
		child.queue_free()
	
	# 2. Создаем новые
	# Используем range, чтобы получить индекс 'i' (0, 1, 2...)
	for i in range(inventory.items.size()):
		var item = inventory.items[i]
		var slot = SLOT_SCENE.instantiate()
		grid.add_child(slot)
		
		# --- ВОТ ЗДЕСЬ БЫЛА ОШИБКА ---
		# Раньше было: slot.set_item(item)
		# Теперь нужно передать ДВА аргумента: предмет и его номер
		slot.set_item(item, i)
		
		# Подключаем нажатие кнопки
		if not slot.slot_clicked.is_connected(inventory.use_item_by_index):
			slot.slot_clicked.connect(inventory.use_item_by_index)

func _input(event):
	# Открытие/Закрытие на TAB
	if event.is_action_pressed("toggle_inventory"): # Добавь эту кнопку в настройках!
		visible = not visible
		
		# Освобождаем или захватываем мышку
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
