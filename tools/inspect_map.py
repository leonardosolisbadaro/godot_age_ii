#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/inspect_map.py — Utilitário Unificado de Inspeção e Diagnóstico de Mapas

@description
Ferramenta unificada com alta coesão e baixo acoplamento para diagnóstico completo de chunks:
1. Relevo & Física: Valida integridade do heightfield.bin, dimensões métricas, desnível e Splatmaps.
2. Continuidade de Bordas: Valida matematicamente a soldagem contínua 2-Pass Seamless Alignment.
3. StaticMeshes & Atores: Inspeciona instâncias, transformações espaciais e biblioteca de modelos GLB.
4. Atmosfera & Iluminação: Diagnóstico de iluminação solar, névoa de distância e superfícies de água.

@created 2026-08-20
@updated 2026-08-20
@author Leonardo S. Badaró
"""

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import sys
from typing import List, Optional
import numpy as np

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
    TERRAIN_GRID_RESOLUTION,
    validate_pipeline_environment,
)


def inspect_terrain(maps_dir: Path, chunk_name: str) -> None:
    """Inspeciona os artefatos de terreno do servidor e cliente."""
    chunk_dir = maps_dir / chunk_name
    server_dir = chunk_dir / "server"
    client_dir = chunk_dir / "client"
    textures_dir = client_dir / "textures"

    print(f"\n[+] 1. RELEVO & TERRENO: Chunk {chunk_name}")
    print(f"    -> Pasta do Chunk : {chunk_dir}")

    # Metadados do Servidor
    meta_path = server_dir / "chunk_meta.json"
    hf_path = server_dir / "heightfield.bin"

    if meta_path.is_file():
        with open(meta_path, "r", encoding="utf-8") as f:
            meta = json.load(f)
        dims = meta.get("chunk_dimensions_meters", [0, 0])
        cells = meta.get("cell_size_meters", [0, 0])
        alt = meta.get("altitude_meters", {})
        origin = meta.get("world_origin_meters", [0, 0, 0])

        print(f"    [SERVIDOR — Física & Bounds]")
        print(f"       * Dimensão Real : {dims[0]:.1f}m x {dims[1]:.1f}m ({cells[0]:.1f}m por célula)")
        print(f"       * Origem Mundo  : X={origin[0]:.1f}m, Z={origin[2]:.1f}m")
        print(f"       * Altitude      : Mín={alt.get('min')}m | Máx={alt.get('max')}m | Desnível={alt.get('delta')}m")

    if hf_path.is_file():
        hf_kb = hf_path.stat().st_size / 1024.0
        print(f"       * heightfield.bin: {hf_kb:.1f} KB (Float32 Linear Buffer)")
    else:
        print(f"       * [!] heightfield.bin pendente de compilação.")

    # Artefatos do Cliente
    glb_path = client_dir / f"{chunk_name}_visual.glb"
    recipe_path = client_dir / "terrain_recipe.json"
    hm_path = client_dir / "heightmap_16bit.png"

    print(f"    [CLIENTE — Renderização Godot 4.7]")
    if glb_path.is_file():
        glb_mb = glb_path.stat().st_size / (1024.0 * 1024.0)
        print(f"       * Malha 3D GLB  : {glb_path.name} ({glb_mb:.2f} MB)")
    if hm_path.is_file():
        print(f"       * Heightmap PNG : {hm_path.name} (16-bit uint16)")

    splatmaps = list(client_dir.glob("splatmap_*.png"))
    textures = list(textures_dir.glob("*.png")) if textures_dir.is_dir() else []
    print(f"       * Splatmaps RGBA: {len(splatmaps)} arquivo(s)")
    print(f"       * Texturas Solo : {len(textures)} textura(s) extraída(s)")

    if recipe_path.is_file():
        with open(recipe_path, "r", encoding="utf-8") as f:
            recipe = json.load(f)
        layers_count = len(recipe.get("layers", []))
        print(f"       * Receita Shader: {recipe_path.name} ({layers_count} camadas configuradas)")


def test_continuity(maps_dir: Path, chunks: List[str]) -> None:
    """Valida matematicamente a junção perfeita de bordas entre chunks vizinhos."""
    print("\n" + "=" * 80)
    print(" [*] TESTE DE CONTINUIDADE DE BORDAS ENTRE CHUNKS (2-PASS SEAMLESS)")
    print("=" * 80)

    heightfields = {}
    res = TERRAIN_GRID_RESOLUTION
    for c in chunks:
        hf_file = maps_dir / c / "server" / "heightfield.bin"
        if hf_file.is_file():
            heightfields[c] = np.fromfile(hf_file, dtype="<f4").reshape((res, res))

    if len(heightfields) < 2:
        print(" [!] Menos de 2 chunks compilados disponíveis para teste de fronteira.")
        return

    # Junção Norte/Sul: 16_24 Topo x 16_25 Base
    if "16_24" in heightfields and "16_25" in heightfields:
        diff_ns = np.abs(heightfields["16_24"][res - 1, :] - heightfields["16_25"][0, :])
        max_diff = float(np.max(diff_ns))
        status = "[PERFEITO (0.0000m)]" if max_diff < 0.0001 else f"[DESVIO: {max_diff:.4f}m]"
        print(f" -> Junção Norte/Sul  (16_24 Topo x 16_25 Base) : {status} (Erro máx: {max_diff:.6f}m)")

    # Junção Norte/Sul: 17_24 Topo x 17_25 Base
    if "17_24" in heightfields and "17_25" in heightfields:
        diff_ns2 = np.abs(heightfields["17_24"][res - 1, :] - heightfields["17_25"][0, :])
        max_diff2 = float(np.max(diff_ns2))
        status2 = "[PERFEITO (0.0000m)]" if max_diff2 < 0.0001 else f"[DESVIO: {max_diff2:.4f}m]"
        print(f" -> Junção Norte/Sul  (17_24 Topo x 17_25 Base) : {status2} (Erro máx: {max_diff2:.6f}m)")

    # Junção Oeste/Leste: 16_24 Dir x 17_24 Esq
    if "16_24" in heightfields and "17_24" in heightfields:
        diff_ew = np.abs(heightfields["16_24"][:, res - 1] - heightfields["17_24"][:, 0])
        max_diff_ew = float(np.max(diff_ew))
        status_ew = "[PERFEITO (0.0000m)]" if max_diff_ew < 0.0001 else f"[DESVIO: {max_diff_ew:.4f}m]"
        print(f" -> Junção Oeste/Leste (16_24 Dir  x 17_24 Esq) : {status_ew} (Erro máx: {max_diff_ew:.6f}m)")

    # Junção Oeste/Leste: 16_25 Dir x 17_25 Esq
    if "16_25" in heightfields and "17_25" in heightfields:
        diff_ew2 = np.abs(heightfields["16_25"][:, res - 1] - heightfields["17_25"][:, 0])
        max_diff_ew2 = float(np.max(diff_ew2))
        status_ew2 = "[PERFEITO (0.0000m)]" if max_diff_ew2 < 0.0001 else f"[DESVIO: {max_diff_ew2:.4f}m]"
        print(f" -> Junção Oeste/Leste (16_25 Dir  x 17_25 Esq) : {status_ew2} (Erro máx: {max_diff_ew2:.6f}m)")


def inspect_objects(maps_dir: Path, models_dir: Path, chunk_name: str) -> None:
    """Inspeciona as instâncias de StaticMeshActor e malhas .glb geradas."""
    print(f"\n[+] 2. STATICMESHES & ATORES: Chunk {chunk_name}")

    actors_json = maps_dir / chunk_name / "chunk_static_actors.json"
    if not actors_json.is_file():
        actors_json = maps_dir / chunk_name / "client" / "chunk_static_actors.json"

    if actors_json.is_file():
        with open(actors_json, "r", encoding="utf-8") as f:
            data = json.load(f)

        total_actors = data.get("total_actors", 0)
        unique_meshes = data.get("unique_meshes_count", 0)
        actors = data.get("actors", [])

        print(f"    -> Total de StaticMeshActors : {total_actors}")
        print(f"    -> Tipos de Malhas Únicas   : {unique_meshes}")

        counts = Counter()
        for a in actors:
            m = a.get("mesh_ref", {})
            if isinstance(m, dict):
                counts[f"{m.get('package')}.{m.get('object_name')}"] += 1

        print("\n    [TOP 6 MALHAS MAIS FREQUENTES NO CHUNK]")
        for m_name, c in counts.most_common(6):
            print(f"       * {c:>3}x  {m_name}")
    else:
        print(f"    [AVISO] {actors_json.name} não encontrado para {chunk_name}.")

    glbs = list(models_dir.glob("**/*.glb"))
    print(f"\n    [BIBLIOTECA GLOBAL DE MODELOS 3D (.GLB)]")
    print(f"    -> Total de Modelos Extraídos : {len(glbs)} arquivo(s)")


def inspect_environment(maps_dir: Path, chunk_name: str) -> None:
    """Inspeciona receitas de atmosfera, iluminação e água."""
    print(f"\n[+] 3. ATMOSFERA & ILUMINAÇÃO: Chunk {chunk_name}")

    recipe_file = maps_dir / chunk_name / "client" / "environment_recipe.json"
    water_file = maps_dir / chunk_name / "server" / "water_volumes.json"
    mat_file = maps_dir / chunk_name / "client" / "material_recipes.json"

    if recipe_file.is_file():
        with open(recipe_file, "r", encoding="utf-8") as f:
            rec = json.load(f)
        sun = rec.get("sunlight", {})
        fog = rec.get("distance_fog", {})
        amb = rec.get("ambient_lighting", {})
        print(f"    -> Sol Direcional : Cor={sun.get('color_rgb')} | Energia={sun.get('energy')}")
        print(f"    -> Névoa Distância: Início={fog.get('begin_meters')}m | Fim={fog.get('end_meters')}m | Cor={fog.get('color_rgb')}")
        print(f"    -> Luz Ambiente   : Cor={amb.get('color_rgb')} | Energia={amb.get('energy')}")
    else:
        print(f"    [!] Receita de ambiente pendente de compilação.")

    if water_file.is_file():
        with open(water_file, "r", encoding="utf-8") as f:
            wdata = json.load(f)
        waters = wdata.get("water_volumes", [])
        print(f"    -> Volumes de Água: {len(waters)} plano(s) registrado(s)")
        for w in waters:
            print(f"       * {w.get('name')}: Plano Z = {w.get('water_plane_height_m')}m (Atrito: {w.get('fluid_friction')})")


def main():
    parser = argparse.ArgumentParser(
        description=(
            "GODOTAGE II — Utilitário Unificado de Inspeção e Diagnóstico de Mapas\n\n"
            "Permite inspecionar relevo, continuidade matemática de soldagem entre chunks,\n"
            "instâncias de atores estáticos e parâmetros atmosféricos de iluminação."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Exemplos de uso:\n"
            "  python tools/inspect_map.py 16_24\n"
            "  python tools/inspect_map.py --continuity 16_24 16_25 17_24 17_25\n"
            "  python tools/inspect_map.py 16_24 --terrain\n"
            "  python tools/inspect_map.py 16_24 --objects\n"
            "  python tools/inspect_map.py 16_24 --open-folder\n"
        ),
    )
    parser.add_argument(
        "maps",
        nargs="*",
        default=["16_24"],
        help="Nomes dos chunks a inspecionar (padrão: 16_24)",
    )
    parser.add_argument(
        "--terrain",
        action="store_true",
        help="Inspeciona apenas dados e artefatos de terreno",
    )
    parser.add_argument(
        "--objects",
        action="store_true",
        help="Inspeciona apenas atores e modelos estáticos",
    )
    parser.add_argument(
        "--environment",
        action="store_true",
        help="Inspeciona apenas parâmetros de atmosfera e iluminação",
    )
    parser.add_argument(
        "--continuity",
        action="store_true",
        help="Executa o teste matemático de continuidade de bordas do cluster",
    )
    parser.add_argument(
        "--open-folder",
        action="store_true",
        help="Abre a pasta do chunk no Windows Explorer",
    )

    args = parser.parse_args()

    config = PipelineConfig()
    maps_dir = config.maps_output_dir
    models_dir = config.models_output_dir

    print("=" * 80)
    print(" [*] GODOTAGE II — PAINEL DE DIAGNÓSTICO E INSPEÇÃO DE MAPAS")
    print("=" * 80)

    inspect_all = not (args.terrain or args.objects or args.environment or args.continuity)

    if args.continuity or len(args.maps) > 1:
        test_continuity(maps_dir, args.maps)

    for m in args.maps:
        if inspect_all or args.terrain:
            inspect_terrain(maps_dir, m)
        if inspect_all or args.objects:
            inspect_objects(maps_dir, models_dir, m)
        if inspect_all or args.environment:
            inspect_environment(maps_dir, m)

    print("\n" + "=" * 80 + "\n")

    if args.open_folder and len(args.maps) > 0:
        target_dir = maps_dir / args.maps[0] / "client"
        if target_dir.is_dir():
            os.startfile(str(target_dir))


if __name__ == "__main__":
    main()
