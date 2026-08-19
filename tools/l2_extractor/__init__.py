#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor — Pipeline de Extração e Engenharia Reversa Lineage II / UE2

Módulos:
- L2Decryptor: Desencriptador universal de pacotes UE2 (Blowfish / XOR / Plain).
- UnrealPackageReader: Parser de pacotes (Names, Imports, Exports, Properties e Objetos).
- L2Environment: Auto-descoberta e indexação de pacotes de mapas, texturas e malhas.
- Decodificadores de Textura: DXT1, DXT3, DXT5 (com interpolação alfa 8-bit), P8, G8, RGBA8.
"""

from .decryptor import L2Decryptor, UE2_PACKAGE_TAG, L2_BLOWFISH_KEY
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
    UU_TO_METERS_DEFAULT,
)
from .static_mesh_builder import (
    StaticMeshParser,
    extract_map_static_actors,
    ue2_rotator_to_euler,
    strip_to_triangles,
)
from .material_builder import MaterialTreeResolver
from .environment_builder import (
    extract_map_environment,
    ue2_rotator_to_direction_vector,
)

__all__ = [
    "L2Decryptor",
    "UE2_PACKAGE_TAG",
    "L2_BLOWFISH_KEY",
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
    "UU_TO_METERS_DEFAULT",
    "StaticMeshParser",
    "extract_map_static_actors",
    "ue2_rotator_to_euler",
    "strip_to_triangles",
    "MaterialTreeResolver",
    "extract_map_environment",
    "ue2_rotator_to_direction_vector",
]
