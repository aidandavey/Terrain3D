#include "terrain_3d_compute.h"

#include <godot_cpp/classes/rd_shader_file.hpp>
#include <godot_cpp/classes/rd_shader_spirv.hpp>
#include <godot_cpp/classes/rd_texture_format.hpp>
#include <godot_cpp/classes/rd_texture_view.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/resource_loader.hpp>

#include "logger.h"

///////////////////////////
// Public Functions
///////////////////////////

void Terrain3DCompute::initialize(Terrain3D *p_terrain) {
	_terrain = p_terrain;
	_rd = RS->create_local_rendering_device();
	_height_shader = _load_shader("res://addons/terrain_3d/compute/height.glsl");
	_height_pipeline = _rd->compute_pipeline_create(_height_shader);
	if (!_height_pipeline.is_valid()) {
		LOG(ERROR, "Failed to create compute pipeline for height shader");
		return;
	}
	if (!_img.is_valid()) {
		_img.instantiate();
	}
	_initialized = true;
	LOG(INFO, "Terrain3DCompute initialized successfully");
}

void Terrain3DCompute::destroy() {
	if (_height_shader.is_valid()) {
		_rd->free_rid(_height_shader);
		_height_shader = RID();
	}
}

void Terrain3DCompute::despatch_compute(Ref<Terrain3DRegion> p_region, const BrushData &p_brush_data) {
	if (!_initialized) {
		LOG(ERROR, "Cannot dispatch compute shader: Terrain3DCompute is not initialized");
		return;
	}
	// Should check if region is valid or not

	LOG(DEBUG, "Starting dispatch");
	PackedByteArray brush_bytes;
	brush_bytes.resize(sizeof(BrushData));
	memcpy(brush_bytes.ptrw(), &p_brush_data, sizeof(BrushData));

	if (!_brush_buffer_rid.is_valid()) {
		_brush_buffer_rid = _rd->storage_buffer_create(sizeof(BrushData), brush_bytes);
	}

	Error err = _rd->buffer_update(_brush_buffer_rid, 0, sizeof(BrushData), brush_bytes);
	if (err != Error::OK) {
		LOG(ERROR, "Failed to update brush data buffer: ", err);
		return;
	}

	size_t pixel_count = size_t(_width) * size_t(_height);
	size_t pxl_byte_size = pixel_count * sizeof(float);

	PackedByteArray pxl_bytes;
	pxl_bytes.resize(pxl_byte_size);

	// Fill from CPU image
	PackedByteArray img_data = p_region->get_height_map()->get_data(); // RF: 4 bytes per pixel
	memcpy(pxl_bytes.ptrw(), img_data.ptr(), pxl_byte_size);

	if (!_heightmap_ssbo_rid.is_valid()) {
		_heightmap_ssbo_rid = _rd->storage_buffer_create(pxl_byte_size, pxl_bytes);
	} else {
		_rd->buffer_update(_heightmap_ssbo_rid, 0, pxl_byte_size, pxl_bytes);
	}

	_width = p_region->get_height_map()->get_width();
	_height = p_region->get_height_map()->get_height();
	_size = Vector3(_width, _height, 1);

	PackedInt32Array dims;
	dims.push_back(_width);
	dims.push_back(_height);
	PackedByteArray dim_data = dims.to_byte_array();

	// Fill from
	memcpy(dim_data.ptrw(), dim_data.ptr(), sizeof(dim_data));

	if (!create_uniforms()) {
		LOG(ERROR, "Failed to create uniform set for height compute shader");
		return;
	}

	// Update the image to be passed as a push constant instead of a uniform buffer since it's only 2 uints and we want to avoid the overhead of a buffer update for every dispatch
	image_dims.height = p_region->get_height_map()->get_height();
	image_dims.width = p_region->get_height_map()->get_width();

	PackedByteArray image_dims_bytes;
	image_dims_bytes.resize(sizeof(PushConsts));
	memcpy(image_dims_bytes.ptrw(), &image_dims, sizeof(PushConsts));

	LOG(DEBUG, "Ready to dispatch compute");

	uint32_t gx = (p_region->get_height_map()->get_width() + 7) / 8;
	uint32_t gy = (p_region->get_height_map()->get_height() + 7) / 8;
	uint32_t gz = 1;

	int64_t list = _rd->compute_list_begin();

	_rd->compute_list_bind_compute_pipeline(list, _height_pipeline);
	_rd->compute_list_bind_uniform_set(list, _uniform_set_rid, 0);
	_rd->compute_list_set_push_constant(list, image_dims_bytes, sizeof(PushConsts));

	_rd->compute_list_dispatch(list, gx, gy, gz);

	_rd->compute_list_end();

	LOG(DEBUG, "Completed dispatch");

	// Note the bitwise or below
	// Barriers are inserted automatically by the rendering device so this is deprecated
	//_rd->barrier(RenderingDevice::BARRIER_MASK_COMPUTE, RenderingDevice::BARRIER_MASK_FRAGMENT | RenderingDevice::BARRIER_MASK_TRANSFER);

	// No longer required since we are using a storage buffer instead of a texture
	//Error err = _rd->texture_copy(staging_buffer_rid, _heightmap_ssbo_rid, _from_pos, _to_pos, _size, _src_mip, _dst_mip, _src_layer, _dst_layer);

	_img->set_data(_width, _height, false, Image::FORMAT_RF, _rd->buffer_get_data(_heightmap_ssbo_rid)); // FORMAT_RF, width × height

	p_region->set_height_map(_img);

	LOG(DEBUG, "Completed image update");

	// Update the GPU texture arrays so the changes are rendered
	Terrain3DData *data = _terrain->get_data();
	if (data) {
		// Update only the height map texture array layer for this region
		data->update_maps(TYPE_HEIGHT, false, false);
	}
}

bool Terrain3DCompute::create_uniforms() {
	if (!_heightmap_ssbo_rid.is_valid()) {
		LOG(ERROR, "Heightmap ssbo rid invalid, cannot create uniform set");
		return false;
	}

	if (!_brush_buffer_rid.is_valid()) {
		LOG(ERROR, "Brushbuffer rid invalid, cannot create uniform set");
		return false;
	}

	// Storage image (heightmap)
	{
		Ref<RDUniform> u;
		u.instantiate();
		u->set_binding(0);
		u->set_uniform_type(RenderingDevice::UNIFORM_TYPE_STORAGE_BUFFER);
		u->add_id(_heightmap_ssbo_rid);
		_uniforms.push_back(u);
	}

	// Brush data buffer
	{
		Ref<RDUniform> u;
		u.instantiate();
		u->set_binding(1);
		u->set_uniform_type(RenderingDevice::UNIFORM_TYPE_STORAGE_BUFFER);
		u->add_id(_brush_buffer_rid);
		_uniforms.push_back(u);
	}

	_uniform_set_rid = _rd->uniform_set_create(_uniforms, _height_shader, 0);
	if (!_uniform_set_rid.is_valid()) {
		LOG(ERROR, "Failed to create uniform set");
	}
	return _uniform_set_rid.is_valid();
}

///////////////////////////
// Private Functions
///////////////////////////

RID Terrain3DCompute::_load_shader(String p_path) {
	Ref<RDShaderFile> shader = ResourceLoader::get_singleton()->load(p_path);
	if (!shader.is_valid()) {
		LOG(ERROR, "Could not load shader at path: ", p_path);
		return RID();
	}

	RID shader_rid = _rd->shader_create_from_spirv(shader->get_spirv());
	if (shader_rid.is_valid()) {
		LOG(MESG, "Shader loaded successfully: ", p_path);
	}

	return shader_rid;
}

///////////////////////////
// Protected Functions
///////////////////////////

void Terrain3DCompute::_bind_methods() {
}
