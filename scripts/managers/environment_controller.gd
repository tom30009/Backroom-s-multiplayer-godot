extends WorldEnvironment

func _ready():
	SettingsManager.quality_preset_changed.connect(_update_quality)
	# Применяем сразу при старте
	_update_quality(SettingsManager.low_quality_mode)

func _update_quality(is_low: bool):
	if not environment: return

	# --- [ЖЕЛЕЗНОЕ ПРАВИЛО] ---
	# Всегда держим выключенными глючные технологии, 
	# даже если настройки графики "Высокие".
	environment.sdfgi_enabled = false
	environment.ssil_enabled = false
	
	# --- НАСТРОЙКИ КАЧЕСТВА ---
	if is_low:
		# РЕЖИМ "КАРТОШКА":
		# Выключаем вообще всё дорогое
		environment.volumetric_fog_enabled = false
		environment.ssao_enabled = false # Тени в углах
		environment.ssr_enabled = false  # Отражения
	else:
		# РЕЖИМ "СТАНДАРТ":
		# Включаем только то, что красиво и НЕ ГЛЮЧИТ
		environment.volumetric_fog_enabled = true # Туман (атмосфера)
		environment.ssao_enabled = true           # Объем в углах
		environment.ssr_enabled = true            # Отражения на полу