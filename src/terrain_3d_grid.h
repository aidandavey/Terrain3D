// Copyright © 2023-2026 Cory Petkovsek, Roope Palmroos, and Contributors.

#ifndef TERRAIN3D_GRID_CLASS_H
#define TERRAIN3D_GRID_CLASS_H

#include <godot_cpp/variant/callable.hpp>

#include "constants.h"

//class Terrain3D;

struct Cell {
	Vector2i location;
	Vector3 position;
	Vector3 global_position;
};

class Terrain3DGrid {
	CLASS_NAME_STATIC("Terrain3DGrid");

private:
	bool _initialized = false;
	bool _dirty = false;
	uint16_t _grid_width = 0;
	uint16_t _cell_count = 0;
	uint16_t _min_cell_size = 8;
	uint16_t _max_cell_size = 64;
	uint16_t _cell_size = 16;

	uint16_t _min_radius = 16;
	uint16_t _max_radius = 256;
	uint16_t _radius = 64;

	Vector2i _last_target_position;
	Vector2i _last_snapped_pos = V2I_MAX;
	Vector2i _grid_offset = V2I_ZERO;
	real_t _vertex_spacing = 1.f;

	//Vector2i _snap_to_grid(const Vector2i &p_pos) const;
	//Vector2i _snap_to_grid(const Vector3 &p_pos) const;
	void _update_grid_width();

public:
	Terrain3DGrid() {}
	~Terrain3DGrid() { destroy(); }

	void initialize(const uint16_t p_cell_size, const uint16_t p_radius);
	void destroy();

	bool is_initialized() const { return _initialized; }
	bool is_dirty() const { return _dirty; }
	bool is_in_radius(const Vector3 &p_pos) const;

	uint16_t get_grid_width() const { return _grid_width; }
	uint16_t get_cell_count() const { return _cell_count; }
	Vector2i get_grid_offset() const { return _grid_offset; }

	uint16_t get_min_cell_size() const { return _min_cell_size; }
	void set_min_cell_size(const uint16_t p_min_cell_size) { _min_cell_size = p_min_cell_size; }
	uint16_t get_max_cell_size() const { return _max_cell_size; }
	void set_max_cell_size(const uint16_t p_max_cell_size) { _max_cell_size = p_max_cell_size; }
	uint16_t get_cell_size() const { return _cell_size; }
	void set_cell_size(const uint16_t p_cell_size);
	uint16_t get_min_radius() const { return _min_radius; }
	void set_min_radius(const uint16_t p_min_radius) { _min_radius = p_min_radius; }
	uint16_t get_max_radius() const { return _max_radius; }
	void set_max_radius(const uint16_t p_max_radius) { _max_radius = p_max_radius; }
	uint16_t get_radius() const { return _radius; }
	void set_radius(const uint16_t p_radius);
	real_t get_radius_sqr() const { return real_t(_radius * _radius); }

	Vector2i get_snapped_position() const { return _last_snapped_pos; }
	Vector2i get_grid_corner() const { return _last_snapped_pos + _grid_offset * _cell_size; }
	void snap(const Vector3 &p_target_pos, const real_t &p_spacing, const bool p_rebuild = false);
	void reset_target_position() { _last_target_position = V2I_MAX; }
	void update();
};
// Inline Functions

#endif // TERRAIN3D_GRID_CLASS_H
