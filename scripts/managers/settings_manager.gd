extends Node

# Сигнал, чтобы Уровень знал, что надо отключить туман/свет
signal quality_preset_changed(is_low_quality)

var low_quality_mode = false

func _ready():
	# Ограничиваем FPS, чтобы видеокарта не плавилась при тесте 3-х окон
	Engine.max_fps = 60 

# 1. ПОЛНЫЙ ЭКРАН
func set_fullscreen(toggled: bool):
	if toggled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# 2. МАСШТАБ РЕНДЕРА (Самое важное для FPS!)
# value: от 0.5 (мыло/быстро) до 1.0 (четко/медленно)
func set_resolution_scale(value: float):
	get_viewport().scaling_3d_scale = value

# 3. V-SYNC (Убирает разрывы, экономит ресурсы)
func set_vsync(toggled: bool):
	if toggled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

# 4. РЕЖИМ "КАРТОШКИ" (Отключение тяжелых эффектов)
func set_low_quality(toggled: bool):
	low_quality_mode = toggled
	
	# Меняем настройки теней глобально
	if toggled:
		# Низкое качество
		RenderingServer.directional_shadow_atlas_set_size(1024, true)
		get_viewport().positional_shadow_atlas_size = 1024
	else:
		# Высокое качество
		RenderingServer.directional_shadow_atlas_set_size(4096, true)
		get_viewport().positional_shadow_atlas_size = 4096
	
	# Отправляем сигнал, чтобы WorldEnvironment на уровне отключил SDFGI/Туман
	quality_preset_changed.emit(toggled)

func set_volume(value: float):
	# Получаем индекс главной шины (Master)
	var bus_index = AudioServer.get_bus_index("Master")
	
	# value у нас от 0.0 до 1.0
	# Godot использует децибелы (dB). 
	# linear_to_db превращает 0.5 в -6dB, 0 в -бесконечность и т.д.
	
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	
	# Если слайдер в самом низу - выключаем звук полностью (Mute)
	if value <= 0.05:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)