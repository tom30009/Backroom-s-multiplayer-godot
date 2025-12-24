class_name ItemData
extends Resource

enum Type { CONSUMABLE, KEY, BATTERY, NOTE }

@export var name: String = "Item Name"
@export_multiline var description: String = "Description here"
@export var icon: Texture2D
@export var type: Type
@export var stackable: bool = true