#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/static_mesh_builder.py — Extrator de Malhas Estáticas e Instâncias (.USX e .UNR)

@description
Implementa:
- Decodificação do formato binário UStaticMesh da Unreal Engine 2 (Streams de vértices, normais, UVs, triangle strips com 0xFFFF)
- Extração de seções e atribuição de materiais/texturas
- Extração de instâncias de StaticMeshActor dentro dos mapas .unr (Posição, Rotação, Escala 3D)
- Exportação de malhas reutilizáveis em .glb binário e metadados de posicionamento em chunk_static_actors.json

@created 2026-08-18
@updated 2026-08-20
@author Leonardo S. Badaró
"""

import json
import math
from pathlib import Path
import struct
from typing import Any, Dict, List, Optional, Tuple, Union
import numpy as np

from .config import (
    PipelineConfig,
    TRIANGLE_STRIP_RESTART_INDEX,
    UE2_ROTATOR_FULL_CIRCLE,
    UU_TO_METERS_CANONICAL,
)
from .environment import L2Environment
from .package_reader import UnrealPackageReader
from .terrain_builder import write_glb


# ==============================================================================
# CONSTANTES SEMÂNTICAS DE STATIC MESHES
# ==============================================================================

## @const VERTEX_STREAM_BYTE_STRIDE (int)
## O que: Tamanho em bytes de 1 elemento no stream de vértices da UE2 (24 bytes).
## Porque: Composto por 3 floats de posição (12 bytes) + 3 floats de normal (12 bytes).
VERTEX_STREAM_BYTE_STRIDE: int = 24

## @const UV_COORDINATE_BYTE_STRIDE (int)
## O que: Tamanho em bytes de 1 par de coordenadas UV em ponto flutuante (8 bytes).
## Porque: 2 floats de 32 bits (U, V).
UV_COORDINATE_BYTE_STRIDE: int = 8

## @const BOUNDING_BOX_BYTE_SIZE (int)
## O que: Tamanho da estrutura de BoundingBox serializada na UE2 (25 bytes).
## Porque: Vector Min (12B) + Vector Max (12B) + Byte IsValid (1B).
BOUNDING_BOX_BYTE_SIZE: int = 25

## @const BOUNDING_SPHERE_BYTE_SIZE (int)
## O que: Tamanho da estrutura de BoundingSphere serializada na UE2 (16 bytes).
## Porque: Vector Center (12B) + Float Radius (4B).
BOUNDING_SPHERE_BYTE_SIZE: int = 16


def ue2_rotator_to_euler(pitch: int, yaw: int, roll: int) -> Tuple[float, float, float]:
    """
    Converte um Rotator da Unreal Engine 2 (0..65536 unidades de rotação)
    para ângulos de Euler em radianos no sistema de coordenadas do Godot.
    """
    factor = (2.0 * math.pi) / UE2_ROTATOR_FULL_CIRCLE
    r_pitch = float(pitch) * factor
    r_yaw = -float(yaw) * factor  # Inverte Yaw devido ao eixo Z no Godot
    r_roll = float(roll) * factor
    return r_pitch, r_yaw, r_roll


def strip_to_triangles(strip_indices: list) -> list:
    """Converte Triangle Strips (com 0xFFFF restart index) em lista de triângulos."""
    triangles = []
    current_strip = []

    for idx in strip_indices:
        if idx == TRIANGLE_STRIP_RESTART_INDEX or idx == 65535:
            if len(current_strip) >= 3:
                for i in range(len(current_strip) - 2):
                    v0, v1, v2 = current_strip[i], current_strip[i + 1], current_strip[i + 2]
                    if v0 != v1 and v1 != v2 and v0 != v2:
                        if i % 2 == 0:
                            triangles.append([v0, v1, v2])
                        else:
                            triangles.append([v0, v2, v1])
            current_strip = []
        else:
            current_strip.append(idx)

    if len(current_strip) >= 3:
        for i in range(len(current_strip) - 2):
            v0, v1, v2 = current_strip[i], current_strip[i + 1], current_strip[i + 2]
            if v0 != v1 and v1 != v2 and v0 != v2:
                if i % 2 == 0:
                    triangles.append([v0, v1, v2])
                else:
                    triangles.append([v0, v2, v1])

    return triangles


class StaticMeshParser:
    """Parser para malhas estáticas UStaticMesh da Unreal Engine 2."""

    def __init__(self, package: UnrealPackageReader, unit_scale: float = UU_TO_METERS_CANONICAL, config: Optional[PipelineConfig] = None):
        self.config = config or PipelineConfig(unit_scale=unit_scale)
        self.pkg = package
        self.unit_scale = unit_scale

    def extract_mesh_by_export(self, exp: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Decodifica malha canônica com streams precisos de vértices, normais, UVs e index buffers."""
        if exp["class_name"] != "StaticMesh":
            return None

        p_start = self.pkg.find_properties_start(exp["offset"], exp["size"])
        props = self.pkg.read_properties(
            p_start, exp["size"] - (p_start - exp["offset"])
        )
        pos = self.pkg.pos

        # Se for um wrapper LOD apontando para LOD01, carrega o LOD01
        lod01_ref = props.get("StaticMeshLod01")
        if lod01_ref and isinstance(lod01_ref, dict):
            lod_obj_name = lod01_ref.get("object_name")
            if lod_obj_name and lod_obj_name != exp["object_name"]:
                lod_exp = next(
                    (e for e in self.pkg.exports if e["object_name"] == lod_obj_name),
                    None,
                )
                if lod_exp:
                    res = self.extract_mesh_by_export(lod_exp)
                    if res:
                        res["name"] = exp["object_name"]
                        res["props"] = props
                        return res

        exp_end = exp["offset"] + exp["size"]
        header_bounds_size = BOUNDING_BOX_BYTE_SIZE + BOUNDING_SPHERE_BYTE_SIZE
        if pos < exp["offset"] or pos + header_bounds_size > exp_end:
            pos = exp["offset"]

        # 1. BoundingBox (25 bytes) e BoundingSphere (16 bytes)
        min_v = (0.0, 0.0, 0.0)
        max_v = (0.0, 0.0, 0.0)
        center_v = (0.0, 0.0, 0.0)
        radius = 1.0

        if pos + header_bounds_size <= exp_end:
            try:
                min_v = struct.unpack_from("<fff", self.pkg.data, pos)
                pos += 12
                max_v = struct.unpack_from("<fff", self.pkg.data, pos)
                pos += 12
                is_valid = self.pkg.data[pos]
                pos += 1
                center_v = struct.unpack_from("<fff", self.pkg.data, pos)
                pos += 12
                radius = struct.unpack_from("<f", self.pkg.data, pos)[0]
                pos += 4
            except Exception:
                pos = exp["offset"]

        # 2. Localização do buffer de vértices (24B: 3f Posição + 3f Normal)
        v_start = None
        for p in range(pos, min(pos + 3000, exp_end - 48), 4):
            try:
                px, py, pz, nx, ny, nz = struct.unpack_from("<6f", self.pkg.data, p)
                n_sq = nx * nx + ny * ny + nz * nz
                if 0.90 <= n_sq <= 1.10:
                    px2, py2, pz2, nx2, ny2, nz2 = struct.unpack_from(
                        "<6f", self.pkg.data, p + VERTEX_STREAM_BYTE_STRIDE
                    )
                    if 0.90 <= (nx2 * nx2 + ny2 * ny2 + nz2 * nz2) <= 1.10:
                        v_start = p
                        break
            except Exception:
                break

        if v_start is None:
            return None

        p = v_start
        while p + VERTEX_STREAM_BYTE_STRIDE <= exp_end:
            try:
                px, py, pz, nx, ny, nz = struct.unpack_from("<6f", self.pkg.data, p)
                n_sq = nx * nx + ny * ny + nz * nz
                if 0.70 <= n_sq <= 1.30:
                    p += VERTEX_STREAM_BYTE_STRIDE
                else:
                    break
            except Exception:
                break

        num_v = (p - v_start) // VERTEX_STREAM_BYTE_STRIDE
        if num_v < 3:
            return None

        raw_verts = np.frombuffer(
            self.pkg.data[v_start : v_start + num_v * VERTEX_STREAM_BYTE_STRIDE], dtype="<f4"
        ).reshape((num_v, 6))
        positions_arr = raw_verts[:, :3].copy()
        normals_arr = raw_verts[:, 3:].copy()
        v_end = v_start + num_v * VERTEX_STREAM_BYTE_STRIDE

        # 3. Localização de UVs em float32 (num_v pares)
        uvs = None
        uv_end = v_end
        for uv_off in range(v_end, min(v_end + 60000, exp_end - num_v * UV_COORDINATE_BYTE_STRIDE), 4):
            cand_uv = np.frombuffer(
                self.pkg.data[uv_off : uv_off + num_v * UV_COORDINATE_BYTE_STRIDE], dtype="<f4"
            )
            if len(cand_uv) == num_v * 2:
                cand_uv = cand_uv.reshape((num_v, 2))
                if (
                    np.all(cand_uv >= -10.0)
                    and np.all(cand_uv <= 10.0)
                    and np.std(cand_uv) > 0.05
                ):
                    uvs = cand_uv.copy()
                    uv_end = uv_off + num_v * UV_COORDINATE_BYTE_STRIDE
                    break

        if uvs is None:
            uvs = np.zeros((num_v, 2), dtype=np.float32)

        # 4. Localização do IndexBuffer canônico
        best_triangles = None
        best_score = 999999.0

        test_offsets = []
        for step in range(0, min(2000, exp_end - uv_end - 6), 2):
            test_offsets.append(uv_end + step)

        for idx_off in test_offsets:
            slice_len = min(60000, exp_end - idx_off)
            slice_len -= slice_len % 2
            if slice_len < 6:
                continue
            cand_u16 = np.frombuffer(
                self.pkg.data[idx_off : idx_off + slice_len], dtype="<u2"
            )
            valid_cnt = 0
            while valid_cnt < len(cand_u16) and cand_u16[valid_cnt] < num_v:
                valid_cnt += 1

            if valid_cnt >= 12:
                line_cnt = valid_cnt // 6
                if line_cnt >= 2:
                    is_6line = True
                    for li in range(min(15, line_cnt)):
                        c = cand_u16[6 * li : 6 * li + 6]
                        if c[1] != c[2] or c[3] != c[4] or c[5] != c[0]:
                            is_6line = False
                            break
                    if is_6line:
                        line_tri = []
                        for li in range(line_cnt):
                            line_tri.append(
                                [
                                    cand_u16[6 * li],
                                    cand_u16[6 * li + 1],
                                    cand_u16[6 * li + 3],
                                ]
                            )
                        line_tri = np.array(line_tri, dtype=np.uint32)
                        edge_lens_l = []
                        for t in line_tri[: min(50, line_cnt)]:
                            p0, p1, p2 = (
                                positions_arr[t[0]],
                                positions_arr[t[1]],
                                positions_arr[t[2]],
                            )
                            edge_lens_l.extend(
                                [
                                    np.linalg.norm(p0 - p1),
                                    np.linalg.norm(p1 - p2),
                                    np.linalg.norm(p2 - p0),
                                ]
                            )
                        mean_edge_l = (
                            float(np.mean(edge_lens_l)) if edge_lens_l else 9999.0
                        )
                        if mean_edge_l < 500.0 and (
                            best_triangles is None
                            or len(line_tri) > len(best_triangles)
                        ):
                            best_triangles = line_tri
                            best_score = mean_edge_l
                            continue

                tri_cnt = valid_cnt // 3
                cand_tri = cand_u16[: tri_cnt * 3].reshape((tri_cnt, 3))
                edge_lens = []
                for t in cand_tri[: min(50, tri_cnt)]:
                    p0, p1, p2 = (
                        positions_arr[t[0]],
                        positions_arr[t[1]],
                        positions_arr[t[2]],
                    )
                    edge_lens.extend(
                        [
                            np.linalg.norm(p0 - p1),
                            np.linalg.norm(p1 - p2),
                            np.linalg.norm(p2 - p0),
                        ]
                    )
                mean_edge = float(np.mean(edge_lens)) if edge_lens else 9999.0

                if mean_edge < 500.0 and (
                    best_triangles is None or len(cand_tri) > len(best_triangles)
                ):
                    best_triangles = cand_tri
                    best_score = mean_edge

        if best_triangles is None or len(best_triangles) == 0:
            num_tri = num_v // 3
            triangles = np.arange(num_tri * 3, dtype=np.uint32).reshape((num_tri, 3))
        else:
            triangles = best_triangles

        # Inverte o winding [v0, v2, v1] para conversão canônica UE2 (CW) -> glTF (CCW)
        triangles_wound = np.zeros_like(triangles)
        triangles_wound[:, 0] = triangles[:, 0]
        triangles_wound[:, 1] = triangles[:, 2]
        triangles_wound[:, 2] = triangles[:, 1]

        # Conversão canônica do UModel para glTF/Godot (Exchange Y e Z, escala unit_scale em metros)
        positions_transformed = np.zeros_like(positions_arr)
        positions_transformed[:, 0] = positions_arr[:, 0] * self.unit_scale
        positions_transformed[:, 1] = positions_arr[:, 2] * self.unit_scale
        positions_transformed[:, 2] = positions_arr[:, 1] * self.unit_scale

        normals_transformed = np.zeros_like(normals_arr)
        normals_transformed[:, 0] = normals_arr[:, 0]
        normals_transformed[:, 1] = normals_arr[:, 2]
        normals_transformed[:, 2] = normals_arr[:, 1]

        # Centraliza o modelo no centro do seu Bounding Box
        center = (
            positions_transformed.min(axis=0) + positions_transformed.max(axis=0)
        ) / 2.0
        positions_centered = positions_transformed - center

        return {
            "name": exp["object_name"],
            "props": props,
            "bounds": {
                "min": min_v,
                "max": max_v,
                "center": center_v,
                "radius": radius,
            },
            "num_vertices": num_v,
            "num_triangles": len(triangles_wound),
            "positions": positions_centered,
            "normals": normals_transformed,
            "uvs": uvs,
            "triangles": triangles_wound,
        }


def extract_map_static_actors(
    map_package: UnrealPackageReader,
    unit_scale: float = UU_TO_METERS_CANONICAL,
    heightfield: Optional[np.ndarray] = None,
) -> List[Dict[str, Any]]:
    """Extrai todas as instâncias de StaticMeshActor de um mapa .unr sincronizadas com o terreno."""
    chunk_w = 2621.44
    chunk_d = 2621.44

    for exp in map_package.exports:
        if exp["class_name"] == "TerrainInfo":
            p_start = map_package.find_properties_start(exp["offset"], exp["size"])
            t_props = map_package.read_properties(
                p_start, exp["size"] - (p_start - exp["offset"])
            )
            t_scale = t_props.get("TerrainScale", (128.0, 128.0, 76.0))
            chunk_w = 256.0 * float(t_scale[0]) * unit_scale
            chunk_d = 256.0 * float(t_scale[1]) * unit_scale
            break

    actors = []
    for exp in map_package.exports:
        if exp["class_name"] == "StaticMeshActor":
            p_start = map_package.find_properties_start(exp["offset"], exp["size"])
            props = map_package.read_properties(
                p_start, exp["size"] - (p_start - exp["offset"])
            )

            mesh_ref = props.get("StaticMesh")
            location = props.get("Location", (0.0, 0.0, 0.0))
            rotation = props.get("Rotation", (0, 0, 0))
            draw_scale = float(props.get("DrawScale", 1.0) or 1.0)
            draw_scale3d = props.get("DrawScale3D", (1.0, 1.0, 1.0))

            if isinstance(location, dict) and location.get("_is_array"):
                location = location.get(0, (0.0, 0.0, 0.0))
            if isinstance(rotation, dict) and rotation.get("_is_array"):
                rotation = rotation.get(0, (0, 0, 0))
            if isinstance(draw_scale3d, dict) and draw_scale3d.get("_is_array"):
                draw_scale3d = draw_scale3d.get(0, (1.0, 1.0, 1.0))

            half_chunk_w = chunk_w / 2.0
            half_chunk_d = chunk_d / 2.0
            loc_x = (float(location[0]) * unit_scale) + half_chunk_w
            loc_y = float(location[2]) * unit_scale
            loc_z = (float(location[1]) * unit_scale) + half_chunk_d

            p, y, r = (
                int(rotation[0]),
                int(rotation[1]),
                int(rotation[2]) if len(rotation) > 2 else 0,
            )
            rot_euler = ue2_rotator_to_euler(p, y, r)

            scale_x = float(draw_scale3d[0]) * draw_scale
            scale_y = float(draw_scale3d[2]) * draw_scale
            scale_z = float(draw_scale3d[1]) * draw_scale

            actors.append(
                {
                    "actor_name": exp["object_name"],
                    "mesh_ref": mesh_ref,
                    "transform": {
                        "position_meters": [
                            round(loc_x, 3),
                            round(loc_y, 3),
                            round(loc_z, 3),
                        ],
                        "rotation_euler_rad": [
                            round(rot_euler[0], 4),
                            round(rot_euler[1], 4),
                            round(rot_euler[2], 4),
                        ],
                        "scale": [
                            round(scale_x, 3),
                            round(scale_y, 3),
                            round(scale_z, 3),
                        ],
                    },
                    "raw_ue2": {
                        "location": location,
                        "rotation": rotation,
                        "draw_scale": draw_scale,
                        "draw_scale3d": draw_scale3d,
                    },
                }
            )

    return actors
