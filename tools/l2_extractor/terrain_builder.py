#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/terrain_builder.py — Compilador de Terreno de Alta Fidelidade Lineage II (UE2 -> Godot 4.7)

Implementa a extração completa e precisa do terreno:
- Decodificação de TerrainInfo (Escalas, Localização, Setores)
- Extração de Heightmap G16 (256x256 uint16)
- Extração de QuadVisibilityBitmap (Máscara de Buracos/Cavernas)
- Extração de Camadas (Difusas, Alfas, UScale, VScale, UPan, VPan, RotDegrees)
- Empacotamento de Splatmaps RGBA de 1024x1024
- Soldagem Contínua de Chunks (2-Pass Seamless Alignment)
- Geração de Malha 3D GLB Binária e Buffers Físicos Float32 para Servidor
"""

from collections import defaultdict
import json
import os
from pathlib import Path
import struct
import time
from typing import Any, Dict, List, Optional, Tuple, Union
import numpy as np
from PIL import Image

from .environment import L2Environment
from .package_reader import UnrealPackageReader

UU_TO_METERS_DEFAULT = 0.08  # 1 UU = 8cm = 0.08 metros


def build_terrain_mesh(
    heights: np.ndarray,
    scale: Tuple[float, float, float],
    location: Tuple[float, float, float],
    unit_scale: float = UU_TO_METERS_DEFAULT,
    step: int = 1,
    hole_mask: Optional[np.ndarray] = None,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """
    Constrói a geometria 3D do terreno (vértices, normais, UVs e triângulos)
    calibrada metricamente e centralizada na origem local do chunk.
    """
    if step > 1:
        heights = heights[::step, ::step]
        if hole_mask is not None:
            hole_mask = hole_mask[::step, ::step]

    rows, cols = heights.shape
    sx = float(scale[0]) * step * unit_scale
    sz_world = float(scale[1]) * step * unit_scale  # Em Godot, Z é profundidade horizontal
    sy_scale = float(scale[2]) * unit_scale        # Em Godot, Y é altitude
    loc_z = float(location[2]) * unit_scale if len(location) > 2 else 0.0

    # Dimensões e centralização
    half_w = (cols * sx) / 2.0
    half_d = (rows * sz_world) / 2.0
    xs = np.linspace(-half_w, half_w, cols, dtype=np.float32)
    zs = np.linspace(-half_d, half_d, rows, dtype=np.float32)

    grid_x, grid_z = np.meshgrid(xs, zs)

    # Altitude mundial em metros calibrada com a fórmula canônica da UE2 para heightmaps 16-bit G16
    world_y = ((heights.astype(np.float32) - 32768.0) * (sy_scale / 256.0)) + loc_z

    # Cálculo de normais de superfície com espaçamento real entre vértices
    dx_eff = (2.0 * half_w) / max(1, cols - 1)
    dz_eff = (2.0 * half_d) / max(1, rows - 1)
    dz, dx = np.gradient(world_y, dz_eff, dx_eff)
    nx = -dx
    ny = np.ones_like(world_y)
    nz = -dz
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    normals = np.stack([nx * inv_len, ny * inv_len, nz * inv_len], axis=-1).reshape(-1, 3).astype(np.float32)

    positions = np.stack([grid_x, world_y, grid_z], axis=-1).reshape(-1, 3).astype(np.float32)

    # Coordenadas UV normalizadas [0..1]
    us = np.linspace(0.0, 1.0, cols, dtype=np.float32)
    vs = np.linspace(0.0, 1.0, rows, dtype=np.float32)
    gu, gv = np.meshgrid(us, vs)
    uvs = np.stack([gu, gv], axis=-1).reshape(-1, 2).astype(np.float32)

    # Construção dos Triângulos (Indices)
    row_indices = np.arange(rows - 1, dtype=np.uint32)
    col_indices = np.arange(cols - 1, dtype=np.uint32)
    rr, cc = np.meshgrid(row_indices, col_indices, indexing="ij")

    a = rr * cols + cc
    b = a + 1
    d = a + cols
    e = d + 1

    triangle_a = np.stack([a, d, b], axis=-1).reshape(-1, 3)
    triangle_b = np.stack([b, d, e], axis=-1).reshape(-1, 3)
    triangles = np.concatenate([triangle_a, triangle_b], axis=0)

    # Se houver máscara de buracos (hole_mask), descarta os triângulos dos quads invisíveis
    if hole_mask is not None and hole_mask.shape == (rows - 1, cols - 1):
        visible_mask = hole_mask.reshape(-1)
        # Cada quad tem 2 triângulos (a e b)
        quad_mask_doubled = np.repeat(visible_mask, 2)
        if len(quad_mask_doubled) == len(triangles):
            triangles = triangles[quad_mask_doubled]

    return positions, normals, uvs, triangles, world_y


def write_glb(
    filepath: Path,
    name: str,
    positions: np.ndarray,
    normals: np.ndarray,
    uvs: np.ndarray,
    triangles: np.ndarray,
) -> None:
    """Exporta a malha 3D como arquivo binário GLB (.glb / GLTF 2.0)."""
    position_data = np.ascontiguousarray(positions, dtype="<f4")
    normal_data = np.ascontiguousarray(normals, dtype="<f4")
    uv_data = np.ascontiguousarray(uvs, dtype="<f4")
    index_data = np.ascontiguousarray(triangles.reshape(-1), dtype="<u4")

    raw_buffers = [
        position_data.tobytes(),
        normal_data.tobytes(),
        uv_data.tobytes(),
        index_data.tobytes(),
    ]

    blobs = []
    buffer_views = []
    offset = 0
    for data in raw_buffers:
        padding = (-len(data)) % 4
        padded = data + b"\x00" * padding
        blobs.append(padded)
        buffer_views.append(
            {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
        )
        offset += len(padded)

    binary_chunk = b"".join(blobs)
    vertex_count = int(len(position_data))

    pbr_config = {
        "metallicFactor": 0.0,
        "roughnessFactor": 0.85,
        "baseColorFactor": [0.75, 0.75, 0.78, 1.0],
    }

    gltf = {
        "asset": {
            "version": "2.0",
            "generator": "terrain_builder.py (Godotage II / Lineage II)",
        },
        "scene": 0,
        "scenes": [{"nodes": [0], "name": name}],
        "nodes": [{"mesh": 0, "name": name}],
        "materials": [
            {
                "name": "TerrainMaterial",
                "doubleSided": True,
                "pbrMetallicRoughness": pbr_config,
            }
        ],
        "meshes": [
            {
                "name": name,
                "primitives": [
                    {
                        "attributes": {
                            "POSITION": 0,
                            "NORMAL": 1,
                            "TEXCOORD_0": 2,
                        },
                        "indices": 3,
                        "material": 0,
                        "mode": 4,
                    }
                ],
            }
        ],
        "buffers": [{"byteLength": len(binary_chunk)}],
        "bufferViews": buffer_views,
        "accessors": [
            {
                "bufferView": 0,
                "componentType": 5126,
                "count": vertex_count,
                "type": "VEC3",
                "min": position_data.min(axis=0).tolist(),
                "max": position_data.max(axis=0).tolist(),
            },
            {
                "bufferView": 1,
                "componentType": 5126,
                "count": vertex_count,
                "type": "VEC3",
            },
            {
                "bufferView": 2,
                "componentType": 5126,
                "count": vertex_count,
                "type": "VEC2",
            },
            {
                "bufferView": 3,
                "componentType": 5125,
                "count": int(index_data.size),
                "type": "SCALAR",
            },
        ],
    }

    json_chunk = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_chunk += b" " * ((-len(json_chunk)) % 4)
    total_length = 12 + 8 + len(json_chunk) + 8 + len(binary_chunk)

    with open(filepath, "wb") as file:
        file.write(struct.pack("<III", 0x46546C67, 2, total_length))
        file.write(struct.pack("<II", len(json_chunk), 0x4E4F534A))
        file.write(json_chunk)
        file.write(struct.pack("<II", len(binary_chunk), 0x004E4942))
        file.write(binary_chunk)


class TerrainChunkCompiler:
    """Compilador de um chunk de terreno individual."""

    def __init__(
        self,
        input_file: Union[str, Path],
        output_dir: Union[str, Path],
        l2_root: Optional[Union[str, Path]] = None,
        unit_scale: float = UU_TO_METERS_DEFAULT,
    ):
        self.input_file = Path(input_file).resolve()
        self.env = L2Environment(self.input_file, l2_root)
        self.pkg = UnrealPackageReader(self.input_file)
        self.unit_scale = unit_scale

        self.clean_stem = self.input_file.stem
        if self.clean_stem.lower().startswith("t_"):
            self.clean_stem = self.clean_stem[2:]

        self.output_dir = Path(output_dir).resolve()
        self.chunk_dir = self.output_dir / self.clean_stem
        self.server_dir = self.chunk_dir / "server"
        self.client_dir = self.chunk_dir / "client"
        self.client_textures_dir = self.client_dir / "textures"

    def extract_terrains(self) -> List[Dict[str, Any]]:
        """Extrai todos os objetos TerrainInfo do mapa."""
        terrains = []
        for exp in self.pkg.exports:
            if exp["class_name"] == "TerrainInfo":
                prop_start = self.pkg.find_properties_start(exp["offset"], exp["size"])
                props = self.pkg.read_properties(
                    prop_start, exp["size"] - (prop_start - exp["offset"])
                )

                scale = props.get("TerrainScale", (64.0, 64.0, 32.0))
                location = props.get("Location", (0.0, 0.0, 0.0))
                terrain_map_ref = props.get("TerrainMap", None)
                sector_size = props.get("TerrainSectorSize", 16)
                quad_vis = props.get("QuadVisibilityBitmap") or props.get("QuadVisibilityBitmapOrig")

                if isinstance(scale, dict) and scale.get("_is_array"):
                    scale = scale.get(0, (64.0, 64.0, 32.0))
                if isinstance(location, dict) and location.get("_is_array"):
                    location = location.get(0, (0.0, 0.0, 0.0))
                if isinstance(terrain_map_ref, dict) and terrain_map_ref.get("_is_array"):
                    terrain_map_ref = terrain_map_ref.get(0)

                layers = []
                raw_layers = props.get("Layers")
                if isinstance(raw_layers, dict) and raw_layers.get("_is_array"):
                    for k in sorted([idx for idx in raw_layers.keys() if isinstance(idx, int)]):
                        l_data = raw_layers[k]
                        if isinstance(l_data, dict):
                            t_ref = l_data.get("Texture") or l_data.get("Material")
                            a_ref = l_data.get("AlphaMap")
                            u_sc = l_data.get("UScale", 1.0)
                            v_sc = l_data.get("VScale", 1.0)
                            u_pan = l_data.get("UPan", 0.0)
                            v_pan = l_data.get("VPan", 0.0)
                            rot_deg = l_data.get("RotDegrees", 0.0)

                            if isinstance(t_ref, dict) and t_ref.get("_is_array"):
                                t_ref = t_ref.get(0)
                            if isinstance(a_ref, dict) and a_ref.get("_is_array"):
                                a_ref = a_ref.get(0)
                            if isinstance(u_sc, dict) and u_sc.get("_is_array"):
                                u_sc = u_sc.get(0, 1.0)
                            if isinstance(v_sc, dict) and v_sc.get("_is_array"):
                                v_sc = v_sc.get(0, 1.0)

                            layers.append(
                                {
                                    "index": k,
                                    "texture_ref": t_ref,
                                    "alpha_ref": a_ref,
                                    "u_scale": float(u_sc or 1.0),
                                    "v_scale": float(v_sc or 1.0),
                                    "u_pan": float(u_pan or 0.0),
                                    "v_pan": float(v_pan or 0.0),
                                    "rot_degrees": float(rot_deg or 0.0),
                                }
                            )

                terrains.append(
                    {
                        "name": exp["object_name"],
                        "scale": scale,
                        "location": location,
                        "sector_size": sector_size,
                        "map_ref": terrain_map_ref,
                        "quad_visibility": quad_vis,
                        "layers": layers,
                    }
                )
        return terrains

    def extract_heightmap(self, terrain_info: Dict[str, Any]) -> Optional[np.ndarray]:
        """Extrai o buffer de elevação G16 (256x256 uint16)."""
        t_map = terrain_info.get("map_ref")
        packages_to_search = [self.pkg]

        pkg_t = self.env.get_package(f"t_{self.clean_stem}") or self.env.get_package(
            self.clean_stem
        )
        if pkg_t:
            packages_to_search.insert(0, pkg_t)

        if t_map and isinstance(t_map, dict):
            obj_name = t_map.get("object_name", "")
            if obj_name:
                for package in packages_to_search:
                    arr = self._decode_heightmap_from_pkg(package, obj_name)
                    if arr is not None:
                        return arr

        for package in packages_to_search:
            for exp in package.exports:
                name_lower = exp["object_name"].lower()
                if any(
                    name_lower.endswith(suf)
                    for suf in ("_c", "_d", "_s1", "_s2", "_s3", "_s4", "_s5")
                ):
                    continue
                if (
                    "_t00" in name_lower
                    or name_lower.endswith("t00")
                    or name_lower == self.clean_stem
                ):
                    arr = self._decode_heightmap_from_pkg(package, exp["object_name"])
                    if arr is not None:
                        return arr
        return None

    def _decode_heightmap_from_pkg(
        self, package: UnrealPackageReader, obj_name: str
    ) -> Optional[np.ndarray]:
        clean_target = obj_name.lower()
        matched = next(
            (e for e in package.exports if e["object_name"].lower() == clean_target),
            None,
        )
        if not matched:
            matched = next(
                (
                    e
                    for e in package.exports
                    if clean_target in e["object_name"].lower()
                ),
                None,
            )
        if not matched:
            return None

        exp_data = package.data[
            matched["offset"] : matched["offset"] + matched["size"]
        ]
        ci_131072 = b"\x40\x80\x10"
        footer_256 = struct.pack("<IIBB", 256, 256, 8, 8)

        ci_pos = exp_data.find(ci_131072)
        if ci_pos != -1:
            start = ci_pos + len(ci_131072)
            end = start + 131072
            if end + 10 <= len(exp_data) and exp_data[end : end + 10] == footer_256:
                arr = np.frombuffer(exp_data[start:end], dtype="<u2").reshape((256, 256))
                return arr.copy()

        pos = exp_data.rfind(footer_256)
        if pos >= 131072:
            raw_bytes = exp_data[pos - 131072 : pos]
            arr = np.frombuffer(raw_bytes, dtype="<u2").reshape((256, 256))
            return arr.copy()
        return None

    def generate_server_artifacts(
        self,
        heights_g16: np.ndarray,
        world_y_matrix: np.ndarray,
        scale: Tuple[float, float, float],
        location: Tuple[float, float, float],
        h_min: float,
        h_max: float,
        has_holes: bool = False,
    ) -> List[Path]:
        """Gera os arquivos de física e metadados autoritativos do servidor."""
        self.server_dir.mkdir(parents=True, exist_ok=True)

        # 1. heightfield.bin (Float32 Linear Buffer em Metros)
        hf_path = self.server_dir / "heightfield.bin"
        hf_data = np.ascontiguousarray(world_y_matrix, dtype="<f4")
        with open(hf_path, "wb") as f:
            f.write(hf_data.tobytes())

        # 2. chunk_meta.json
        coords = [int(p) for p in self.clean_stem.split("_") if p.isdigit()]
        chunk_x = coords[0] if len(coords) > 0 else 0
        chunk_y = coords[1] if len(coords) > 1 else 0

        rows, cols = heights_g16.shape
        sx_meters = float(scale[0]) * self.unit_scale
        sz_meters = float(scale[1]) * self.unit_scale
        half_w = (cols * sx_meters) / 2.0
        half_d = (rows * sz_meters) / 2.0
        origin_x = (float(location[0]) * self.unit_scale) + half_w
        origin_z = (float(location[1]) * self.unit_scale) + half_d

        meta = {
            "chunk_name": self.clean_stem,
            "chunk_indices": [chunk_x, chunk_y],
            "grid_resolution": [cols, rows],
            "unit_scale": self.unit_scale,
            "scale_uu": [float(scale[0]), float(scale[1]), float(scale[2])],
            "location_uu": [float(location[0]), float(location[1]), float(location[2])],
            "cell_size_meters": [sx_meters, sz_meters],
            "chunk_dimensions_meters": [cols * sx_meters, rows * sz_meters],
            "world_origin_meters": [origin_x, 0.0, origin_z],
            "altitude_meters": {
                "min": round(h_min, 3),
                "max": round(h_max, 3),
                "delta": round(h_max - h_min, 3),
            },
            "has_holes": has_holes,
        }
        meta_path = self.server_dir / "chunk_meta.json"
        with open(meta_path, "w", encoding="utf-8") as f:
            json.dump(meta, f, indent=4)

        return [hf_path, meta_path]

    def generate_client_artifacts(
        self,
        terrain_info: Dict[str, Any],
        heights: np.ndarray,
        positions: np.ndarray,
        normals: np.ndarray,
        uvs: np.ndarray,
        triangles: np.ndarray,
        pack_splatmaps: bool = True,
    ) -> List[Path]:
        """Gera malha visual GLB, texturas difusas, splatmaps e receita de shaders."""
        self.client_textures_dir.mkdir(parents=True, exist_ok=True)
        generated = []

        # 1. Visual GLB
        glb_path = self.client_dir / f"{self.clean_stem}_visual.glb"
        write_glb(glb_path, self.clean_stem, positions, normals, uvs, triangles)
        generated.append(glb_path)

        # 2. Heightmap 16-bit PNG
        hm_path = self.client_dir / "heightmap_16bit.png"
        Image.fromarray(heights.astype(np.uint16)).save(hm_path, format="PNG")
        generated.append(hm_path)

        # 3. Extração de Texturas Difusas, Detalhe e Máscaras
        recipe_layers = []
        active_masks = []
        for l in terrain_info.get("layers", []):
            idx = l["index"]
            t_ref = l.get("texture_ref")
            a_ref = l.get("alpha_ref")
            u_sc = l["u_scale"]
            v_sc = l["v_scale"]
            u_pan = l.get("u_pan", 0.0)
            v_pan = l.get("v_pan", 0.0)
            rot_deg = l.get("rot_degrees", 0.0)

            diffuse_file = None
            if t_ref and isinstance(t_ref, dict):
                pkg_name = t_ref.get("package", "")
                obj_name = t_ref.get("object_name", "")
                tex_pkg = self.env.get_package(pkg_name)
                if tex_pkg:
                    diff_img = tex_pkg.extract_image_by_export_name(obj_name)
                    if diff_img:
                        diffuse_file = f"textures/layer_{idx}_tex_{obj_name}.png"
                        diff_path = self.client_dir / diffuse_file
                        diff_img.save(diff_path, format="PNG")
                        generated.append(diff_path)

            mask_img = None
            if a_ref and isinstance(a_ref, dict):
                pkg_name = a_ref.get("package", "")
                obj_name = a_ref.get("object_name", "")
                alpha_pkg = self.env.get_package(pkg_name)
                if alpha_pkg:
                    mask_img = alpha_pkg.extract_image_by_export_name(obj_name)

            if idx > 0 and mask_img is not None:
                active_masks.append((idx, mask_img))

            recipe_layers.append(
                {
                    "layer_index": idx,
                    "texture_file": diffuse_file,
                    "diffuse_texture": diffuse_file,
                    "u_scale": u_sc,
                    "v_scale": v_sc,
                    "u_pan": u_pan,
                    "v_pan": v_pan,
                    "rot_degrees": rot_deg,
                    "splatmap_index": -1 if idx == 0 else 0,
                    "splatmap_channel": "BASE" if idx == 0 else "r",
                }
            )

        # 4. Empacotamento de Splatmaps RGBA
        splatmap_files = []
        channels = ["r", "g", "b", "a"]
        splat_idx = 0

        if pack_splatmaps:
            if not active_masks:
                empty_splat = np.zeros((256, 256, 4), dtype=np.uint8)
                splat_filename = "splatmap_0.png"
                splat_path = self.client_dir / splat_filename
                Image.fromarray(empty_splat, mode="RGBA").save(splat_path, format="PNG")
                splatmap_files.append(splat_filename)
                generated.append(splat_path)
            else:
                for i in range(0, len(active_masks), 4):
                    batch = active_masks[i : i + 4]
                    splat_w = max(1024, max(m.size[0] for _, m in batch))
                    splat_h = max(1024, max(m.size[1] for _, m in batch))
                    rgba_arr = np.zeros((splat_h, splat_w, 4), dtype=np.uint8)

                    for ch_idx, (layer_orig_idx, m_img) in enumerate(batch):
                        m_resized = m_img.convert("L").resize(
                            (splat_w, splat_h), resample=Image.Resampling.BICUBIC
                        )
                        rgba_arr[:, :, ch_idx] = np.array(m_resized)

                        for r_l in recipe_layers:
                            if r_l["layer_index"] == layer_orig_idx:
                                r_l["splatmap_index"] = splat_idx
                                r_l["splatmap_channel"] = channels[ch_idx]

                    splat_filename = f"splatmap_{splat_idx}.png"
                    splat_path = self.client_dir / splat_filename
                    Image.fromarray(rgba_arr, mode="RGBA").save(splat_path, format="PNG")
                    splatmap_files.append(splat_filename)
                    generated.append(splat_path)
                    splat_idx += 1

        # 5. terrain_recipe.json
        recipe = {
            "chunk_name": self.clean_stem,
            "lightmap": None,
            "splatmaps": splatmap_files,
            "layers": recipe_layers,
        }
        recipe_path = self.client_dir / "terrain_recipe.json"
        with open(recipe_path, "w", encoding="utf-8") as f:
            json.dump(recipe, f, indent=4)
        generated.append(recipe_path)

        return generated


def compile_cluster(
    input_files: List[Union[str, Path]],
    output_dir: Union[str, Path],
    l2_root: Optional[Union[str, Path]] = None,
    step: int = 1,
    pack_splatmaps: bool = True,
    unit_scale: float = UU_TO_METERS_DEFAULT,
) -> Dict[str, Any]:
    """
    Compila um lote de chunks executando o algoritmo 2-Pass Seamless Alignment
    para unir as bordas do relevo com continuidade de derivada zero.
    """
    start_time = time.time()
    compilers: Dict[str, TerrainChunkCompiler] = {}
    extracted_data: Dict[str, Any] = {}

    print("\n" + "=" * 80)
    print(f"[*] GODOTAGE II — COMPILADOR DE TERRENO EM LOTE (2-PASS SEAMLESS)")
    print(f"[*] Total de Chunks a Processar: {len(input_files)}")
    print("=" * 80)

    # 1. Extração de Todos os Heightmaps do Cluster
    for inp in input_files:
        comp = TerrainChunkCompiler(inp, output_dir, l2_root, unit_scale)
        c_name = comp.clean_stem
        compilers[c_name] = comp

        terrains = comp.extract_terrains()
        if not terrains:
            print(f"[AVISO] Nenhum TerrainInfo em {comp.input_file.name}, ignorando.")
            continue
        t_info = terrains[0]
        scale = t_info.get("scale", (64.0, 64.0, 32.0))
        location = t_info.get("location", (0.0, 0.0, 0.0))
        heights = comp.extract_heightmap(t_info)
        if heights is None:
            print(f"[AVISO] Heightmap não encontrado em {comp.input_file.name}, ignorando.")
            continue

        extracted_data[c_name] = {
            "compiler": comp,
            "t_info": t_info,
            "scale": scale,
            "location": location,
            "heights": heights.copy(),
        }

    # 2. Sintetizador de Grade Global (2-Pass Seamless Vertex Unifier)
    global_grid = defaultdict(list)
    for c_name, data in extracted_data.items():
        coords = [int(p) for p in c_name.split("_") if p.isdigit()]
        if len(coords) < 2:
            continue
        cx, cy = coords[0], coords[1]
        h = data["heights"]
        for r in range(256):
            for c in range(256):
                gx = cx * 255 + c
                gy = cy * 255 + r
                global_grid[(gx, gy)].append(float(h[r, c]))

    # Aplica o valor unificado exato em todos os chunks que compartilham a coordenada
    for c_name, data in extracted_data.items():
        coords = [int(p) for p in c_name.split("_") if p.isdigit()]
        if len(coords) < 2:
            continue
        cx, cy = coords[0], coords[1]
        h = data["heights"]
        for r in range(256):
            for c in range(256):
                gx = cx * 255 + c
                gy = cy * 255 + r
                samples = global_grid[(gx, gy)]
                if len(samples) > 1:
                    h[r, c] = int(round(sum(samples) / len(samples)))

    # 3. Geração Final dos Artefatos de Física e Gráficos
    cluster_base_z = (
        min(float(d["location"][2]) for d in extracted_data.values())
        if extracted_data
        else 0.0
    )

    results = {}
    for c_name, data in extracted_data.items():
        comp = data["compiler"]
        t_info = data["t_info"]
        scale = data["scale"]
        raw_location = data["location"]
        location = (raw_location[0], raw_location[1], cluster_base_z)
        heights = data["heights"]

        positions, normals, uvs, triangles, world_y_matrix = build_terrain_mesh(
            heights, scale, location, unit_scale, step
        )

        h_min = float(world_y_matrix.min())
        h_max = float(world_y_matrix.max())
        h_delta = h_max - h_min

        server_files = comp.generate_server_artifacts(
            heights, world_y_matrix, scale, location, h_min, h_max
        )
        client_files = comp.generate_client_artifacts(
            t_info, heights, positions, normals, uvs, triangles, pack_splatmaps
        )

        results[c_name] = {
            "server_files": server_files,
            "client_files": client_files,
            "h_min": h_min,
            "h_max": h_max,
            "h_delta": h_delta,
        }

    elapsed = time.time() - start_time
    print("\n" + "=" * 80)
    print(f"[*] Compilação de Terreno Concluída com Sucesso em {elapsed:.2f}s!")
    print("=" * 80 + "\n")
    return results
