#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/build_terrain.py — Compilador CLI de Terreno do Lineage II para Godotage II

@description
Extrai, compila e solda chunks de terreno (2-Pass Seamless Alignment) gerando
os artefatos otimizados para Cliente (Godot 4.7) e Servidor (QuanticNet).
Inclui validação estrita de pré-requisitos antes da execução.

@created 2026-08-18
@updated 2026-08-20
@author Leonardo S. Badaró
"""

import argparse
import os
from pathlib import Path
import sys
import time

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
    UU_TO_METERS_CANONICAL,
    compile_cluster,
    validate_pipeline_environment,
)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "GODOTAGE II — Compilador de Terreno Lineage II -> Godotage II (Godot 4.7)\n\n"
            "Extrai a geometria de terreno (G16), gera normais de superfície em alta resolução,\n"
            "empacota Splatmaps RGBA e executa soldagem contínua de bordas entre chunks vizinhos."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Exemplos de uso:\n"
            "  python tools/build_terrain.py 16_24\n"
            "  python tools/build_terrain.py 16_24 16_25 17_24 17_25\n"
            "  python tools/build_terrain.py 16_24 --step 2 --no-splat\n"
            "  python tools/build_terrain.py 16_24 -o ./assets/maps --force\n"
        ),
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
        help="Diretório de saída dos assets de terreno (padrão: assets/maps)",
    )
    parser.add_argument(
        "--l2-root",
        default=None,
        help="Caminho raiz personalizado de instalação do Lineage II (padrão: Lineage II/ na raiz)",
    )
    parser.add_argument(
        "--step",
        type=int,
        default=1,
        help="Downsampling da malha 3D (1 = 100%% resolução 256x256, 2 = 128x128)",
    )
    parser.add_argument(
        "--no-splat",
        action="store_true",
        help="Desativa o empacotamento em Splatmaps RGBA",
    )
    parser.add_argument(
        "--unit-scale",
        type=float,
        default=UU_TO_METERS_CANONICAL,
        help="Fator de conversão de Unreal Units para Metros (padrão: 0.08)",
    )
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help="Força a recompilação e sobrescrita de assets existentes",
    )

    args = parser.parse_args()

    # Pre-flight Check
    config = PipelineConfig(
        l2_root_dir=Path(args.l2_root) if args.l2_root else None,
        maps_output_dir=Path(args.output_dir) if args.output_dir else None,
        unit_scale=args.unit_scale,
        force_rebuild=args.force,
    )
    validate_pipeline_environment(config, require_l2_root=True, require_umodel=False, abort_on_error=True)

    env = L2Environment(config=config, l2_root=config.l2_root_dir)
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
                print(f"[AVISO] Mapa .unr não encontrado para: {raw_inp}", file=sys.stderr)

    if not resolved_inputs:
        sys.exit("[ERRO] Nenhum arquivo .unr válido encontrado para compilação.")

    out_dir = config.maps_output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    start_time = time.time()
    results = compile_cluster(
        input_files=resolved_inputs,
        output_dir=out_dir,
        l2_root=config.l2_root_dir,
        step=args.step,
        pack_splatmaps=not args.no_splat,
        unit_scale=args.unit_scale,
        config=config,
    )

    elapsed = time.time() - start_time
    print("\n[+] Resumo dos Chunks Compilados:")
    for c_name, data in results.items():
        print(f"    -> Chunk {c_name:<8}: Altitude [{data['h_min']:.1f}m a {data['h_max']:.1f}m] | Desnível: {data['h_delta']:.1f}m")
        print(f"       Servidor : {len(data['server_files'])} arquivos gerados")
        print(f"       Cliente  : {len(data['client_files'])} arquivos gerados")
    print(f"\n[OK] Compilação de terreno finalizada em {elapsed:.2f}s!")


if __name__ == "__main__":
    main()
