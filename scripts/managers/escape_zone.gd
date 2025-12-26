extends Area3D

# Путь к сцене лобби (чтобы вернуться)
const LOBBY_SCENE = "res://scenes/ui/Lobby.tscn" # Проверь путь!



func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Игрок сбежал: ", body.name)
		# Вызываем победу для всех
		win_game.rpc()

@rpc("any_peer", "call_local", "reliable")
func win_game():
	# Тут можно показать экран "YOU ESCAPED"
	print("!!! ПОБЕДА !!!")
	
	# Показываем мышку
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Отключаемся от сети и идем в меню (простой вариант)
	multiplayer.multiplayer_peer = null
	get_tree().change_scene_to_file(LOBBY_SCENE)
