class_name Interactable
extends StaticBody3D

# Этот метод будут вызывать клиенты, когда нажмут E
func interact():
    # Отправляем запрос на сервер
    rpc_id(1, "_server_interact")

# Этот метод выполняется ТОЛЬКО на сервере
@rpc("any_peer", "call_local", "reliable")
func _server_interact():
    pass # В каждой конкретной двери/предмете мы перепишем эту часть