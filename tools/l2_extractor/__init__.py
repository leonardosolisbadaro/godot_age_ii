#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor — Pipeline de Extração e Engenharia Reversa Lineage II / UE2

@description
Módulos:
- config: Centralização de constantes semânticas e PipelineConfig para injeção de dependência.
- validator: Pre-flight Health Check e validação de ambiente sem fallbacks externos.
- decryptor: Desencriptador universal de pacotes UE2 (Blowfish / XOR / Plain).
- package_reader: Parser de pacotes UE2 (Names, Imports, Exports, Properties e Objetos).
- environment: Descoberta e indexação de pacotes de mapas, texturas e malhas na raiz.
- texture_decoder: Decodificadores vetorizados DXT1, DXT3, DXT5, P8, G8, RGBA8.
- terrain_builder: Compilador de terreno e soldagem contínua 2-Pass Seamless.
- static_mesh_builder: Extrator de StaticMeshes, index buffers e atores em mapas .unr.
- material_builder: Resolvedor de árvores de materiais e shaders para StandardMaterial3D.
- environment_builder: Extrator de iluminação solar, névoa e física de águas.
- umodel_wrapper: Wrapper para UModel CLI restrito à pasta umodel_win32 da raiz.

@created 2026-08-18
@updated 2026-08-20
@author Leonardo S. Badaró
"""

from .config import (
    PipelineConfig,
    UU_TO_METERS_CANONICAL,
    UMODEL_TO_CANONICAL_SCALE,
    UE2_ROTATOR_FULL_CIRCLE,
    UE2_ROTATOR_QUARTER_CIRCLE,
    TERRAIN_GRID_RESOLUTION,
    TERRAIN_HEIGHT_OFFSET_U16,
    TERRAIN_HEIGHT_DIVISOR,
    TERRAIN_SECTOR_SIZE_DEFAULT,
    SPLATMAP_RESOLUTION,
    SPLATMAP_MAX_LAYERS_PER_MAP,
    TERRAIN_MAX_TOTAL_LAYERS,
    UE2_PACKAGE_TAG,
    UE2_MIN_VALID_VERSION,
    UE2_MAX_VALID_VERSION,
    L2_BLOWFISH_KEY,
    BLOWFISH_BLOCK_SIZE,
    TRIANGLE_STRIP_RESTART_INDEX,
    DXT_BLOCK_PIXELS_DIM,
    DXT1_BLOCK_BYTE_SIZE,
    DXT3_5_BLOCK_BYTE_SIZE,
    PALETTE_ENTRIES_COUNT,
)
from .validator import (
    ValidationResult,
    validate_pipeline_environment,
)
from .decryptor import L2Decryptor
from .package_reader import UnrealPackageReader
from .environment import L2Environment
from .texture_decoder import (
    decode_dxt1,
    decode_dxt3,
    decode_dxt5,
    decode_p8,
    decode_g8,
    decode_rgba8,
)
from .terrain_builder import (
    TerrainChunkCompiler,
    build_terrain_mesh,
    compile_cluster,
    write_glb,
)
from .static_mesh_builder import (
    StaticMeshParser,
    extract_map_static_actors,
    ue2_rotator_to_euler,
    strip_to_triangles,
)
from .material_builder import MaterialTreeResolver, to_godot_res_path
from .environment_builder import (
    extract_map_environment,
    ue2_rotator_to_direction_vector,
)
from .umodel_wrapper import (
    find_umodel_executable,
    export_package_textures,
    export_package_meshes,
)

# Aliases de compatibilidade
UU_TO_METERS_DEFAULT = UU_TO_METERS_CANONICAL

__all__ = [
    "PipelineConfig",
    "ValidationResult",
    "validate_pipeline_environment",
    "UU_TO_METERS_CANONICAL",
    "UU_TO_METERS_DEFAULT",
    "UMODEL_TO_CANONICAL_SCALE",
    "UE2_ROTATOR_FULL_CIRCLE",
    "UE2_ROTATOR_QUARTER_CIRCLE",
    "TERRAIN_GRID_RESOLUTION",
    "TERRAIN_HEIGHT_OFFSET_U16",
    "TERRAIN_HEIGHT_DIVISOR",
    "TERRAIN_SECTOR_SIZE_DEFAULT",
    "SPLATMAP_RESOLUTION",
    "SPLATMAP_MAX_LAYERS_PER_MAP",
    "TERRAIN_MAX_TOTAL_LAYERS",
    "UE2_PACKAGE_TAG",
    "UE2_MIN_VALID_VERSION",
    "UE2_MAX_VALID_VERSION",
    "L2_BLOWFISH_KEY",
    "BLOWFISH_BLOCK_SIZE",
    "TRIANGLE_STRIP_RESTART_INDEX",
    "DXT_BLOCK_PIXELS_DIM",
    "DXT1_BLOCK_BYTE_SIZE",
    "DXT3_5_BLOCK_BYTE_SIZE",
    "PALETTE_ENTRIES_COUNT",
    "L2Decryptor",
    "UnrealPackageReader",
    "L2Environment",
    "decode_dxt1",
    "decode_dxt3",
    "decode_dxt5",
    "decode_p8",
    "decode_g8",
    "decode_rgba8",
    "TerrainChunkCompiler",
    "build_terrain_mesh",
    "compile_cluster",
    "write_glb",
    "StaticMeshParser",
    "extract_map_static_actors",
    "ue2_rotator_to_euler",
    "strip_to_triangles",
    "MaterialTreeResolver",
    "to_godot_res_path",
    "extract_map_environment",
    "ue2_rotator_to_direction_vector",
    "find_umodel_executable",
    "export_package_textures",
    "export_package_meshes",
]
