// Copyright © 2025 Cory Petkovsek, Roope Palmroos, and Contributors.

#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/classes/scene_tree.hpp>

#include "logger.h"
#include "terrain_3d.h"
#include "terrain_3d_region.h"
#include "terrain_3d_util.h"
#include "terrain_3d_zone_loader.h"

void Terrain3DZoneLoader::initialize(Terrain3D *p_terrain) {
	// If another ZoneLoader exists on the terrain, do not initialize a second one.
	Node *existing = p_terrain->get_node_or_null(NodePath("ZoneLoader"));
	if (existing && existing != this) {
		// Ensure the persisted ZoneLoader has its runtime Terrain pointer set so
		// it can use get_data() later (avoids null/dangling _terrain use).
		Terrain3DZoneLoader *existing_loader = cast_to<Terrain3DZoneLoader>(existing);
		if (existing_loader) {
			existing_loader->set_terrain(p_terrain);
		}
		return;
	}

	_terrain = p_terrain;
	if (!_terrain) {
		LOG(ERROR, "Terrain3DZoneLoader::initialize called with null Terrain3D pointer");
		return;
	}

	set_name("ZoneLoader");
	_terrain->add_child(this);
	set_owner(_terrain->get_owner());

	// Add or restore sub nodes for regions
	_region_object_nodes.clear();

	// No pre-existing children: create runtime children from active regions.
	for (Ref<Terrain3DRegion> region : _terrain->get_data()->get_regions_active()) {
		Terrain3DZoneLoader *region_object_node = memnew(Terrain3DZoneLoader);
		region_object_node->set_terrain(_terrain);
		region_object_node->set_region(region);
		_region_object_nodes.push_back(region_object_node);
		add_child(region_object_node);
		region_object_node->set_owner(get_owner());
	}
}

void Terrain3DZoneLoader::load() {
	LOG(MESG, "Loading ", get_name());
	if (!_region_object_nodes.is_empty()) {
		for (int i = 0; i < _region_object_nodes.size(); i++) {
			Terrain3DZoneLoader *region_node = cast_to<Terrain3DZoneLoader>(_region_object_nodes[i]);
			region_node->load();
		}
		return;
	}
	if (_data_loaded) {
		LOG(MESG, get_name(), " is already loaded")
		return;
	}
	Ref<Terrain3DRegion> region = _terrain->get_data()->get_region(_region_location);
	if (!region.is_valid()) {
		LOG(ERROR, get_name(), " has invalid region pointer")
		return;
	}
	if (instance) {
		remove_child(instance);
		instance->queue_free();
		instance = nullptr;
	}
	Ref<PackedScene> packed_scene = region->get_zone_scene();
	if (packed_scene.is_null()) {
		LOG(ERROR, get_name(), " region has no packed scene to instantiate");
		return;
	}
	instance = packed_scene->instantiate();
	if (!instance) {
		LOG(ERROR, get_name(), " failed to instantiate packed scene");
		return;
	}
	add_child(instance);
	instance->set_owner(get_owner());
	_data_loaded = true;
}

void Terrain3DZoneLoader::save() {
	LOG(MESG, "Saving ", get_name());
	if (!_region_object_nodes.is_empty()) {
		for (int i = 0; i < _region_object_nodes.size(); i++) {
			Terrain3DZoneLoader *region_node = cast_to<Terrain3DZoneLoader>(_region_object_nodes[i]);
			region_node->save();
		}
		return;
	}
	Ref<Terrain3DRegion> region = _terrain->get_data()->get_region(_region_location);
	if (!region.is_valid()) {
		LOG(ERROR, get_name(), " has invalid region pointer");
		return;
	}
	Array nodes = find_children("*", "Node");
	for (int i = 0; i < nodes.size(); i++) {
		Node *node = cast_to<Node>(nodes[i]);
		node->set_owner(this);
	}
	Ref<PackedScene> packed_scene = memnew(PackedScene);
	packed_scene->pack(this);
	region->set_zone_scene(packed_scene);
	for (int i = 0; i < nodes.size(); i++) {
		Node *node = cast_to<Node>(nodes[i]);
		node->set_owner(get_tree()->get_edited_scene_root());
	}
}

void Terrain3DZoneLoader::clear() {
	LOG(MESG, "Clearing ", get_name());
	if (!_region_object_nodes.is_empty()) {
		LOG(MESG, "clearing children");
		for (int i = 0; i < _region_object_nodes.size(); i++) {
			Terrain3DZoneLoader *region_node = cast_to<Terrain3DZoneLoader>(_region_object_nodes[i]);
			region_node->clear();
		}
		return;
	}
	if (instance) {
		remove_child(instance);
		instance->queue_free();
		instance = nullptr;
	}
	for (int i = 0; i < get_child_count(); i++) {
		Node *child = get_child(i);
		child->queue_free();
	}
	_data_loaded = false;
}

void Terrain3DZoneLoader::set_region(Ref<Terrain3DRegion> p_region) {
	if (p_region.is_valid()) {
		set_name(Util::location_to_filename(p_region->get_location()));
		set_region_location(p_region->get_location());
	}
}

void Terrain3DZoneLoader::set_region_location(const Vector2i &p_loc) {
	_region_location = p_loc;
}

Vector2i Terrain3DZoneLoader::get_region_location() const {
	return _region_location;
}

// Editor button accessors.
// These are "momentary" properties: the setter triggers the action when true.
// The getter always returns false so the checkbox in the inspector appears untoggled.
void Terrain3DZoneLoader::set_load_button(bool p_pressed) {
	if (p_pressed) {
		load();
	}
}

bool Terrain3DZoneLoader::get_load_button() const {
	return false;
}

void Terrain3DZoneLoader::set_save_button(bool p_pressed) {
	if (p_pressed) {
		save();
	}
}

bool Terrain3DZoneLoader::get_save_button() const {
	return false;
}

void Terrain3DZoneLoader::set_clear_button(bool p_pressed) {
	if (p_pressed) {
		clear();
	}
}

bool Terrain3DZoneLoader::get_clear_button() const {
	return false;
}

void Terrain3DZoneLoader::set_terrain(Terrain3D *p_terrain) {
	_terrain = p_terrain;
}

void Terrain3DZoneLoader::_bind_methods() {
	// Bind region location so it is serialized by the editor and available on persisted nodes.
	ClassDB::bind_method(D_METHOD("set_region_location", "loc"), &Terrain3DZoneLoader::set_region_location);
	ClassDB::bind_method(D_METHOD("get_region_location"), &Terrain3DZoneLoader::get_region_location);
	ADD_PROPERTY(PropertyInfo(Variant::VECTOR2I, "Ignore/region_location", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT), "set_region_location", "get_region_location");

	// Bind the editor "button" setters/getters
	ClassDB::bind_method(D_METHOD("set_load_button", "pressed"), &Terrain3DZoneLoader::set_load_button);
	ClassDB::bind_method(D_METHOD("get_load_button"), &Terrain3DZoneLoader::get_load_button);
	ClassDB::bind_method(D_METHOD("set_save_button", "pressed"), &Terrain3DZoneLoader::set_save_button);
	ClassDB::bind_method(D_METHOD("get_save_button"), &Terrain3DZoneLoader::get_save_button);
	ClassDB::bind_method(D_METHOD("set_clear_button", "pressed"), &Terrain3DZoneLoader::set_clear_button);
	ClassDB::bind_method(D_METHOD("get_clear_button"), &Terrain3DZoneLoader::get_clear_button);

	// Add momentary boolean properties that act like buttons in the Inspector.
	// Use PROPERTY_USAGE_EDITOR so they don't get saved with the scene.
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Load", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR), "set_load_button", "get_load_button");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Save", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR), "set_save_button", "get_save_button");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "Clear", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR), "set_clear_button", "get_clear_button");
}