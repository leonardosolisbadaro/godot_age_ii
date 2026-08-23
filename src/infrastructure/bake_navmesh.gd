## @file bake_navmesh.gd
## @path res://src/infrastructure/bake_navmesh.gd
##
## @description
## Script de linha de comando (CLI SceneTree) para compilação (bake) da NavMesh definitiva do Servidor.
## Consome diretamente a malha do terreno (GLB visual) e os colisores pré-compilados (chunk_static_collision.tres)
## como Fonte Única da Verdade para gerar a malha de navegação 3D otimizada em assets/maps/<chunk>/server/navmesh.res.
##
## Uso:
##   godot --headless -s res://src/infrastructure/bake_navmesh.gd
##   godot --headless -s res://src/infrastructure/bake_navmesh.gd -- --chunk 17_25
##
## @created 2026-08-23
## @updated 2026-08-23
##
## @author Leonardo S. Badaró
extends SceneTree

const ChunkResourceAdapterClass = preload("res://src/adapters/chunk_resource_adapter.gd")
const TerrainChunkAdapterClass = preload("res://src/adapters/terrain_chunk_adapter.gd")
const RuntimeAssetCacheClass = preload("res://src/infrastructure/runtime_asset_cache.gd")

const BASE_MAPS_PATH: String = "res://assets/maps"

# Parâmetros de Navegação Calibrados para Humanóides MMORPG (Lineage II)
const NAV_AGENT_RADIUS: float = 0.5
const NAV_AGENT_HEIGHT: float = 1.8
const NAV_AGENT_MAX_CLIMB: float = 0.5
const NAV_AGENT_MAX_SLOPE: float = 45.0
const NAV_CELL_SIZE: float = 1.5
const NAV_CELL_HEIGHT: float = 0.5


func _init() -> void:
	process_frame.connect(_on_process_frame, CONNECT_ONE_SHOT)


func _on_process_frame() -> void:
	ProjectSettings.set_setting("navigation/baking/use_crash_prevention_checks", false)
	print("=======================================================")
	print("[NAVMESH BAKE] Iniciando Pipeline de Compilacao NavMesh...")
	print("=======================================================")

	var user_args = OS.get_cmdline_user_args()
	var main_args = OS.get_cmdline_args()
	var combined_args = user_args + main_args

	var target_chunk = ""
	for i in range(combined_args.size()):
		if (combined_args[i] == "--chunk" or combined_args[i] == "-c") and i + 1 < combined_args.size():
			target_chunk = combined_args[i + 1]
			break

	if not target_chunk.is_empty():
		bake_single_chunk(target_chunk)
	else:
		bake_all_chunks()

	quit(0)


func bake_single_chunk(chunk_name: String) -> void:
	var adapter = ChunkResourceAdapterClass.new(BASE_MAPS_PATH)
	print("[NAVMESH BAKE] Compilando NavMesh apenas para o chunk '%s'..." % chunk_name)
	bake_chunk_navmesh(chunk_name, adapter)
	print("=======================================================")
	print("[NAVMESH BAKE] Compilacao do chunk '%s' concluida!" % chunk_name)
	print("=======================================================")


func bake_all_chunks() -> void:
	var adapter = ChunkResourceAdapterClass.new(BASE_MAPS_PATH)
	var chunks = adapter.get_available_chunks()

	print("[NAVMESH BAKE] Encontrados %d chunks para processamento." % chunks.size())

	for chunk_name in chunks:
		bake_chunk_navmesh(chunk_name, adapter)

	print("=======================================================")
	print("[NAVMESH BAKE] Compilacao de todos os chunks concluida!")
	print("=======================================================")


func bake_chunk_navmesh(chunk_name: String, adapter: RefCounted) -> void:
	var meta = adapter.load_chunk_meta_dict(chunk_name, true)
	var origin_arr = meta.get("world_origin_meters", [0.0, 0.0, 0.0])
	var chunk_origin = Vector3(float(origin_arr[0]), 0.0, float(origin_arr[2]))

	var root = Node3D.new()
	root.name = "NavMeshSourceRoot"
	# Desloca a raiz para que as geometrias mundiais fiquem no espaço local [0, 2621.44m] do chunk
	root.position = -chunk_origin
	get_root().add_child(root)

	# 1. Carrega a malha do terreno do chunk via TerrainChunkAdapter
	var terrain_adapter = TerrainChunkAdapterClass.new()
	var terrain_node = terrain_adapter.load_visual_mesh_node(chunk_name, BASE_MAPS_PATH)
	if terrain_node:
		terrain_node.name = "TerrainVisualMesh"
		root.add_child(terrain_node)
		print("[NAVMESH BAKE] Chunk '%s': Terreno carregado e anexado com sucesso." % chunk_name)
	else:
		print("[NAVMESH BAKE] [AVISO] Chunk '%s': Malha de terreno nao encontrada." % chunk_name)

	# 2. Carrega os colisores pré-compilados de chunk_static_collision.tres (Single Source of Truth)
	var baked_file = "%s/%s/client/chunk_static_collision.tres" % [BASE_MAPS_PATH, chunk_name]
	var glob_path = ProjectSettings.globalize_path(baked_file)
	var resolved = baked_file if FileAccess.file_exists(baked_file) else (glob_path if FileAccess.file_exists(glob_path) else "")
	var total_colliders_attached = 0

	if not resolved.is_empty():
		var config = ConfigFile.new()
		var err = config.load(resolved)
		if err == OK:
			for actor_name in config.get_sections():
				var mesh_path = config.get_value(actor_name, "mesh_path", "")
				var c_type = config.get_value(actor_name, "collision_type", "convex")
				var xform: Transform3D = config.get_value(actor_name, "transform", Transform3D.IDENTITY)

				var mesh = RuntimeAssetCacheClass.get_or_load_mesh(mesh_path)
				if not mesh:
					continue

				var shape: Shape3D = null
				if c_type == "tree_trunk" or c_type == "tree_trunk_surface":
					var surf_idx = int(config.get_value(actor_name, "surface_index", 0))
					shape = RuntimeAssetCacheClass.get_or_create_trunk_convex_shape(mesh_path, mesh, surf_idx)
				elif c_type == "concave":
					shape = RuntimeAssetCacheClass.get_or_create_trimesh_shape(mesh_path, mesh)
				else:
					shape = RuntimeAssetCacheClass.get_or_create_convex_shape(mesh_path, mesh)

				if shape:
					var body = StaticBody3D.new()
					body.transform = xform
					var col = CollisionShape3D.new()
					col.shape = shape
					body.add_child(col)
					root.add_child(body)
					total_colliders_attached += 1

	print("[NAVMESH BAKE] Chunk '%s': %d colisores estaticos carregados de '%s' e anexados para oclusao." % [chunk_name, total_colliders_attached, baked_file])

	# 3. Configura o NavigationMesh Recast
	var nav_mesh = NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_BOTH
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	nav_mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_WATERSHED
	nav_mesh.agent_radius = NAV_AGENT_RADIUS
	nav_mesh.agent_height = NAV_AGENT_HEIGHT
	nav_mesh.agent_max_climb = NAV_AGENT_MAX_CLIMB
	nav_mesh.agent_max_slope = NAV_AGENT_MAX_SLOPE
	nav_mesh.cell_size = NAV_CELL_SIZE
	nav_mesh.cell_height = NAV_CELL_HEIGHT

	# 4. Executa o parse e o bake no NavigationServer3D
	var source_data = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source_data, root)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_data)

	var poly_count = nav_mesh.get_polygon_count()
	var vert_count = nav_mesh.get_vertices().size()

	# 5. Salva o resultado binário em assets/maps/<chunk>/server/navmesh.res
	var server_dir = "%s/%s/server" % [BASE_MAPS_PATH, chunk_name]
	var target_file = "%s/navmesh.res" % server_dir
	var write_path = ProjectSettings.globalize_path(target_file)

	var dir_path = write_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	var err = ResourceSaver.save(nav_mesh, target_file)
	if err == OK:
		print("[NAVMESH BAKE] Chunk '%s': Sucesso! %d poligonos / %d vertices salvos em '%s'." % [chunk_name, poly_count, vert_count, target_file])
	else:
		print("[NAVMESH BAKE] [ERRO] Falha ao salvar '%s' (codigo: %d)." % [target_file, err])

	get_root().remove_child(root)
	root.free()
