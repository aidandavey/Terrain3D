#ifndef TERRAIN3D_ZONE_LOADER_CLASS_H
#define TERRAIN3D_ZONE_LOADER_CLASS_H

#include <godot_cpp/classes/node3d.hpp>

#include "constants.h"

// Forward declarations to avoid a circular include with terrain_3d.h
class Terrain3D;
class Terrain3DRegion;

class Terrain3DZoneLoader : public Node3D {
	GDCLASS(Terrain3DZoneLoader, Node3D);
	CLASS_NAME();

private:
	bool _data_loaded = false;
	Terrain3D *_terrain;
	Ref<Terrain3DRegion> _region;
	Node *instance = nullptr;
	Array _region_object_nodes;
	// File I/O
	Error _save(const String &p_path = "");

public:
	void initialize(Terrain3D *p_terrain);
	void load();
	void save();
	void clear();
	void set_region(Ref<Terrain3DRegion> p_region);

	// Editor button accessors.
	// These are "momentary" properties: the setter triggers the action when true.
	// The getter always returns false so the checkbox in the inspector appears untoggled.
	void set_load_button(bool p_pressed);
	bool get_load_button() const;

	void set_save_button(bool p_pressed);
	bool get_save_button() const;

	void set_clear_button(bool p_pressed);
	bool get_clear_button() const;

protected:
	static void _bind_methods();
};

#endif // TERRAIN3D_ZONE_LOADER_CLASS_H