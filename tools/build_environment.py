#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/build_environment.py — Compilador de Atmosfera, Materiais e Iluminação (Etapa 1.4)

@description
Extrai e gera:
1. environment_recipe.json (Cliente / Godot 4):
   - Direção e cor da luz solar (DirectionalLight3D)
   - Distância e cores da névoa volumétrica (DistanceFog)
   - Cor e energia da luz ambiente (Ambient Lighting)
   - Posição da câmera do céu (SkyZoneInfo) e Lua (NMoon)
   - Luzes pontuais locais (Tochas, Postes, Fontes)
2. water_volumes.json (Servidor / Física):
   - Níveis de altura da superfície d'água em metros
   - Limites métricos e atrito de fluido
3. Texturas e Materiais (assets/textures/ e material_recipes.json):
   - Resolução da árvore de materiais (Shader, FinalBlend, TexPanner)
   - Extração automática de PNGs e geração de receitas StandardMaterial3D do Godot 4
Inclui validação rigorosa de pré-requisitos antes da execução.

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
from typing import Any, Dict, List, Optional

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
    MaterialTreeResolver,
    PipelineConfig,
    UU_TO_METERS_CANONICAL,
    UnrealPackageReader,
    extract_map_environment,
    validate_pipeline_environment,
)


def process_map_environment(
    map_name_or_path: str,
    env: L2Environment,
    maps_dir: Path,
    textures_dir: Path,
    unit_scale: float = UU_TO_METERS_CANONICAL,
    config: Optional[PipelineConfig] = None,
) -> Dict[str, Any]:
    """Processa toda a atmosfera, iluminação, água e materiais de um mapa .unr."""
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

    map_pkg = UnrealPackageReader(map_path)
    print(f"\n[+] Chunk {clean_name}: Extraindo parâmetros ambientais e iluminação...")
    env_data = extract_map_environment(map_pkg, unit_scale, config=config)

    chunk_root = maps_dir / clean_name
    chunk_client_dir = chunk_root / "client"
    chunk_server_dir = chunk_root / "server"
    chunk_root.mkdir(parents=True, exist_ok=True)
    chunk_client_dir.mkdir(parents=True, exist_ok=True)
    chunk_server_dir.mkdir(parents=True, exist_ok=True)

    # 1. Salva environment_recipe.json para o Cliente (Godot WorldEnvironment / DirectionalLight3D)
    client_env_file = chunk_client_dir / "environment_recipe.json"
    client_recipe = {
        "chunk_name": clean_name,
        "sunlight": env_data["sunlight"],
        "moonlight": env_data["moonlight"],
        "ambient_lighting": env_data["ambient_lighting"],
        "distance_fog": env_data["distance_fog"],
        "sky_info": env_data["sky_info"],
        "point_lights": env_data["point_lights"],
        "water_volumes_count": len(env_data["water_volumes"]),
    }
    with open(client_env_file, "w", encoding="utf-8") as f:
        json.dump(client_recipe, f, indent=4)
    print(f"    -> Salvo receita ambiental do cliente em: {client_env_file.name}")

    # 2. Salva water_volumes.json unificado na raiz do mapa e no server
    root_water_file = chunk_root / "water_volumes.json"
    server_water_file = chunk_server_dir / "water_volumes.json"
    water_data = {
        "chunk_name": clean_name,
        "water_volumes": env_data["water_volumes"],
    }
    with open(root_water_file, "w", encoding="utf-8") as f:
        json.dump(water_data, f, indent=4)
    with open(server_water_file, "w", encoding="utf-8") as f:
        json.dump(water_data, f, indent=4)
    print(f"    -> Salvo metadados de corpos d'água em: {root_water_file.name}")

    # 3. Resolve materiais referenciados pelos atores do mapa
    resolver = MaterialTreeResolver(env, textures_out_dir=textures_dir, config=config)
    actors_json = chunk_root / "chunk_static_actors.json"
    if not actors_json.is_file():
        actors_json = chunk_client_dir / "chunk_static_actors.json"
    resolved_materials = {}

    if actors_json.is_file():
        with open(actors_json, "r", encoding="utf-8") as f:
            actors_meta = json.load(f)

        for a in actors_meta.get("actors", []):
            m_ref = a.get("mesh_ref")
            if isinstance(m_ref, dict):
                pkg_name = m_ref.get("package")
                if pkg_name:
                    t_name = pkg_name[:-2] + "_t" if pkg_name.lower().endswith("_s") else pkg_name
                    target_pkg = t_name if env.get_package(t_name) else pkg_name

                    tex_pkg = env.get_package(target_pkg)
                    if tex_pkg:
                        for exp in tex_pkg.exports:
                            if exp["class_name"] in ("Texture", "Shader", "FinalBlend"):
                                m_info = resolver.resolve_material(target_pkg, exp["object_name"])
                                resolved_materials[f"{target_pkg}.{exp['object_name']}"] = m_info

    # Salva manifesto de materiais do chunk
    mat_recipe_file = chunk_client_dir / "material_recipes.json"
    with open(mat_recipe_file, "w", encoding="utf-8") as f:
        json.dump(resolved_materials, f, indent=4)
    print(f"    -> {len(resolved_materials)} material(is) resolvido(s) em: {mat_recipe_file.name}")

    return env_data


def main():
    parser = argparse.ArgumentParser(
        description=(
            "GODOTAGE II — Compilador de Atmosfera, Iluminação e Materiais (Lineage II -> Godotage II)\n\n"
            "Gera a receita de iluminação solar, névoa, luzes pontuais e volumes de água para o Godot 4.7,\n"
            "além de resolver a árvore de materiais e shaders para o manifesto do chunk."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Exemplos de uso:\n"
            "  python tools/build_environment.py 16_24\n"
            "  python tools/build_environment.py 16_24 16_25\n"
            "  python tools/build_environment.py --extract-materials speaking_tree_t\n"
        ),
    )
    parser.add_argument(
        "maps",
        nargs="*",
        help="Nomes dos mapas .unr (ex: 16_24 16_25)",
    )
    parser.add_argument(
        "--extract-materials",
        default=None,
        help="Extrai e resolve todos os materiais de um pacote .utx (ex: speaking_tree_t)",
    )
    parser.add_argument(
        "--l2-root",
        default=None,
        help="Caminho raiz personalizado de instalação do Lineage II (padrão: Lineage II/ na raiz)",
    )

    args = parser.parse_args()

    config = PipelineConfig(
        l2_root_dir=Path(args.l2_root) if args.l2_root else None,
    )
    validate_pipeline_environment(config, require_l2_root=True, require_umodel=False, abort_on_error=True)

    maps_dir = config.maps_output_dir
    textures_dir = config.textures_output_dir
    env = L2Environment(config=config, l2_root=config.l2_root_dir)

    print("=" * 80)
    print(" [*] GODOTAGE II — COMPILADOR DE ATMOSFERA E MATERIAIS (ETAPA 1.4)")
    print("=" * 80)

    if args.extract_materials:
        pkg_name = args.extract_materials.lower()
        if pkg_name.endswith(".utx"):
            pkg_name = pkg_name[:-4]
        print(f"\n[+] Resolvendo e extraindo materiais do pacote: {pkg_name}.utx...")
        pkg = env.get_package(pkg_name)
        if not pkg:
            print(f"[ERRO] Pacote {pkg_name} não encontrado.", file=sys.stderr)
            return
        resolver = MaterialTreeResolver(env, textures_out_dir=textures_dir, config=config)
        count = 0
        for exp in pkg.exports:
            if exp["class_name"] in ("Texture", "Shader", "FinalBlend", "TexPanner"):
                resolver.resolve_material(pkg_name, exp["object_name"])
                count += 1
        print(f"[OK] {count} materiais resolvidos e texturas salvas em: {textures_dir / pkg_name}")
        return

    if not args.maps:
        args.maps = ["16_24"]

    start_time = time.time()
    for m in args.maps:
        process_map_environment(m, env, maps_dir, textures_dir, config=config)

    elapsed = time.time() - start_time
    print("\n" + "=" * 80)
    print(f" [*] Compilação de Atmosfera e Materiais Concluída com Sucesso em {elapsed:.2f}s!")
    print("=" * 80 + "\n")


if __name__ == "__main__":
    main()
