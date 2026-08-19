#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/build_terrain.py — Compilador CLI de Terreno do Lineage II para Godotage II

Extrai, compila e solda chunks de terreno (2-Pass Seamless Alignment) gerando
os artefatos otimizados para Cliente (Godot 4.7) e Servidor (QuanticNet).

Uso:
    python tools/build_terrain.py 16_24
    python tools/build_terrain.py 16_24 16_25 17_24 17_25
    python tools/build_terrain.py 16_24 --step 2
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

from tools.l2_extractor import (
    L2Environment,
    compile_cluster,
    UU_TO_METERS_DEFAULT,
)


def main():
    parser = argparse.ArgumentParser(
        description="Compilador de Terreno Lineage II -> Godotage II (Godot 4.7)"
    )
    parser.add_argument(
        "maps",
        nargs="+",
        help="Nomes ou caminhos dos chunks .unr (ex: 16_24 16_25 17_24 17_25)",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        default=None,
        help="Diretório de saída dos assets (padrão: assets/maps)",
    )
    parser.add_argument(
        "--l2-root",
        default=None,
        help="Caminho raiz de instalação do Lineage II",
    )
    parser.add_argument(
        "--step",
        type=int,
        default=1,
        help="Downsampling da malha 3D (1 = 100%% resolução total 256x256, 2 = 128x128)",
    )
    parser.add_argument(
        "--no-splat",
        action="store_true",
        help="Desativa o empacotamento em Splatmaps RGBA",
    )
    parser.add_argument(
        "--unit-scale",
        type=float,
        default=UU_TO_METERS_DEFAULT,
        help="Fator de conversão de Unreal Units para Metros (padrão: 0.08)",
    )
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help="Força a recompilação e sobrescrita de assets existentes",
    )

    args = parser.parse_args()

    env = L2Environment(l2_root=args.l2_root)
    resolved_inputs = []

    for raw_inp in args.maps:
        inp_path = Path(raw_inp)
        if inp_path.is_file():
            resolved_inputs.append(inp_path)
        else:
            clean_name = inp_path.stem.lower()
            if clean_name in env.available_unr:
                resolved_inputs.append(env.available_unr[clean_name])
            else:
                print(f"[AVISO] Mapa .unr não encontrado para: {raw_inp}")

    if not resolved_inputs:
        sys.exit("[ERRO] Nenhum arquivo .unr válido encontrado para compilação.")

    if args.output_dir:
        out_dir = Path(args.output_dir)
    else:
        out_dir = Path(__file__).resolve().parent.parent / "assets" / "maps"

    out_dir.mkdir(parents=True, exist_ok=True)

    results = compile_cluster(
        input_files=resolved_inputs,
        output_dir=out_dir,
        l2_root=Path(args.l2_root) if args.l2_root else None,
        step=args.step,
        pack_splatmaps=not args.no_splat,
        unit_scale=args.unit_scale,
    )

    print("\n[+] Resumo dos Chunks Compilados:")
    for c_name, data in results.items():
        print(f"    -> Chunk {c_name:<8}: Altitude [{data['h_min']:.1f}m a {data['h_max']:.1f}m] | Desnível: {data['h_delta']:.1f}m")
        print(f"       Servidor : {len(data['server_files'])} arquivos gerados")
        print(f"       Cliente  : {len(data['client_files'])} arquivos gerados")


if __name__ == "__main__":
    main()
