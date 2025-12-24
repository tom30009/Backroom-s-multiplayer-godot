shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	// Вычисляем расстояние от центра экрана (0.5, 0.5)
	vec2 uv = UV - vec2(0.5);
	float dist = length(uv);

	// Создаем мягкий круг.
	// smoothstep(внутренний_радиус, внешний_радиус, текущая_дистанция)
	// Чем больше intensity, тем меньше "чистый" круг в центре.
	float radius = 1.0 - intensity * 0.5;
	float alpha = smoothstep(radius - 0.4, radius, dist);

	// Применяем черный цвет с вычисленной прозрачностью
	COLOR = vec4(color.rgb, alpha * intensity * 2.0); // Умножаем, чтобы усилить эффект
}