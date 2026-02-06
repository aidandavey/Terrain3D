#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// ------------------------------------------------------------
// Mode / tool constants
// ------------------------------------------------------------
const uint OP_ADD = 0u;
const uint OP_SUBTRACT = 1u;
const uint OP_AVERAGE = 2u;
const uint OP_GRADIENT = 3u;

const uint TOOL_SCULPT = 0u;
const uint TOOL_HEIGHT = 1u; // extend as needed

// ------------------------------------------------------------
// Brush data layout
// ------------------------------------------------------------
struct BrushData {
	uint operation; // OP_*
	uint tool; // TOOL_*
	uint gradient_count; // 0, 1, 2
	uint _pad0; // padding

	float strength;
	float height; // used for HEIGHT tool or AVG value
	float radius;
	float _pad1;

	vec3 global_pos; // brush_global_position
	float _pad2;

	vec3 operation_movement; // _operation_movement
	float _pad3;

	vec2 brush_offset; // brush_offset
	vec2 _pad4;

	vec3 gradient_point1; // gradient_points[0]
	float _pad5;

	vec3 gradient_point2; // gradient_points[1]
	float _pad6;
};

// ------------------------------------------------------------
// Brushdata Buffer
// ------------------------------------------------------------

layout(std430, binding = 1) buffer BrushBuf {
	BrushData brush;
};

// ------------------------------------------------------------
// Heightmap SSBO
// ------------------------------------------------------------
layout(std430, binding = 0) buffer HeightmapBuf {
	float height_data[];
};

layout(push_constant) uniform PushConsts {
	uint u_width;
	uint u_height;
}
pc;

// ------------------------------------------------------------
// Helpers
// ------------------------------------------------------------
float safe_value(float v) {
	return (isnan(v) || isinf(v)) ? 0.0 : v;
}
uint index_from_coord(ivec2 coord) {
	return uint(coord.y) * pc.u_width + uint(coord.x);
}

// ------------------------------------------------------------
// Main
// ------------------------------------------------------------
void main() {
	ivec2 coord = ivec2(gl_GlobalInvocationID.xy);

	if (coord.x < 0 || coord.y < 0 ||
			coord.x >= int(pc.u_width) || coord.y >= int(pc.u_height)) {
		return;
	}

	uint idx = index_from_coord(coord);

	float srcf = height_data[idx];
	srcf = safe_value(srcf);
	float destf = srcf;

	// Compute pixel position region space
	vec2 pixel = vec2(coord);

	// Brush center in same space
	vec2 center = brush.global_pos.xz;

	// Compute distance
	float dist = distance(pixel, center);

	// Compute falloff
	//float alpha = 1.0 - smoothstep(brush.radius, 0.0, dist);
	float alpha = smoothstep(brush.radius, 0.0, dist);

	// Multiply by strength
	alpha *= brush.strength;

	// Clamp
	alpha = clamp(alpha, 0.0, 1.0);

	// --------------------------------------------------------
	// ADD / SUBTRACT
	// --------------------------------------------------------
	if (brush.operation == OP_ADD || brush.operation == OP_SUBTRACT) {
		bool is_add = (brush.operation == OP_ADD);
		float sign = is_add ? 1.0 : -1.0;

		if (brush.tool == TOOL_HEIGHT) {
			destf = mix(srcf, brush.height, alpha);
		} else if (length(brush.operation_movement) > 0.0) {
			float delta = alpha * brush.strength;
			float brush_center_y = brush.global_pos.y + sign * delta;

			float lo = srcf + (is_add ? 0.0 : -delta);
			float hi = srcf + (is_add ? delta : 0.0);

			destf = clamp(brush_center_y, lo, hi);
		} else {
			destf = srcf + sign * (alpha * brush.strength);
		}
	}
	// --------------------------------------------------------
	// AVERAGE
	// --------------------------------------------------------
	else if (brush.operation == OP_AVERAGE) {
		float avg = brush.height; // precomputed on CPU
		float t = clamp(alpha * brush.strength * 2.0, 0.02, 1.0);
		destf = mix(srcf, avg, t);
	}
	// --------------------------------------------------------
	// GRADIENT
	// --------------------------------------------------------
	else if (brush.operation == OP_GRADIENT && brush.gradient_count == 2u) {
		vec2 p1 = brush.gradient_point1.xz;
		vec2 p2 = brush.gradient_point2.xz;
		vec2 dir = p2 - p1;

		if (dot(dir, dir) > 0.01) {
			vec2 brush_xz = brush.global_pos.xz;

			if (length(brush.operation_movement) > 0.0) {
				vec2 move = normalize(brush.operation_movement.xz);
				float offset = dot(brush.brush_offset, move);
				brush_xz = vec2(
						brush.global_pos.x + move.x * offset,
						brush.global_pos.z + move.y * offset);
			}

			float weight = dot(normalize(dir), brush_xz - p1) / length(dir);
			weight = clamp(weight, 0.0, 1.0);

			float h = mix(brush.gradient_point1.y, brush.gradient_point2.y, weight);
			destf = mix(srcf, h, alpha);
		}
	}

	// Write back to SSBO
	height_data[idx] = destf;
}
