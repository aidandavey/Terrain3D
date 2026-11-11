// Copyright © 2023-2026 Cory Petkovsek, Roope Palmroos, and Contributors.

#include "terrain_3d_grid.h"
#include "logger.h"

///////////////////////////
// Private Functions
///////////////////////////

void Terrain3DGrid::_update_grid_width() {
	uint16_t grid_width = _radius * 2 / _cell_size;
	_grid_width = int_ceil_pow2(grid_width, uint16_t(4));
	_cell_count = _grid_width * _grid_width;
	_grid_offset = -V2I(_grid_width / 2);
}

///////////////////////////
// Public Functions
///////////////////////////

void Terrain3DGrid::initialize(const uint16_t p_cell_size, const uint16_t p_radius) {
	LOG(INFO, "Initializing grid");
	set_cell_size(p_cell_size);
	set_radius(p_radius);
	_initialized = true;
	update();
	reset_target_position();
}

void Terrain3DGrid::destroy() {
	LOG(INFO, "Destroying grid");
	_initialized = false;
}

bool Terrain3DGrid::is_in_radius(const Vector3 &p_pos) const {
	return v3v2i(p_pos / _vertex_spacing).distance_squared_to(_last_snapped_pos) <= get_radius_sqr();
}

void Terrain3DGrid::set_cell_size(const uint16_t p_cell_size) {
	uint16_t size = CLAMP(p_cell_size, _min_cell_size, _max_cell_size);
	size = int_round_mult(size, uint16_t(8));
	SET_IF_DIFF(_cell_size, size);
	LOG(INFO, "Setting grid cell size: ", _cell_size);
	if (_cell_size > _radius - 8) {
		set_radius(_cell_size + 16);
	}
	_update_grid_width();
	update();
}

void Terrain3DGrid::set_radius(const uint16_t p_radius) {
	uint16_t radius = CLAMP(p_radius, _min_radius, _max_radius);
	radius = int_ceil_pow2(radius, uint16_t(16));
	SET_IF_DIFF(_radius, radius);
	LOG(INFO, "Setting grid radius: ", _radius);
	// Ensure size:radius always results in at least one valid shape
	if (_radius < _cell_size + 8) {
		set_cell_size(_radius - 8);
	} else if (_cell_size < 16 && _radius > 128) {
		set_cell_size(16);
	}
	_update_grid_width();
	update();
}

void Terrain3DGrid::snap(const Vector3 &p_target_pos, const real_t &p_spacing, const bool p_rebuild) {
	Vector2i snapped_pos = Util::snap_to_grid(p_target_pos / p_spacing, _cell_size);
	if (!p_rebuild && (_last_snapped_pos - snapped_pos).length_squared() == 0) {
		return;
	}
	_dirty = true;
	_last_snapped_pos = snapped_pos;
}

// Iterates over every instance of every mesh and updates all properties.
void Terrain3DGrid::update() {
	LOG(EXTREME, "Updating grid");
}
