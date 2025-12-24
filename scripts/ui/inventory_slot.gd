extends PanelContainer

@onready var icon_node = $Icon

func set_item(item: ItemData):
	if item.icon:
		icon_node.texture = item.icon
	else:
		# Если иконки нет, ставим цветную заглушку или дефолтную картинку
		icon_node.texture = null 
		
	# Тут можно добавить тултип (подсказку при наведении)
	tooltip_text = item.name + "\n" + item.description