@tool
class_name CollisionShapeMerger
extends CollisionShape3D


@export var scrape_n_merge: bool:
	set(value):
		scrape_and_merge_collion_shapes()
		
var collision_shapes: Array




func scrape_and_merge_collion_shapes() -> void:
	var new_shape := ConcavePolygonShape3D.new()
	position = Vector3.ZERO
	collision_shapes.clear()
	get_collision_shapes(get_parent())
	var v3_arr: PackedVector3Array
	for cs: CollisionShape3D in collision_shapes:
		var s = cs.shape
		v3_arr.append_array(s.get_faces())
		
	new_shape.set_faces(v3_arr)

	shape = new_shape



func get_collision_shapes(parent: Node3D) -> void:
	
	for child: Node3D in parent.get_children():
		if child == self:
			return
		if child is CollisionShape3D:
			collision_shapes.push_back(child)
		get_collision_shapes(child)
