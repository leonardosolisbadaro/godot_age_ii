#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/build_map.py — Orquestrador Unificado de Compilação de Mapas (All-in-One por Chunk)

@description
Compila um ou mais chunks de mapa do Lineage II de ponta a ponta em um único comando:
1. Pre-flight Health Check: Validação estrita de diretórios (Lineage II/), binários (UModel) e dependências.
2. Relevo & Altitudes em Lote (2-Pass Seamless Alignment unificando todos os chunks e bordas).
3. Atores Estáticos & Malhas 3D (Lê .unr, converte .glb 8x multi-materiais).
4. Texturas de Objetos (Descobre pacotes .utx necessários e extrai via UModel CLI na raiz).
5. Ambiente & Atmosfera (Luz solar, cores, névoa, água).

@created 2026-08-18
@updated 2026-08-20
@author Leonardo S. Badaró
"""

import argparse
import json
import os
from pathlib import Path
import sys
import time
from typing import List, Optional, Set

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
    export_package_meshes,
    export_package_textures,
    find_umodel_executable,
    validate_pipeline_environment,
)
from tools.build_environment import process_map_environment
from tools.build_objects import process_chunk_objects


# ==============================================================================
# CONSTANTES SEMÂNTICAS DO ORQUESTRADOR DE MAPA
# ==============================================================================

## @const DEFAULT_SEED_TEXTURE_PACKAGES (Set[str])
## O que: Lista de pacotes de textura fundamentais frequentemente referenciados em Talking Island e Vilas.
## Porque: Permite aquecer o cache de texturas comuns previamente para acelerar a compilação.
DEFAULT_SEED_TEXTURE_PACKAGES: Set[str] = {
    "si_v_t", "speaking1f_t", "speaking_tree_t", "field_deco_t",
    "field_deco_artifact_t", "speakingfighter_t", "interior_b_ch_t",
    "statues_t", "sp_lighthouse", "entrance_t", "deco01",
    "gludio_port_t", "interior_b_t", "speaking_magic_t",
    "v_obj_t", "door_set_t", "fx_e_t", "gl_cv_t", "talking_village_t"
}

## @const MIN_EXTRACTED_TEXTURES_THRESHOLD (int)
## O que: Quantidade mínima de texturas PNG esperadas em um pacote já sincronizado (3 arquivos).
## Porque: Evita re-extração desnecessária caso o diretório já contenha as texturas convertidas.
MIN_EXTRACTED_TEXTURES_THRESHOLD: int = 3


def auto_sync_textures_for_actors(
    actors: List[dict],
    env: L2Environment,
    textures_dir: Path,
    umodel_root: Path,
    l2_root: Path,
    config: Optional[PipelineConfig] = None,
) -> int:
    """
    Identifica todos os pacotes de texturas referenciados pelas StaticMeshes do chunk
    e extrai automaticamente via UModel CLI qualquer pacote que ainda não esteja presente.
    """
    needed_tex_pkgs: Set[str] = set(DEFAULT_SEED_TEXTURE_PACKAGES)

    # Varre os modelos dos atores
    for a in actors:
        m_ref = a.get("mesh_ref", {})
        if isinstance(m_ref, dict):
            pkg = m_ref.get("package", "")
            if pkg:
                tex_pkg = pkg.lower()
                if tex_pkg.endswith("_s"):
                    tex_pkg = tex_pkg[:-2] + "_t"
                needed_tex_pkgs.add(tex_pkg)

    extracted_count = 0
    umodel_exe = find_umodel_executable(config)

    for pkg_name in sorted(needed_tex_pkgs):
        pkg_dir = textures_dir / pkg_name
        pngs_present = list(pkg_dir.glob("*.png")) if pkg_dir.is_dir() else []
        if len(pngs_present) < MIN_EXTRACTED_TEXTURES_THRESHOLD:
            umodel_tex_dir = umodel_root / pkg_name / "Texture"
            if umodel_tex_dir.is_dir():
                pkg_dir.mkdir(parents=True, exist_ok=True)
                for png in umodel_tex_dir.glob("*.png"):
                    import shutil
                    shutil.copy2(png, pkg_dir / png.name)
                extracted_count += 1
            elif umodel_exe and l2_root:
                print(f"    -> [UModel CLI] Extraindo pacote de texturas: {pkg_name}...")
                if export_package_textures(pkg_name, l2_root, textures_dir, umodel_exe):
                    extracted_count += 1

    return extracted_count


def process_chunk_actors_and_env(
    chunk_name: str,
    env: L2Environment,
    maps_dir: Path,
    models_dir: Path,
    textures_dir: Path,
    umodel_root: Path,
    l2_root: Path,
    force: bool = False,
    config: Optional[PipelineConfig] = None,
) -> bool:
    """Processa atores, texturas e ambiente de um chunk."""
    print("\n" + "=" * 80)
    print(f" [*] PROCESSANDO OBJETOS & AMBIENTE: {chunk_name}")
    print("=" * 80)

    start_time = time.time()

    # 1. Extração de Atores e Malhas 3D (.glb 8x)
    print(f"\n--- [1/3] Extraindo StaticMeshActors & Modelos 3D ({chunk_name}) ---")
    actors_meta = process_chunk_objects(
        chunk_name,
        env,
        maps_dir,
        models_dir,
        unit_scale=UU_TO_METERS_CANONICAL,
        force=force,
        config=config,
    )

    # 2. Sincronização Automática de Texturas via UModel CLI
    print(f"\n--- [2/3] Verificando e Extraindo Texturas de Objetos ({chunk_name}) ---")
    actors = actors_meta.get("actors", [])
    synced_pkgs = auto_sync_textures_for_actors(
        actors, env, textures_dir, umodel_root, l2_root, config=config
    )
    print(f"    -> [+] {synced_pkgs} pacote(s) de texturas sincronizado(s) com sucesso.")

    # 3. Ambiente e Atmosfera
    print(f"\n--- [3/3] Gerando Receita de Atmosfera e Ambiente ({chunk_name}) ---")
    process_map_environment(chunk_name, env, maps_dir, textures_dir, config=config)

    elapsed = time.time() - start_time
    print(f"\n [OK] Objetos e ambiente de {chunk_name} finalizados em {elapsed:.2f}s!")
    return True


def main():
    parser = argparse.ArgumentParser(
        description=(
            "GODOTAGE II — Pipeline Unificado de Compilação de Mapas (All-in-One por Chunk)\n\n"
            "Compila chunks de mapa do Lineage II gerando malhas 3D (.glb), heightfields (.bin),\n"
            "splatmaps RGBA (1024x1024), instâncias de StaticMeshActors e receitas de atmosfera para Godot 4.7."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Exemplos de uso:\n"
            "  python tools/build_map.py 16_24\n"
            "  python tools/build_map.py 16_24 16_25\n"
            "  python tools/build_map.py 16_24 16_25 17_24 17_25 --force\n"
            "  python tools/build_map.py --all\n"
            "  python tools/build_map.py all\n"
            "  python tools/build_map.py --l2-root \"./Lineage II\"\n"
        ),
    )
    parser.add_argument(
        "maps",
        nargs="*",
        default=["16_24", "16_25", "17_24", "17_25"],
        help="Nomes dos chunks de mapa a compilar (use 'all' ou --all para compilar todo o mundo do jogo)",
    )
    parser.add_argument(
        "--all",
        "-a",
        action="store_true",
        help="Processa e compila todos os mapas .unr existentes na pasta do Lineage II",
    )
    parser.add_argument(
        "--l2-root",
        default=None,
        help="Caminho personalizado da pasta de dados RAW do Lineage II (padrão: Lineage II/ na raiz)",
    )
    parser.add_argument(
        "--force",
        "-f",
        action="store_true",
        help="Força a recompilação e sobrescrita de todos os artefatos existentes",
    )

    args = parser.parse_args()

    # 1. Configuração e Pre-flight Check
    config = PipelineConfig(
        l2_root_dir=Path(args.l2_root) if args.l2_root else None,
        force_rebuild=args.force,
    )

    validate_pipeline_environment(config, require_l2_root=True, require_umodel=False, abort_on_error=True)

    maps_dir = config.maps_output_dir
    models_dir = config.models_output_dir
    textures_dir = config.textures_output_dir
    umodel_root = config.umodel_export_dir

    env = L2Environment(config=config, l2_root=config.l2_root_dir)
    l2_root = env.l2_root

    # Se solicitado --all ou argumento "all", carrega todos os mapas disponíveis
    if args.all or (len(args.maps) == 1 and args.maps[0].lower() == "all"):
        target_map_names = sorted(list(env.available_unr.keys()))
    else:
        target_map_names = args.maps

    print("=" * 80)
    print(" [*] GODOTAGE II — PIPELINE UNIFICADO DE COMPILAÇÃO DE MAPAS")
    print("=" * 80)
    print(f" [*] Raiz do Lineage II : {l2_root}")
    print(f" [*] Executável UModel  : {find_umodel_executable(config)}")
    print(f" [*] Chunks Solicitados : {len(target_map_names)} mapa(s)")
    print(f" [*] Forçar Recompilação: {args.force}")

    # 2. Compilação de Relevo em Lote (2-Pass Seamless Alignment)
    valid_unrs = []
    for m in target_map_names:
        unr_p = env.available_unr.get(m.lower())
        if unr_p and unr_p.is_file():
            valid_unrs.append(unr_p)
        else:
            print(f"    [AVISO] Mapa {m}.unr não encontrado em {env.maps_dir}.", file=sys.stderr)

    if valid_unrs:
        print("\n" + "=" * 80)
        print(" [PASSO 1] Compilação Global de Terreno (2-Pass Seamless Stitcher)")
        print("=" * 80)
        compile_cluster(
            valid_unrs,
            maps_dir,
            l2_root=l2_root,
            step=1,
            pack_splatmaps=True,
            unit_scale=UU_TO_METERS_CANONICAL,
            config=config,
        )

    # 3. Atores, Texturas e Ambiente de Cada Chunk
    for m in target_map_names:
        process_chunk_actors_and_env(
            m, env, maps_dir, models_dir, textures_dir, umodel_root, l2_root, force=args.force, config=config
        )

    print("\n" + "=" * 80)
    print(" [*] TODOS OS MAPAS FORAM COMPILADOS COM SUCESSO!")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    main()
