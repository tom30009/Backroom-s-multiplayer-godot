extends Button 

@onready var icon_node = $Icon

# Мы будем хранить индекс слота, чтобы знать, какую вещь удалять
var slot_index: int = -1

# Сигнал, который поймает главное меню инвентаря
signal slot_clicked(index)

func _ready():
	# Подключаем нажатие кнопки к отправке нашего сигнала
	pressed.connect(_on_pressed)

func _on_pressed():
	if slot_index != -1:
		slot_clicked.emit(slot_index)

func set_item(item: ItemData, index: int): # <-- Добавили аргумент index
	slot_index = index
	if item.icon:
		icon_node.texture = item.icon
	else:
		icon_node.texture = null
	tooltip_text = item.name
