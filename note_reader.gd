extends Control

# Используем экспорт переменную, чтобы ты мог сам перетащить кнопку в инспекторе
# Это надежнее, чем писать путь руками ($TextureRect/Button)
@export var close_button: Button 
@export var content_label: Label

func _ready():
	hide() # Скрываем при старте
	
	# Проверка на ошибки
	if close_button:
		close_button.pressed.connect(close_note)
	else:
		print("ОШИБКА: Кнопка закрытия не привязана в NoteReader!")

func show_note(text: String):
	if content_label:
		content_label.text = text
	
	show() # Показываем саму панель NoteReader
	
	# Обязательно включаем мышь!
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_note():
	hide()
	# Возвращаем управление в игру
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED