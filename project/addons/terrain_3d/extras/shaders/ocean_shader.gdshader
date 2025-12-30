shader_type spatial;
render_mode cull_back, depth_draw_always, diffuse_burley, specular_schlick_ggx, skip_vertex_transform;

// Shader adapted from https://docs.godotengine.org/en/4.4/tutorials/shaders/your_first_shader/your_second_3d_shader.html

//////////////////////////////
// Constants
//////////////////////////////
const int ITERATIONS_VERTEX = 1;
const int ITERATIONS_FRAGMENT =3;

//////////////////////////////
// Uniforms
//////////////////////////////
group_uniforms water;
uniform float time_scale : hint_range(0.0, 16.0) = 3.0;
uniform float height_scale : hint_range(0.0, 16.0) = 3.0;
uniform float ocean_scale : hint_range(0.1, 64.0, 0.1) = 4.0;
uniform float sea_level : hint_range(-50.0, 50.0, 0.1) = 12.0;
uniform vec3 albedo_color : source_color = vec3(.102, .212, .318);
uniform float visible_depth : hint_range(0., 10000., .1) = 256.;
uniform float depth_curve : hint_range(0., 1.) = .2;
uniform float edge_fade_distance : hint_range(0.0, 10.0, 0.01) = 1.;
uniform float refraction_strength : hint_range(0.0, 0.1, 0.001) = 0.07;
uniform sampler2D water_noise : filter_linear_mipmap, repeat_enable;

group_uniforms light_scattering;

uniform bool _light_scattering_enabled = true;

uniform vec3 _light_direction;
uniform vec3 _light_color : source_color = vec3(1.0, 1.0, .735);
uniform float height_scattering : hint_range(0.0, 15.0) = 3.0;
uniform float height_threshold : hint_range(0.0, 1.0) = 0.1;
uniform float height_angle_threshold : hint_range(0.0, 1.0) = 0.21;

uniform float fersnel_scattering : hint_range(0.0, 70.0) = 20.0;
uniform float direct_scattering : hint_range(0.0, 70.0) = 15.0;

uniform float depth_absorbtion : hint_range(0.0, 10.0) = 1.0;

group_uniforms;
group_uniforms reflections;
uniform float fresnel_scale : hint_range(0., 1.) = .065;
uniform float fresnel_power = 1.;
uniform float specular : hint_range(0., 1.) = .5;
group_uniforms;

group_uniforms foam;
uniform bool foam_enabled = true;
uniform sampler2D foam_alpha;
uniform float foam_height : hint_range(-2.0, 5.0) = 2.5;
uniform float foam_scale : hint_range(0.1, 5.0) = 1.5;
// Uniforms set by C++
group_uniforms private_dont_touch;
uniform float _mesh_size = 32.;
uniform float _subdiv = 1.;
uniform float _vertex_spacing = 1.;
uniform float _vertex_density = 1.;
uniform vec3 _target_pos = vec3(0.,0.,0.);
group_uniforms;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

varying float vertex_distance;

//////////////////////////////
// Ocean Noise
//////////////////////////////

float octave(vec2 uv) {
	float n = texture(water_noise, uv).r;
	return 1.0 - 2.0 * n;
}

vec2 rotateUV(vec2 uv, float rotation) {
	float mid = 0.5;
	return vec2(
		cos(rotation) * (uv.x - mid) + sin(rotation) * (uv.y - mid) + mid,
		cos(rotation) * (uv.y - mid) - sin(rotation) * (uv.x - mid) + mid
	);
}

float get_base_height(vec2 pos, float multiplier, int iterations) {
	float freq = multiplier * ocean_scale;
	float amp = 4.0;
	vec2 uv = pos;
	uv.x *= 0.6;
	float h = 0.0;
	float t = TIME * time_scale / freq * 0.004;

	for (int i = 0; i < iterations; i++) {
	    h += (octave((uv + t) * freq) + octave((uv - t) * freq * 0.89)) * amp;
	   // rotate uv to avoid repetition
	 	uv = rotateUV(uv, 0.2);
		
		// offset smaller waves by the movement of bigger ones
		uv -= h / freq * 0.004;
		
	    freq *= 2.0;
	    amp *= 0.15;
	}
    return h * 0.1 * height_scale;
}
float ocean_height(vec2 pos, int iterations) {
	float giant_wave = get_base_height(pos, 0.00007, iterations );
	float big_wave = get_base_height(pos, 0.0008, iterations);
	float detail_wave = get_base_height(pos, 0.02, iterations);
	return big_wave + detail_wave * 0.02 + giant_wave * 2.0;
}

//////////////////////////////
// Vertex
//////////////////////////////

void vertex() {
    // Get vertex of flat plane in world coordinates and set world UV
    vec3 vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float scale = MODEL_MATRIX[0][0];
    float inv_scale = 1.0 / scale;
    float vertex_xz_distance = max(abs(vertex.x - _target_pos.x), abs(vertex.z - _target_pos.z));
    float vertex_lerp = smoothstep(0.0, 1.0, (vertex_xz_distance * inv_scale - _mesh_size - 4.0) / (_mesh_size - 4.0));
    vec2 v_fract = fract(VERTEX.xz * 0.5) * 2.0;
    // For LOD0 morph from a regular grid to an alternating grid to align with LOD1+
    vec2 shift = (scale < _vertex_spacing / _subdiv + 1e-6) ? // LOD0 or not
        // Shift from regular to symmetric
        mix(v_fract, vec2(v_fract.x, -v_fract.y),
            round(fract(round(mod(vertex.z * inv_scale, 4.0)) *
            round(mod(vertex.x * inv_scale, 4.0)) * 0.25))) :
        // symmetric shift
        v_fract * round((fract(vertex.xz * 0.25 * inv_scale) - 0.5) * 4.0);
    vertex.xz -= shift * scale * vertex_lerp;

    UV = (vertex.xz);
	
	// add vertex on every axis for more complex displacement
    vertex += sea_level * vec3(0.0, 1.0, 0.0) + ocean_height(UV, ITERATIONS_VERTEX) * vec3(0.5, 1.0, 0.5);

    VERTEX = (VIEW_MATRIX * vec4(vertex, 1.0)).xyz;
	vertex_distance = length(vertex - _target_pos);
}

//////////////////////////////
// Fragment
//////////////////////////////

void fragment() {
	float h, u, v;
	// adjust normal domain as screen space distance increases to reduce high frequency values across pixels
	float dv = max(0.25, length(fwidth(VERTEX)));
	h = ocean_height(UV, ITERATIONS_FRAGMENT);
	u = ocean_height(UV + vec2(dv, 0.0), ITERATIONS_FRAGMENT);
	v = ocean_height(UV + vec2(0.0, dv), ITERATIONS_FRAGMENT);
	vec3 world_normal = normalize(vec3(h - u, dv * _vertex_density, h - v));
	NORMAL = mat3(VIEW_MATRIX) * world_normal;
	TANGENT = normalize(cross(NORMAL, VIEW_MATRIX[2].xyz));
	BINORMAL = normalize(cross(NORMAL, TANGENT));

	float fresnel = clamp(fresnel_scale * pow(1.0 + dot(VIEW, NORMAL), fresnel_power), 0., 1.);
	ROUGHNESS = fresnel;
	SPECULAR = specular;

	// Depth fade
	float alpha = 1. - depth_curve + depth_curve * smoothstep(.0, 1., vertex_distance/visible_depth);

	// Edge fade
	float proximity_depth_tex = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 proximity_view_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, proximity_depth_tex, 1.0);
	proximity_view_pos.xyz /= proximity_view_pos.w;
	float edge_mask = 1.0 - clamp(1.0 - smoothstep(proximity_view_pos.z + 2. * edge_fade_distance, proximity_view_pos.z, VERTEX.z), 0.0, 1.0);
	alpha = clamp(alpha - edge_mask, 0., 1.);
	
	// increase alpha with depth as more water means more light absorbed
	alpha = clamp(alpha+ min((VERTEX.z - proximity_view_pos.z) * 0.001 * depth_absorbtion, 1.0), 0.0, 1.0);
	
	// Refraction: Distort screen UVs using the normal (tangent-space projection)
	vec2 refract_offset = NORMAL.xz * refraction_strength;
	// limit refraction at the bottom edge of the screen as normals push away in view direction.
	float y_limit = 1.0 - smoothstep(.0, .25, 1.-SCREEN_UV.y);
	refract_offset = mix(refract_offset, vec2(0.), max(edge_mask, y_limit));
	vec2 refract_uv = SCREEN_UV + refract_offset;
	
	// Invert refract if target screenspace pixel is above ocean surface, replaces major artifact with minor one.
	proximity_depth_tex = textureLod(depth_texture, refract_uv, 0.0).r;
	proximity_view_pos = INV_PROJECTION_MATRIX * vec4(refract_uv * 2.0 - 1.0, proximity_depth_tex, 1.0);
	
	proximity_view_pos.xyz /= proximity_view_pos.w;
	
	refract_uv = SCREEN_UV + mix(refract_offset * (float(proximity_view_pos.z < VERTEX.z) * 2.0 - 1.0), vec2(0.), max(edge_mask, y_limit));
	
	vec3 final_color = albedo_color * _light_color;
	float foam_factor = 0.0;
	if (foam_enabled) {
		float detail_wave = get_base_height(UV, 0.005 * foam_scale, 2);
		float foam_texture_alpha = texture(foam_alpha, UV * 0.09 * foam_scale).r;
		foam_factor = clamp(h * 0.5 + (detail_wave * 2.0 +  edge_mask * 40.0) * foam_texture_alpha * 1.5 - foam_height,0.0, 1.0);
		
		final_color = mix(final_color, vec3(0.8), foam_factor);
	}
	if (_light_scattering_enabled) {
		// Approximate light scattering
		vec3 ray_dir = normalize(mat3(INV_VIEW_MATRIX) * VIEW);
		// light scattering based on height and sun angle
		vec3 light_factor = height_scattering * max(h, height_threshold) * max(pow(dot(normalize(_light_direction), -ray_dir), 4.0), height_angle_threshold) * _light_color * pow(0.5 - 0.5 * dot(normalize(_light_direction), world_normal), 3.0);
		// light scattering based on view angle
		light_factor += fersnel_scattering *pow(dot(ray_dir, world_normal), 2.0) * _light_color * albedo_color;
		// direct light scattering
		light_factor += direct_scattering * dot(normalize(_light_direction), world_normal) * albedo_color * _light_color;
		BACKLIGHT = light_factor * 4.0 * clamp(alpha, 0.4, 1.0) * max(1.0 - foam_factor, 0.5);
	}
	
	vec3 background = texture(screen_texture, refract_uv).rgb;
	ALBEDO = mix(background, final_color, alpha * alpha);
	ALPHA = clamp(1.0 - edge_mask, 0., 1.);


}