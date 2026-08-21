#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/build_objects.py — Extrator e Compilador de StaticMeshes e Atores (Etapa 1.3)

@description
Extrai e compila:
1. Malhas 3D (.glb) reutilizáveis a partir dos pacotes .usx e/ou UModel export na raiz do projeto.
2. Instâncias de posicionamento de StaticMeshActor dentro dos mapas .unr (chunk_static_actors.json).
Inclui validação rigorosa de pré-requisitos antes da execução.

@created 2026-08-18
@updated 2026-08-20
@author Leonardo S. Badaró
"""

import argparse
import json
import os
from pathlib import Path
import struct
import sys
import time
from typing import Any, Dict, List, Optional, Set, Tuple, Union

# Força UTF-8 no stdout/stderr no Windows
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Adiciona a raiz do projeto ao path
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from tools.l2_extractor import (
    L2Environment,
    PipelineConfig,
    StaticMeshParser,
    UMODEL_TO_CANONICAL_SCALE,
    UU_TO_METERS_CANONICAL,
    UnrealPackageReader,
    export_package_meshes,
    extract_map_static_actors,
    find_umodel_executable,
    validate_pipeline_environment,
    write_glb,
)


# ==============================================================================
# CONSTANTES SEMÂNTICAS DO CONVERSOR GLTF -> GLB
# ==============================================================================

## @const GLTF_POS_BYTE_STRIDE (int)
## O que: Stride em bytes de 1 vetor de posição no buffer glTF (12 bytes = 3 * float32).
## Porque: 3 coordenadas de precisão simples (X, Y, Z).
GLTF_POS_BYTE_STRIDE: int = 12

## @const GLB_HEADER_MAGIC (int)
## O que: Assinatura de 32 bits de arquivos GLB binários (0x46546C67).
## Porque: Padrão binário do glTF 2.0.
GLB_HEADER_MAGIC: int = 0x46546C67

## @const GLB_CHUNK_JSON (int)
## O que: Tipo de chunk JSON no contêiner GLB (0x4E4F534A).
## Porque: Especificação glTF 2.0.
GLB_CHUNK_JSON: int = 0x4E4F534A

## @const GLB_CHUNK_BIN (int)
## O que: Tipo de chunk binário no contêiner GLB (0x004E4942).
## Porque: Especificação glTF 2.0.
GLB_CHUNK_BIN: int = 0x004E4942


def gltf_to_glb(gltf_path: Path, glb_path: Path, scale_factor: float = UMODEL_TO_CANONICAL_SCALE) -> bool:
    """
    Converte arquivo .gltf + .bin do UModel para formato .glb binário do Godot 4.
    Preserva 100% da estrutura multi-primitiva, materiais, tangentes e UVs do UModel,
    removendo primitivas com 0 triângulos para compatibilidade estrita com o Godot.
    """
    try:
        with open(gltf_path, "r", encoding="utf-8") as f:
            gltf = json.load(f)

        bin_name = gltf["buffers"][0]["uri"]
        bin_file = gltf_path.parent / bin_name
        if not bin_file.is_file():
            return False

        bin_data = bin_file.read_bytes()
        gltf_copy = json.loads(json.dumps(gltf))

        # 1. Filtra primitivas válidas (que têm vértices e índices com count > 0)
        mesh = gltf_copy["meshes"][0]
        valid_primitives = []
        used_accessor_indices = set()

        for prim in mesh.get("primitives", []):
            idx_acc_i = prim.get("indices")
            pos_acc_i = prim.get("attributes", {}).get("POSITION")

            has_valid_idx = (
                idx_acc_i is not None
                and idx_acc_i < len(gltf_copy["accessors"])
                and gltf_copy["accessors"][idx_acc_i].get("count", 0) > 0
            )
            has_valid_pos = (
                pos_acc_i is not None
                and pos_acc_i < len(gltf_copy["accessors"])
                and gltf_copy["accessors"][pos_acc_i].get("count", 0) > 0
            )

            if has_valid_idx and has_valid_pos:
                valid_primitives.append(prim)
                used_accessor_indices.add(idx_acc_i)
                for attr_acc in prim.get("attributes", {}).values():
                    used_accessor_indices.add(attr_acc)

        if not valid_primitives:
            return False

        # 2. Reconstrói o array de accessors excluindo qualquer accessor com count 0 ou não utilizado
        old_accessors = gltf_copy.get("accessors", [])
        new_accessors = []
        old_to_new_acc = {}

        for old_idx, acc in enumerate(old_accessors):
            if old_idx in used_accessor_indices and acc.get("count", 0) > 0:
                old_to_new_acc[old_idx] = len(new_accessors)
                new_accessors.append(acc)

        # 3. Remapeia os índices de accessors em todas as primitivas válidas e escala os vértices
        bin_data_mut = bytearray(bin_data)
        scaled_bv_indices = set()

        for prim in valid_primitives:
            if "indices" in prim:
                prim["indices"] = old_to_new_acc[prim["indices"]]
            for attr_name, old_acc in list(prim.get("attributes", {}).items()):
                new_acc_idx = old_to_new_acc[old_acc]
                prim["attributes"][attr_name] = new_acc_idx
                if attr_name == "POSITION":
                    acc = new_accessors[new_acc_idx]
                    bv_idx = acc["bufferView"]
                    if bv_idx not in scaled_bv_indices:
                        scaled_bv_indices.add(bv_idx)
                        bv = gltf_copy["bufferViews"][bv_idx]
                        b_off = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
                        stride = bv.get("byteStride", GLTF_POS_BYTE_STRIDE)
                        cnt = acc.get("count", 0)
                        for i in range(cnt):
                            p_curr = b_off + i * stride
                            if p_curr + GLTF_POS_BYTE_STRIDE <= len(bin_data_mut):
                                x, y, z = struct.unpack_from("<fff", bin_data_mut, p_curr)
                                struct.pack_into(
                                    "<fff",
                                    bin_data_mut,
                                    p_curr,
                                    x * scale_factor,
                                    y * scale_factor,
                                    z * scale_factor,
                                )
                    if "min" in acc:
                        acc["min"] = [v * scale_factor for v in acc["min"]]
                    if "max" in acc:
                        acc["max"] = [v * scale_factor for v in acc["max"]]

        bin_data = bytes(bin_data_mut)
        mesh["primitives"] = valid_primitives
        gltf_copy["accessors"] = new_accessors

        gltf_copy["buffers"][0].pop("uri", None)
        gltf_copy["buffers"][0]["byteLength"] = len(bin_data)

        json_str = json.dumps(gltf_copy, separators=(",", ":"))
        json_bytes = json_str.encode("utf-8")
        json_padding = (4 - (len(json_bytes) % 4)) % 4
        json_bytes += b" " * json_padding

        bin_padding = (4 - (len(bin_data) % 4)) % 4
        bin_data += b"\x00" * bin_padding

        total_size = 12 + 8 + len(json_bytes) + 8 + len(bin_data)
        glb_bytes = bytearray()
        glb_bytes += struct.pack("<III", GLB_HEADER_MAGIC, 2, total_size)
        glb_bytes += struct.pack("<II", len(json_bytes), GLB_CHUNK_JSON)
        glb_bytes += json_bytes
        glb_bytes += struct.pack("<II", len(bin_data), GLB_CHUNK_BIN)
        glb_bytes += bin_data

        glb_path.parent.mkdir(parents=True, exist_ok=True)
        glb_path.write_bytes(glb_bytes)
        return True
    except Exception as e:
        print(f"    [AVISO] Falha ao converter {gltf_path.name} para GLB: {e}", file=sys.stderr)
        return False


def build_mesh_glb(
    pkg_name: str,
    obj_name: str,
    env: L2Environment,
    models_dir: Path,
    umodel_root: Path,
    force: bool = False,
    config: Optional[PipelineConfig] = None,
) -> Optional[Path]:
    """Extrai ou converte uma malha específica para .glb em assets/models/<pkg_name>/<obj_name>.glb."""
    pkg_models_dir = models_dir / pkg_name.lower()
    glb_path = pkg_models_dir / f"{obj_name}.glb"

    if glb_path.is_file() and not force:
        return glb_path

    # 1. Se existir export do UModel em UmodelExport/, converte com prioridade
    umodel_gltf = umodel_root / pkg_name.lower() / "StaticMesh" / f"{obj_name}.gltf"
    if not umodel_gltf.is_file():
        umodel_exe = find_umodel_executable(config)
        if umodel_exe and env.l2_root:
            print(f"    -> [UModel CLI] Extraindo pacote de malhas 3D: {pkg_name}...")
            export_package_meshes(pkg_name, env.l2_root, umodel_root, umodel_exe)

    if umodel_gltf.is_file():
        if gltf_to_glb(umodel_gltf, glb_path, scale_factor=UMODEL_TO_CANONICAL_SCALE):
            return glb_path

    # 2. Extração nativa diretamente do pacote .usx
    usx_pkg = env.get_package(pkg_name)
    if usx_pkg:
        parser = StaticMeshParser(usx_pkg, unit_scale=UU_TO_METERS_CANONICAL, config=config)
        exp = next(
            (e for e in usx_pkg.exports if e["object_name"].lower() == obj_name.lower()),
            None,
        )
        if exp:
            mesh_data = parser.extract_mesh_by_export(exp)
            if (
                mesh_data
                and mesh_data["num_vertices"] >= 3
                and mesh_data["num_triangles"] >= 1
            ):
                pkg_models_dir.mkdir(parents=True, exist_ok=True)
                write_glb(
                    glb_path,
                    obj_name,
                    mesh_data["positions"],
                    mesh_data["normals"],
                    mesh_data["uvs"],
                    mesh_data["triangles"],
                )
                return glb_path

    return None


def extract_package_meshes_all(
    pkg_name: str,
    env: L2Environment,
    models_dir: Path,
    umodel_root: Path,
    force: bool = False,
    config: Optional[PipelineConfig] = None,
) -> Dict[str, Path]:
    """Extrai todas as malhas estáticas de um pacote .usx para arquivos .glb."""
    pkg = env.get_package(pkg_name)
    if not pkg:
        return {}

    saved_meshes = {}
    for exp in pkg.exports:
        if exp["class_name"] == "StaticMesh":
            m_name = exp["object_name"]
            res = build_mesh_glb(pkg_name, m_name, env, models_dir, umodel_root, force=force, config=config)
            if res:
                saved_meshes[m_name] = res

    return saved_meshes


def process_chunk_objects(
    map_name_or_path: str,
    env: L2Environment,
    maps_dir: Path,
    models_dir: Path,
    unit_scale: float = UU_TO_METERS_CANONICAL,
    force: bool = False,
    config: Optional[PipelineConfig] = None,
) -> Dict[str, Any]:
    """Processa todos os StaticMeshActors de um mapa .unr e extrai as malhas necessárias."""
    inp_path = Path(map_name_or_path)
    if inp_path.is_file():
        map_path = inp_path
        clean_name = inp_path.stem.lower()
    else:
        clean_name = inp_path.stem.lower()
        map_path = env.available_unr.get(clean_name)

    if not map_path or not map_path.is_file():
        print(f"[ERRO] Mapa .unr não encontrado: {map_name_or_path}", file=sys.stderr)
        return {}

    # Carrega heightfield se disponível
    hf = None
    hf_path = maps_dir / clean_name / "server" / "heightfield.bin"
    if hf_path.is_file():
        import numpy as np
        hf = np.fromfile(hf_path, dtype="<f4").reshape((256, 256))

    map_pkg = UnrealPackageReader(map_path)
    actors = extract_map_static_actors(map_pkg, unit_scale, heightfield=hf)
    print(f"\n[+] Chunk {clean_name}: {len(actors)} StaticMeshActors encontrados.")

    needed_meshes = set()
    for a in actors:
        m_ref = a.get("mesh_ref")
        if m_ref and isinstance(m_ref, dict):
            pkg_n = m_ref.get("package")
            obj_n = m_ref.get("object_name")
            if pkg_n and obj_n:
                needed_meshes.add((pkg_n.lower(), obj_n))

    print(f"    -> Malhas únicas referenciadas: {len(needed_meshes)}")

    # Extrai cada malha necessária
    extracted_count = 0
    umodel_root = config.umodel_export_dir if config else maps_dir.parent.parent / "UmodelExport"

    for pkg_n, obj_n in needed_meshes:
        res = build_mesh_glb(pkg_n, obj_n, env, models_dir, umodel_root, force=force, config=config)
        if res:
            extracted_count += 1

    print(f"    -> Total de malhas 3D (.glb) compiladas: {extracted_count}")

    chunk_root = maps_dir / clean_name
    chunk_root.mkdir(parents=True, exist_ok=True)

    actors_meta = {
        "chunk_name": clean_name,
        "total_actors": len(actors),
        "unique_meshes_count": len(needed_meshes),
        "actors": actors,
    }

    root_json = chunk_root / "chunk_static_actors.json"
    with open(root_json, "w", encoding="utf-8") as f:
        json.dump(actors_meta, f, indent=4)

    print(f"    -> Salvo metadados unificados em: {root_json.name}")
    return actors_meta


def main():
    parser = argparse.ArgumentParser(
        description=(
            "GODOTAGE II — Extrator de StaticMeshes e Atores (Lineage II -> Godotage II)\n\n"
            "Converte modelos 3D (.usx) em arquivos .glb otimizados para o Godot 4.7 e extrai\n"
            "o posicionamento exato de todos os StaticMeshActors de chunks de mapa (.unr)."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Exemplos de uso:\n"
            "  python tools/build_objects.py 16_24\n"
            "  python tools/build_objects.py 16_24 16_25\n"
            "  python tools/build_objects.py --all-meshes field_deco_artifact_s\n"
            "  python tools/build_objects.py 16_24 --force\n"
        ),
    )
    parser.add_argument(
        "maps",
        nargs="*",
        help="Nomes dos mapas .unr (ex: 16_24 16_25)",
    )
    parser.add_argument(
        "--all-meshes",
        default=None,
        help="Extrai todas as malhas de um pacote .usx específico (ex: speaking_tree_s)",
    )
    parser.add_argument(
        "--l2-root",
        default=None,
        help="Caminho raiz personalizado de instalação do Lineage II (padrão: Lineage II/ na raiz)",
    )
    parser.add_argument(
        "--force",
        "-f",
        action="store_true",
        help="Força re-extração e sobrescrita de todas as malhas .glb",
    )

    args = parser.parse_args()

    config = PipelineConfig(
        l2_root_dir=Path(args.l2_root) if args.l2_root else None,
        force_rebuild=args.force,
    )
    validate_pipeline_environment(config, require_l2_root=True, require_umodel=False, abort_on_error=True)

    maps_dir = config.maps_output_dir
    models_dir = config.models_output_dir
    umodel_root = config.umodel_export_dir
    env = L2Environment(config=config, l2_root=config.l2_root_dir)

    print("=" * 80)
    print(" [*] GODOTAGE II — EXTRATOR DE STATICMESHES E ATORES (ETAPA 1.3)")
    print("=" * 80)

    if args.all_meshes:
        pkg_name = args.all_meshes.lower()
        if pkg_name.endswith(".usx"):
            pkg_name = pkg_name[:-4]
        print(f"\n[+] Extraindo todas as malhas de: {pkg_name}.usx...")
        saved = extract_package_meshes_all(pkg_name, env, models_dir, umodel_root, force=args.force, config=config)
        print(f"[OK] {len(saved)} malha(s) .glb extraída(s) em: {models_dir / pkg_name}")
        return

    if not args.maps:
        args.maps = ["16_24"]

    start_time = time.time()
    for m in args.maps:
        process_chunk_objects(m, env, maps_dir, models_dir, force=args.force, config=config)

    elapsed = time.time() - start_time
    print("\n" + "=" * 80)
    print(f" [*] Extração de Objetos e Atores Concluída com Sucesso em {elapsed:.2f}s!")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    main()
