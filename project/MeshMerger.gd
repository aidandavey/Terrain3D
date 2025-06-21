@tool
class_name MeshMerger
extends MeshInstance3D

@export var scrape_n_merge: bool:
	set(value):
		scrape_and_merge_mesh_instances()

var mesh_instances: Array


func scrape_and_merge_mesh_instances() -> void:
	print("Starting scrape and merge")
	var new_mesh := ArrayMesh.new()
	mesh = new_mesh
	position = Vector3.ZERO
	mesh_instances.clear()
	get_mesh_instances(get_parent())
	
	var surface_counter: int = 0
	for mi: MeshInstance3D in mesh_instances:
		for i: int in mi.mesh.get_surface_count():
			print(mi.name, " surface ", i)
			var surface_arr: Array = mi.mesh.surface_get_arrays(i)
			var vertices: PackedVector3Array = surface_arr[Mesh.ArrayType.ARRAY_VERTEX]
			var normals: PackedVector3Array = surface_arr[Mesh.ArrayType.ARRAY_NORMAL]
			
			for v: int in vertices.size():
				vertices[v] = mi.get_global_transform() * vertices[v]
				
			for n: int in normals.size():
				normals[n] = mi.global_transform.basis.inverse().transposed() * normals[n]
			
			surface_arr[Mesh.ArrayType.ARRAY_VERTEX] = vertices
			surface_arr[Mesh.ArrayType.ARRAY_NORMAL] = normals
			
			new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arr)
			new_mesh.surface_set_material(surface_counter, mi.get_active_material(i))
			surface_counter+=1	
	
func get_mesh_instances(parent: Node3D) -> void:
	
	for child: Node3D in parent.get_children():
		if child == self:
			return
		if child is MeshInstance3D:
			mesh_instances.push_back(child)
		get_mesh_instances(child)
