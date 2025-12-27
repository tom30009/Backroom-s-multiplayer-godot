extends Control

const MAIN_MENU_PATH = "res://scenes/ui/main_menu.tscn"

# Путь к кнопке (проверь, совпадает ли он с твоей сценой!)
@onready var btn_restart = $CenterContainer/VBoxContainer/Btn_Restart 

func _ready():
	hide()
	
	# Кнопку рестарта видит только Хост
	if multiplayer.is_server():
		btn_restart.show()
	else:
		btn_restart.hide()

func toggle_menu():
	visible = not visible
	
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- УМНЫЙ ПОИСК ИГРОКА ---
func _find_player():
	var node = self
	# Поднимаемся вверх по дереву, пока не найдем ноду с нужной функцией
	while node:
		if node.has_method("restart_level_rpc"):
			return node
		node = node.get_parent()
	return null

# --- КНОПКИ ---

func _on_btn_resume_pressed():
	toggle_menu()

func _on_btn_restart_pressed():
	if multiplayer.is_server():
		print("Пауза: Попытка рестарта...")
		
		var player = _find_player()
		
		if player:
			print("Пауза: Игрок найден -> ", player.name)
			player.restart_level_rpc.rpc()
			toggle_menu()
		else:
			print("ОШИБКА: Меню паузы не смогло найти Игрока (скрипт player.gd)!")

func _on_btn_quit_pressed():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file(MAIN_MENU_PATH)