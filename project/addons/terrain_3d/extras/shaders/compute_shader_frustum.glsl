#[compute]
#version 450
//#extension GL_OES_standard_derivatives : enable
#extension GL_NV_compute_shader_derivatives : enable

// Instruct the GPU to use 16x16x1 = 256 local invocations per workgroup.
// this means each invocation will be responsible for 32x32 meters in the page file.
layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) restrict buffer CommandBuffer { int data[]; }
command_buffer;
layout(std430, binding = 1) restrict buffer ReferenceBuffer { float data[]; }
reference_buffer;
layout(std430, binding = 2) restrict buffer OutputBufferBuffer { float data[]; }
output_buffer;

layout(std430, binding = 3) restrict buffer OutputCounter { int index; }
output_counter; //has to be another buffer as it gets wiped each run.

layout(push_constant, std430) uniform Params {
	vec4 nearPlane; // Near plane: ax + by + cz + d = 0
	vec4 farPlane; // Far plane: ax + by + cz + d = 0
	vec4 leftPlane; // Left plane: ax + by + cz + d = 0
	vec4 topPlane; // Top plane: ax + by + cz + d = 0
	vec4 rightPlane; // Right plane: ax + by + cz + d = 0
	vec4 bottomPlane; // Bottom plane: ax + by + cz + d = 0

	float instanceCount;
}
params;

// Frustum culling for each instance
bool IsInFrustum(vec3 min, vec3 max) {
	// Get the 8 corners of the bounding box (AABB)
	vec3 corners[8];
	corners[0] = min;
	corners[1] = vec3(max.x, min.y, min.z);
	corners[2] = vec3(min.x, max.y, min.z);
	corners[3] = vec3(max.x, max.y, min.z);
	corners[4] = vec3(min.x, min.y, max.z);
	corners[5] = vec3(max.x, min.y, max.z);
	corners[6] = vec3(min.x, max.y, max.z);
	corners[7] = max;

	// Check if any corner is inside the frustum
	for (int i = 0; i < 8; ++i) {
		// Test against all 6 planes
		bool inside = true;
		inside = inside && dot(params.leftPlane.xyz, corners[i]) + params.leftPlane.w >= 0.0;
		inside = inside && dot(params.rightPlane.xyz, corners[i]) + params.rightPlane.w >= 0.0;
		inside = inside && dot(params.topPlane.xyz, corners[i]) + params.topPlane.w >= 0.0;
		inside = inside && dot(params.bottomPlane.xyz, corners[i]) + params.bottomPlane.w >= 0.0;
		inside = inside && dot(params.nearPlane.xyz, corners[i]) + params.nearPlane.w >= 0.0;
		inside = inside && dot(params.farPlane.xyz, corners[i]) + params.farPlane.w >= 0.0;

		// If any corner is inside, the instance is in the frustum
		if (inside) {
			return true;
		}
	}

	// If none of the corners are inside, discard the instance
	return false;
}

void main() {
	//int basecoords = int(gl_GlobalInvocationID.x);
	// output_buffer.data[0] = params.nearPlane.x;
	// output_buffer.data[1] = params.nearPlane.y;
	// output_buffer.data[2] = params.nearPlane.z;
	// output_buffer.data[3] = params.nearPlane.w;
	// output_buffer.data[4] = params.farPlane.x;
	// output_buffer.data[5] = params.farPlane.y;
	// output_buffer.data[6] = params.farPlane.z;
	// output_buffer.data[7] = params.farPlane.w;
	// output_buffer.data[8] = params.leftPlane.x;
	// output_buffer.data[9] = params.leftPlane.y;
	// output_buffer.data[10] = params.leftPlane.z;
	// output_buffer.data[11] = params.leftPlane.w;
	// output_buffer.data[12] = params.topPlane.x;
	// output_buffer.data[13] = params.topPlane.y;
	// output_buffer.data[14] = params.topPlane.z;
	// output_buffer.data[15] = params.topPlane.w;
	// output_buffer.data[16] = params.rightPlane.x;
	// output_buffer.data[17] = params.rightPlane.y;
	// output_buffer.data[18] = params.rightPlane.z;
	// output_buffer.data[19] = params.rightPlane.w;
	// output_buffer.data[20] = params.bottomPlane.x;
	// output_buffer.data[21] = params.bottomPlane.y;
	// output_buffer.data[22] = params.bottomPlane.z;
	// output_buffer.data[23] = params.bottomPlane.w;
	// output_buffer.data[24] = params.instanceCount;
	// int instanceCount = int(params.instanceCount);
	// output_buffer.data[25] = float(instanceCount);
	// output_buffer.data[26] = 0.0;
	// output_buffer.data[27] = 0.0;

	int basecoords = int(gl_GlobalInvocationID.x);

	int instanceCount = int(params.instanceCount);
	int instanceInvocationCount = instanceCount / 64;
	int startingIndex = basecoords * instanceInvocationCount;
	int endingIndex = startingIndex + instanceInvocationCount;
	mat4 thisInstance = mat4(0);
	vec3 instanceSize = vec3(10.0); //subtract from origin to get the min corner, add to get the max corner.
	vec3 instancePosition = vec3(0.0);

	int curIndex = 0;
	int newIndex = 0;
	for (int x = startingIndex; x < endingIndex; x++) {
		instancePosition.x = reference_buffer.data[curIndex + 3];
		instancePosition.y = reference_buffer.data[curIndex + 7];
		instancePosition.z = reference_buffer.data[curIndex + 11];

		if (IsInFrustum(instancePosition - instanceSize, instancePosition + instanceSize)) {
			newIndex = atomicAdd(output_counter.index, 1) * 20;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;

			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;

			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;

			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
			output_buffer.data[newIndex] = reference_buffer.data[curIndex];
			curIndex += 1;
			newIndex += 1;
		} else {
			curIndex += 20;
		}
	}

	command_buffer.data[1] = output_counter.index;
}
