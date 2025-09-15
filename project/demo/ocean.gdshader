// Shader adapted from https://docs.godotengine.org/en/4.4/tutorials/shaders/your_first_shader/your_second_3d_shader.html

shader_type spatial;

render_mode specular_schlick_ggx;

group_uniforms controls;
uniform float sea_level = 50.0;
uniform vec3 color : source_color = vec3(0.1, 0.3, 0.5);
uniform float height_scale = 0.5;
uniform float uv_scale = 20.0;

group_uniforms textures;
uniform sampler2D noise;
uniform sampler2D normalmap;

uniform sampler2D screen_tex : hint_screen_texture;

varying float v_vertex_xz_dist;
varying vec3 v_vertex;
varying vec2 tex_position;

float wave(vec2 position){
  position += texture(noise, position / 10.0).x * 2.0 - 1.0;
  vec2 wv = 1.0 - abs(sin(position));
  return pow(1.0 - pow(wv.x * wv.y, 0.65), 4.0);
}

float get_height(vec2 position, float time) {
  float d = wave((position + time) * 0.4) * 0.3;
  d += wave((position - time) * 0.3) * 0.3;
  d += wave((position + time) * 0.5) * 0.2;
  d += wave((position - time) * 0.6) * 0.2;
  return d;
}

void vertex() {
	// Get vertex of flat plane in world coordinates and set world UV
	v_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tex_position = v_vertex.xz / 2.0 + 0.5 * uv_scale;
	float height = get_height(tex_position, TIME);
	VERTEX.y = sea_level + (height * height_scale);
	NORMAL = normalize(vec3(height - get_height(tex_position + vec2(0.1, 0.0), TIME), 0.1, height - get_height(tex_position + vec2(0.0, 0.1), TIME)));
}

void fragment() {
	float fresnel = sqrt(1.0 - dot(NORMAL, VIEW));
	RIM = 0.2;
	METALLIC = 0.0;
	ROUGHNESS = 0.01;
	vec3 screen_clr = texture(screen_tex, SCREEN_UV).rgb;
	vec3 final_clr = mix(color.rgb, screen_clr, dot(VIEW, NORMAL));
	ALBEDO = final_clr + (0.1 * fresnel);
}