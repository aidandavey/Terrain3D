// Copyright © 2025 Cory Petkovsek, Roope Palmroos, and Contributors.

#ifndef TERRAIN3D_COMPUTE_CLASS_H
#define TERRAIN3D_COMPUTE_CLASS_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/classes/rd_uniform.hpp>
#include <godot_cpp/classes/rendering_device.hpp>
#include <godot_cpp/variant/typed_array.hpp>

#include "constants.h"
#include "terrain_3d_region.h"

struct BrushData {
	uint32_t operation;
	uint32_t tool;
	uint32_t gradient_count;
	uint32_t _pad0 = 0;

	float strength;
	float height;
	float radius;
	float _pad1 = 0;

	Vector3 global_pos;
	float _pad2 = 0;

	Vector3 operation_movement;
	float _pad3 = 0;

	Vector2 brush_offset;
	Vector2 _pad4 = Vector2(0, 0);

	Vector3 gradient_point1;
	float _pad5 = 0;

	Vector3 gradient_point2;
	float _pad6 = 0;
};

struct PushConsts {
	uint32_t width = 1024;
	uint32_t height = 1024;
	uint32_t _pad0;
	uint32_t _pad1;
};

class Terrain3D;

class Terrain3DCompute : public Object {
	GDCLASS(Terrain3DCompute, Object);
	CLASS_NAME_STATIC("Terrain3DCompute");

public:
	void initialize(Terrain3D *p_terrain);
	void destroy();

	void despatch_compute(Ref<Terrain3DRegion> p_region, const BrushData &p_brush_data);
	bool create_uniforms();
	RID get_height_shader() const { return _height_shader; }

	BrushData _brush_data;

private:
	Terrain3D *_terrain = nullptr;
	bool _initialized = false;
	RID _image_dims_rid = RID();
	RID _brush_buffer_rid = RID();
	RID _height_shader = RID();
	RID _height_pipeline = RID();
	RID _heightmap_ssbo_rid = RID();
	RID _uniform_set_rid = RID();
	RenderingDevice *_rd = nullptr;
	TypedArray<RDUniform> _uniforms;

	Vector3 _from_pos = Vector3(0, 0, 0);
	Vector3 _to_pos = Vector3(0, 0, 0);
	Vector3 _size = Vector3(1024, 0, 1);
	real_t _width = 1024.0f;
	real_t _height = 1024.0f;

	uint32_t _src_mip = 0;
	uint32_t _dst_mip = 0;
	uint32_t _src_layer = 0;
	uint32_t _dst_layer = 0;
	PushConsts image_dims;

	Ref<Image> _img;

	RID _load_shader(String p_path);

protected:
	static void _bind_methods();
};

#endif // TERRAIN3D_COMPUTE_CLASS_H
