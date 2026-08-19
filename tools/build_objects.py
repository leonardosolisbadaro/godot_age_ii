#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/build_objects.py — Extrator e Compilador de StaticMeshes e Atores (Etapa 1.3)

Extrai:
1. Malhas 3D (.glb) reutilizáveis a partir dos pacotes .usx e/ou UmodelExport
2. Instâncias de posicionamento de StaticMeshActor dentro dos mapas .unr (chunk_static_actors.json)

Uso:
    python tools/build_objects.py 16_24
    python tools/build_objects.py 16_24 16_25
    python tools/build_objects.py --all-meshes field_deco_artifact_s
    python tools/build_objects.py 16_24 --force
"""

import argparse
import json
import os
import struct
import sys
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple, Union

# Força UTF-8 no stdout/stderr no Windows
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Adiciona a raiz do projeto ao path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from tools.l2_extractor import (
    L2Environment,
    UnrealPackageReader,
    StaticMeshParser,
    extract_map_static_actors,
    write_glb,
    UU_TO_METERS_DEFAULT,
)


def gltf_to_glb(gltf_path: Path, glb_path: Path) -> bool:
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

        # 3. Remapeia os índices de accessors em todas as primitivas válidas
        for prim in valid_primitives:
            if "indices" in prim:
                prim["indices"] = old_to_new_acc[prim["indices"]]
            for attr_name, old_acc in list(prim.get("attributes", {}).items()):
                prim["attributes"][attr_name] = old_to_new_acc[old_acc]

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
        glb_bytes += struct.pack("<III", 0x46546C67, 2, total_size)
        glb_bytes += struct.pack("<II", len(json_bytes), 0x4E4F534A)
        glb_bytes += json_bytes
        glb_bytes += struct.pack("<II", len(bin_data), 0x004E4942)
        glb_bytes += bin_data

        glb_path.parent.mkdir(parents=True, exist_ok=True)
        glb_path.write_bytes(glb_bytes)
        return True
    except Exception as e:
        print(f"    [AVISO] Falha ao converter {gltf_path.name} para GLB: {e}")
        return False


def build_mesh_glb(
    pkg_name: str,
    obj_name: str,
    env: L2Environment,
    models_dir: Path,
    umodel_root: Path,
    force: bool = False,
) -> Optional[Path]:
    """Extrai ou converte uma malha específica para .glb em assets/models/<pkg_name>/<obj_name>.glb."""
    pkg_models_dir = models_dir / pkg_name.lower()
    glb_path = pkg_models_dir / f"{obj_name}.glb"

    if glb_path.is_file() and not force:
        return glb_path

    # 1. Se existir export canônico do UModel em UmodelExport/, converte com prioridade
    umodel_gltf = umodel_root / pkg_name.lower() / "StaticMesh" / f"{obj_name}.gltf"
    if umodel_gltf.is_file():
        if gltf_to_glb(umodel_gltf, glb_path):
            return glb_path

    # 2. Extração nativa diretamente do pacote .usx
    usx_pkg = env.get_package(pkg_name)
    if usx_pkg:
        parser = StaticMeshParser(usx_pkg)
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


def extract_package_meshes(
    pkg_name: str,
    env: L2Environment,
    models_dir: Path,
    umodel_root: Path,
    force: bool = False,
) -> Dict[str, Path]:
    """Extrai todas as malhas estáticas de um pacote .usx para arquivos .glb."""
    pkg = env.get_package(pkg_name)
    if not pkg:
        return {}

    saved_meshes = {}
    for exp in pkg.exports:
        if exp["class_name"] == "StaticMesh":
            m_name = exp["object_name"]
            res = build_mesh_glb(pkg_name, m_name, env, models_dir, umodel_root, force)
            if res:
                saved_meshes[m_name] = res

    return saved_meshes


def process_chunk_objects(
    map_name_or_path: str,
    env: L2Environment,
    maps_dir: Path,
    models_dir: Path,
    unit_scale: float = UU_TO_METERS_DEFAULT,
    force: bool = False,
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
        print(f"[ERRO] Mapa .unr não encontrado: {map_name_or_path}")
        return {}

    map_pkg = UnrealPackageReader(map_path)
    actors = extract_map_static_actors(map_pkg, unit_scale)
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
    project_root = maps_dir.parent.parent
    umodel_root = project_root / "UmodelExport"

    for pkg_n, obj_n in needed_meshes:
        res = build_mesh_glb(pkg_n, obj_n, env, models_dir, umodel_root, force)
        if res:
            extracted_count += 1

    print(f"    -> Total de malhas 3D (.glb) compiladas: {extracted_count}")

    # Salva chunk_static_actors.json para Cliente e Servidor
    chunk_client_dir = maps_dir / clean_name / "client"
    chunk_server_dir = maps_dir / clean_name / "server"
    chunk_client_dir.mkdir(parents=True, exist_ok=True)
    chunk_server_dir.mkdir(parents=True, exist_ok=True)

    actors_meta = {
        "chunk_name": clean_name,
        "total_actors": len(actors),
        "unique_meshes_count": len(needed_meshes),
        "actors": actors,
    }

    client_json = chunk_client_dir / "chunk_static_actors.json"
    server_json = chunk_server_dir / "chunk_static_actors.json"

    with open(client_json, "w", encoding="utf-8") as f:
        json.dump(actors_meta, f, indent=4)
    with open(server_json, "w", encoding="utf-8") as f:
        json.dump(actors_meta, f, indent=4)

    print(f"    -> Salvo instâncias em: {client_json.name} e {server_json.name}")
    return actors_meta


def main():
    parser = argparse.ArgumentParser(
        description="Extrator de StaticMeshes e Atores (Lineage II -> Godotage II)"
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
        help="Caminho raiz de instalação do Lineage II",
    )
    parser.add_argument(
        "--force",
        "-f",
        action="store_true",
        help="Força re-extração e sobrescrita de todas as malhas .glb",
    )

    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    maps_dir = project_root / "assets" / "maps"
    models_dir = project_root / "assets" / "models"
    umodel_root = project_root / "UmodelExport"
    env = L2Environment(l2_root=args.l2_root)

    print("=" * 80)
    print(" [*] GODOTAGE II — EXTRATOR DE STATICMESHES E ATORES (ETAPA 1.3)")
    print("=" * 80)

    if args.all_meshes:
        pkg_name = args.all_meshes.lower()
        if pkg_name.endswith(".usx"):
            pkg_name = pkg_name[:-4]
        print(f"\n[+] Extraindo todas as malhas de: {pkg_name}.usx...")
        saved = extract_package_meshes(pkg_name, env, models_dir, umodel_root, args.force)
        print(f"[OK] {len(saved)} malha(s) .glb extraída(s) em: {models_dir / pkg_name}")
        return

    if not args.maps:
        args.maps = ["16_24"]

    for m in args.maps:
        process_chunk_objects(m, env, maps_dir, models_dir, force=args.force)

    print("\n" + "=" * 80)
    print(" [*] Extração de Objetos e Atores Concluída com Sucesso!")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    main()
