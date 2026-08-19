#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/inspect_l2.py — Utilitário Visual e Interativo de Inspeção do Lineage II

Permite inspecionar pacotes .unr, .utx e .usx e extrair texturas de teste diretamente
para uma pasta sem necessidade de comandos complexos no PowerShell.

Uso:
    python tools/inspect_l2.py
    python tools/inspect_l2.py --map 16_24
    python tools/inspect_l2.py --extract-textures t_16_24 --limit 10
"""

import argparse
import os
from pathlib import Path
import sys

# Força UTF-8 no stdout/stderr no Windows
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Adiciona a raiz do projeto ao path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from tools.l2_extractor import L2Environment, UnrealPackageReader


def main():
    parser = argparse.ArgumentParser(description="Inspetor e Extrator de Teste Lineage II")
    parser.add_argument("--map", default="16_24", help="Nome do mapa para inspecionar (padrão: 16_24)")
    parser.add_argument("--extract-textures", default="t_16_24", help="Nome do pacote .utx para extrair amostras PNG (padrão: t_16_24)")
    parser.add_argument("--limit", type=int, default=5, help="Número de texturas para extrair (padrão: 5)")
    parser.add_argument("--out-dir", default="test_output_textures", help="Pasta de saída das texturas (padrão: test_output_textures)")
    args = parser.parse_args()

    print("=" * 80)
    print(" [*] GODOTAGE II — FERRAMENTA DE INSPEÇÃO E TESTE MANUAL")
    print("=" * 80)

    env = L2Environment()
    print(f"\n[+] 1. AMBIENTE LINEAGE II")
    print(f"    -> Pasta Raiz L2   : {env.l2_root}")
    print(f"    -> Mapas .UNR      : {len(env.available_unr)} encontrados")
    print(f"    -> Texturas .UTX   : {len(env.available_utx)} encontrados")
    print(f"    -> Malhas .USX     : {len(env.available_usx)} encontrados")

    # 1. Inspeção do Mapa
    map_name = args.map.lower().replace(".unr", "")
    map_path = env.available_unr.get(map_name)
    if map_path:
        print(f"\n[+] 2. INSPEÇÃO DO MAPA: {map_path.name}")
        reader = UnrealPackageReader(map_path)
        print(f"    -> Versão do Pacote: {reader.file_version} (Tag: 0x{reader.tag:08X})")
        print(f"    -> Total de Nomes  : {len(reader.names)}")
        print(f"    -> Importações     : {len(reader.imports)}")
        print(f"    -> Exportações     : {len(reader.exports)}")

        # TerrainInfo
        terrains = [e for e in reader.exports if e["class_name"] == "TerrainInfo"]
        print(f"    -> TerrainInfo     : {len(terrains)} encontrado(s)")
        if terrains:
            t = terrains[0]
            p_start = reader.find_properties_start(t["offset"], t["size"])
            props = reader.read_properties(p_start, t["size"] - (p_start - t["offset"]))
            print(f"       * Nome          : {t['object_name']}")
            print(f"       * Escala        : {props.get('TerrainScale')}")
            print(f"       * Mapa Altura   : {props.get('TerrainMap')}")
            layers = props.get("Layers", {})
            layers_count = len(layers) if isinstance(layers, dict) else len(layers)
            print(f"       * Camadas Solo  : {layers_count} camada(s)")

        # StaticMeshActors
        actors = [e for e in reader.exports if e["class_name"] == "StaticMeshActor"]
        print(f"    -> StaticMeshActors: {len(actors)} objetos no mapa")
        if actors:
            first = actors[0]
            p_start = reader.find_properties_start(first["offset"], first["size"])
            p = reader.read_properties(p_start, first["size"] - (p_start - first["offset"]))
            mesh_ref = p.get("StaticMesh")
            mesh_name = mesh_ref.get("full_path") if isinstance(mesh_ref, dict) else str(mesh_ref)
            print(f"       * Exemplo       : {first['object_name']} -> Mesh={mesh_name}")
            print(f"       * Posição Mundo : {p.get('Location')}")
            print(f"       * Rotação UE2   : {p.get('Rotation')}")

    # 2. Extração Visual de Texturas
    tex_pkg_name = args.extract_textures.lower().replace(".utx", "")
    pkg = env.get_package(tex_pkg_name)
    if pkg:
        out_dir = Path(args.out_dir)
        out_dir.mkdir(parents=True, exist_ok=True)
        print(f"\n[+] 3. EXTRAÇÃO DE TEXTURAS DE AMOSTRA: {pkg.filepath.name}")
        print(f"    -> Destino         : {out_dir.resolve()}")

        saved = 0
        for exp in pkg.exports:
            if exp["class_name"] in ("Texture", "Shader", "Material"):
                img = pkg.extract_image_by_export_name(exp["object_name"])
                if img:
                    file_path = out_dir / f"{exp['object_name']}.png"
                    img.save(file_path, format="PNG")
                    print(f"       [+] Extraído: {file_path.name:<25} ({img.size[0]}x{img.size[1]}, Modo={img.mode})")
                    saved += 1
                    if saved >= args.limit:
                        break

        print(f"\n[OK] {saved} textura(s) extraída(s) com sucesso em: {out_dir.resolve()}")

    print("\n" + "=" * 80)
    print(" [*] Inspeção concluída com sucesso!")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    main()
