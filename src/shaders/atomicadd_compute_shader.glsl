#[compute]
#version 450
//#extension GL_OES_standard_derivatives : enable
#extension GL_NV_compute_shader_derivatives : enable

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 0) restrict buffer CommandBuffer { int data[]; } command_buffer;

layout(std430, binding = 1) restrict buffer TransformBuffer { float data[]; } transform_buffer;

layout(std430, binding = 2) restrict buffer OutputCounter { int index; } output_counter; //has to be another buffer as it gets wiped each run.

layout(push_constant, std430) uniform Params {
	vec4[6] FrustumPlanes;
	float CleanupPass;
	float SurfaceCount;
	float ViewDistance;
	float PlayerX;
	float PlayerY;
	float PlayerZ;
} params;



bool isInsideFrustum(vec3 position, vec4[6] frustumPlanes) {
    for (int i = 0; i < 6; i++) {
        vec4 plane = frustumPlanes[i];
        if (dot(plane.xyz, position) > plane.w) {
            return false;
        }
    }
    return true;
}

bool isInsideFrustumWithRange(vec3 position, float instanceSize, vec4[6] frustumPlanes) {
    return isInsideFrustum(position, frustumPlanes) ||
		isInsideFrustum(position + vec3(instanceSize, 0.0, 0.0), frustumPlanes) ||
		isInsideFrustum(position + vec3(-instanceSize, 0.0, 0.0), frustumPlanes) ||
		isInsideFrustum(position + vec3(0.0, 0.0, instanceSize), frustumPlanes) ||
		isInsideFrustum(position + vec3(0.0, 0.0, -instanceSize), frustumPlanes) ||
		isInsideFrustum(position + vec3(0.0, instanceSize, 0.0), frustumPlanes) ||
		isInsideFrustum(position + vec3(0.0, -instanceSize, 0.0), frustumPlanes);
}

float PHI = 1.61803398874989484820459;  // Φ = Golden Ratio   

float gold_noise(vec2 xy, in float seed){
       return (fract(tan(distance(xy*PHI, xy)*seed)*xy.x) * 2.0) - 1.0;
}

mat3 rotateY(float angle) {
	float s = sin(angle);
	float c = cos(angle);

  	return mat3(
		c, 0.0, s,
		0.0, 1.0, 0.0,
		-s, 0.0, c
	);
}


void main() {
	float seperation = 0.2;
	if (params.CleanupPass == 1.0){
		for(int i = 0; i < int(params.SurfaceCount); i++){
			command_buffer.data[(i * 5) + 1] = output_counter.index; 
		}
		output_counter.index = 0;
	}
	else{
		vec3 newPosition = vec3(gl_GlobalInvocationID.x * seperation, 0.0, gl_GlobalInvocationID.y * seperation);
		newPosition.x += gold_noise(newPosition.xz, 1.0) * seperation / 2.0;
		newPosition.z += gold_noise(newPosition.xz, 1337.0) * seperation / 2.0;
		vec3 playerPosition = vec3(params.PlayerX, params.PlayerY, params.PlayerZ);

		if (distance(newPosition, playerPosition) < params.ViewDistance && isInsideFrustumWithRange(newPosition, 4.0, params.FrustumPlanes)){
			
			int lastCount = atomicAdd(output_counter.index, 1); //adds one to it and gets the new number to set the command buffer.
			mat3 newTransform = rotateY(gold_noise(newPosition.xz, 1337.0) * 365.0);
			
			int transformIndex = lastCount * 20;
			transform_buffer.data[transformIndex] = newTransform[0][0];
			transformIndex += 1;
			transform_buffer.data[transformIndex] = newTransform[0][1];
			transformIndex += 1;
			transform_buffer.data[transformIndex] = newTransform[0][2];
			transformIndex += 1;
			transform_buffer.data[transformIndex] = newPosition.x;
			transformIndex += 1;

			//y
			transform_buffer.data[transformIndex] = newTransform[1][0];
			transformIndex += 1;
			transform_buffer.data[transformIndex] = newTransform[1][1];
			transformIndex += 1;
			transform_buffer.data[transformIndex] = newTransform[1][2];
			transformIndex += 1;
			transform_buffer.data[transformIndex] = newPosition.y;
			transformIndex += 1;

			//z
			transform_buffer.data[transformIndex] = newTransform[2][0];
			transformIndex += 1;
			transform_buffer.data[transformIndex] = newTransform[2][1];
			transformIndex += 1;
			transform_buffer.data[transformIndex] = newTransform[2][2];
			transformIndex += 1;
			transform_buffer.data[transformIndex] = newPosition.z;
			transformIndex += 1;

			//color
			transform_buffer.data[transformIndex] = 1.0;
			transformIndex += 1;
			transform_buffer.data[transformIndex] = 1.0;
			transformIndex += 1;
			transform_buffer.data[transformIndex] = 1.0;
			transformIndex += 1;
			transform_buffer.data[transformIndex] = 1.0;
			transformIndex += 1;

			//Custom data
			transform_buffer.data[transformIndex] = 1.0;
			transformIndex += 1;
			transform_buffer.data[transformIndex] = 1.0;
			transformIndex += 1;
			transform_buffer.data[transformIndex] = 1.0;
			transformIndex += 1;
			transform_buffer.data[transformIndex] = 1.0;
			transformIndex += 1;

			// lastCount += 1; //gets current total.
			// lastCount = atomicMax(command_buffer.data[1], lastCount);
			// for(int i = 0; i < int(params.SurfaceCount); i++){
			// 	command_buffer.data[(i * 5) + 1] = lastCount; 
			// }
		}
	}
}



