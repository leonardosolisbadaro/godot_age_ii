#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/inspect_terrain.py — Utilitário de Inspeção e Teste Manual do Pipeline de Terreno (Etapa 1.2)

Inspeciona e valida visualmente e matematicamente os artefatos de terreno gerados:
- Integridade da Malha 3D GLB (Vértices, Triângulos, Tamanho)
- Texturas de Solo e Splatmaps RGBA
- Metadados e Buffers Físicos do Servidor (Altitudes, Desnível, Dimensões Métricas)
- Validação Matemática de Soldagem Contínua de Bordas (2-Pass Seamless Alignment)

Uso:
    python tools/inspect_terrain.py
    python tools/inspect_terrain.py --chunk 16_24
    python tools/inspect_terrain.py --cluster 16_24 16_25 17_24 17_25
    python tools/inspect_terrain.py --open-folder
"""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import numpy as np

# Força UTF-8 no stdout/stderr no Windows
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Adiciona a raiz do projeto ao path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


def inspect_single_chunk(maps_dir: Path, chunk_name: str) -> None:
    chunk_dir = maps_dir / chunk_name
    server_dir = chunk_dir / "server"
    client_dir = chunk_dir / "client"
    textures_dir = client_dir / "textures"

    print(f"\n[+] INSPEÇÃO DO CHUNK: {chunk_name}")
    print(f"    -> Pasta do Chunk : {chunk_dir.resolve()}")

    # 1. Metadados do Servidor
    meta_path = server_dir / "chunk_meta.json"
    hf_path = server_dir / "heightfield.bin"

    if meta_path.is_file():
        with open(meta_path, "r", encoding="utf-8") as f:
            meta = json.load(f)
        dims = meta.get("chunk_dimensions_meters", [0, 0])
        cells = meta.get("cell_size_meters", [0, 0])
        alt = meta.get("altitude_meters", {})
        origin = meta.get("world_origin_meters", [0, 0, 0])

        print(f"    [SERVIDOR (Física & Bounds)]")
        print(f"       * Dimensão Real : {dims[0]:.1f}m x {dims[1]:.1f}m ({cells[0]:.1f}m por célula)")
        print(f"       * Origem Mundo  : X={origin[0]:.1f}m, Z={origin[2]:.1f}m")
        print(f"       * Altitude      : Mín={alt.get('min')}m | Máx={alt.get('max')}m | Desnível={alt.get('delta')}m")

    if hf_path.is_file():
        hf_kb = hf_path.stat().st_size / 1024.0
        print(f"       * heightfield.bin: {hf_kb:.1f} KB (Float32 Linear Buffer)")

    # 2. Artefatos do Cliente
    glb_path = client_dir / f"{chunk_name}_visual.glb"
    recipe_path = client_dir / "terrain_recipe.json"
    hm_path = client_dir / "heightmap_16bit.png"

    print(f"    [CLIENTE (Godot 4.7 Rendering)]")
    if glb_path.is_file():
        glb_mb = glb_path.stat().st_size / (1024.0 * 1024.0)
        print(f"       * Malha 3D GLB  : {glb_path.name} ({glb_mb:.2f} MB)")
    if hm_path.is_file():
        print(f"       * Heightmap PNG : {hm_path.name} (16-bit uint16)")

    # 3. Splatmaps e Texturas
    splatmaps = list(client_dir.glob("splatmap_*.png"))
    textures = list(textures_dir.glob("*.png")) if textures_dir.is_dir() else []
    print(f"       * Splatmaps RGBA: {len(splatmaps)} arquivo(s) ({', '.join(s.name for s in splatmaps)})")
    print(f"       * Texturas Solo : {len(textures)} textura(s) difusa(s) extraída(s)")

    if recipe_path.is_file():
        with open(recipe_path, "r", encoding="utf-8") as f:
            recipe = json.load(f)
        layers_count = len(recipe.get("layers", []))
        print(f"       * Receita Shader: {recipe_path.name} ({layers_count} camadas configuradas)")


def test_cluster_continuity(maps_dir: Path, chunks: list) -> None:
    print("\n" + "=" * 80)
    print(" [*] TESTE DE CONTINUIDADE DE BORDAS ENTRE CHUNKS (2-PASS SEAMLESS)")
    print("=" * 80)

    heightfields = {}
    for c in chunks:
        hf_file = maps_dir / c / "server" / "heightfield.bin"
        if hf_file.is_file():
            heightfields[c] = np.fromfile(hf_file, dtype="<f4").reshape((256, 256))

    if len(heightfields) < 2:
        print(" [!] Menos de 2 chunks compilados disponíveis para teste de fronteira.")
        return

    # 1. Teste 16_24 (Norte) x 16_25 (Sul) se ambos existirem
    if "16_24" in heightfields and "16_25" in heightfields:
        diff_ns = np.abs(heightfields["16_24"][255, :] - heightfields["16_25"][0, :])
        max_diff_ns = float(np.max(diff_ns))
        status_ns = "[PERFEITO (0.0000m)]" if max_diff_ns < 0.0001 else f"[DESVIO: {max_diff_ns:.4f}m]"
        print(f" -> Junção Norte/Sul  (16_24 Topo x 16_25 Base) : {status_ns} (Erro máx: {max_diff_ns:.6f}m)")

    # 2. Teste 17_24 (Norte) x 17_25 (Sul) se ambos existirem
    if "17_24" in heightfields and "17_25" in heightfields:
        diff_ns2 = np.abs(heightfields["17_24"][255, :] - heightfields["17_25"][0, :])
        max_diff_ns2 = float(np.max(diff_ns2))
        status_ns2 = "[PERFEITO (0.0000m)]" if max_diff_ns2 < 0.0001 else f"[DESVIO: {max_diff_ns2:.4f}m]"
        print(f" -> Junção Norte/Sul  (17_24 Topo x 17_25 Base) : {status_ns2} (Erro máx: {max_diff_ns2:.6f}m)")

    # 3. Teste 16_24 (Oeste) x 17_24 (Leste) se ambos existirem
    if "16_24" in heightfields and "17_24" in heightfields:
        diff_ew = np.abs(heightfields["16_24"][:, 255] - heightfields["17_24"][:, 0])
        max_diff_ew = float(np.max(diff_ew))
        status_ew = "[PERFEITO (0.0000m)]" if max_diff_ew < 0.0001 else f"[DESVIO: {max_diff_ew:.4f}m]"
        print(f" -> Junção Oeste/Leste (16_24 Dir  x 17_24 Esq) : {status_ew} (Erro máx: {max_diff_ew:.6f}m)")

    # 4. Teste 16_25 (Oeste) x 17_25 (Leste) se ambos existirem
    if "16_25" in heightfields and "17_25" in heightfields:
        diff_ew2 = np.abs(heightfields["16_25"][:, 255] - heightfields["17_25"][:, 0])
        max_diff_ew2 = float(np.max(diff_ew2))
        status_ew2 = "[PERFEITO (0.0000m)]" if max_diff_ew2 < 0.0001 else f"[DESVIO: {max_diff_ew2:.4f}m]"
        print(f" -> Junção Oeste/Leste (16_25 Dir  x 17_25 Esq) : {status_ew2} (Erro máx: {max_diff_ew2:.6f}m)")


def main():
    parser = argparse.ArgumentParser(
        description="Inspetor e Validador de Terreno (Godotage II / Etapa 1.2)"
    )
    parser.add_argument(
        "--chunk",
        default="16_24",
        help="Chunk específico para inspecionar (padrão: 16_24)",
    )
    parser.add_argument(
        "--cluster",
        nargs="+",
        default=["16_24", "16_25", "17_24", "17_25"],
        help="Lista de chunks para validação contínua (padrão: 16_24 16_25 17_24 17_25)",
    )
    parser.add_argument(
        "--open-folder",
        action="store_true",
        help="Abre a pasta do chunk no Windows Explorer",
    )

    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    maps_dir = project_root / "assets" / "maps"

    print("=" * 80)
    print(" [*] GODOTAGE II — FERRAMENTA DE INSPEÇÃO DE TERRENO (ETAPA 1.2)")
    print("=" * 80)

    # 1. Inspeciona o chunk alvo
    inspect_single_chunk(maps_dir, args.chunk)

    # 2. Testa a continuidade de bordas do cluster
    test_cluster_continuity(maps_dir, args.cluster)

    print("\n" + "=" * 80)
    print(" [*] DICA: Para abrir a malha 3D (.glb) no Visualizador 3D do Windows:")
    print(f"     explorer assets\\maps\\{args.chunk}\\client")
    print("=" * 80 + "\n")

    if args.open_folder:
        target_dir = maps_dir / args.chunk / "client"
        if target_dir.is_dir():
            os.startfile(str(target_dir))


if __name__ == "__main__":
    main()
