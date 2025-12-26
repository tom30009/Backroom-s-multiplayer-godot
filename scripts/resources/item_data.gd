class_name ItemData
extends Resource

# Оставляем только базовые типы
enum Type { CONSUMABLE, KEY, BATTERY }

@export var name: String = "Item Name"
@export_multiline var description: String = "Description here"
@export var icon: Texture2D
@export var type: Type
@export var stackable: bool = true