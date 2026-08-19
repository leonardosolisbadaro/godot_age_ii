#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/inspect_environment.py — Ferramenta de Diagnóstico e Inspeção de Atmosfera (Etapa 1.4)

Exibe:
1. Parâmetros de iluminação solar (Vetor direcional, cor RGB, intensidade)
2. Parâmetros de névoa de distância (DistanceFog) e luz ambiente (ZoneInfo)
3. Volumes de água e níveis de altitude do mar
4. Contagem e resolução de materiais e texturas do mapa

Uso:
    python tools/inspect_environment.py
    python tools/inspect_environment.py 16_24
"""

import argparse
import json
import os
import sys
from pathlib import Path

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
    extract_map_environment,
)


def inspect_map_atmosphere(map_name: str, env: L2Environment):
    """Lê e exibe os parâmetros atmosféricos e ambientais do chunk."""
    map_pkg = env.get_package(map_name)
    if not map_pkg:
        print(f"[ERRO] Mapa {map_name} não encontrado.")
        return

    env_data = extract_map_environment(map_pkg)

    print("=" * 80)
    print(f" [*] GODOTAGE II — INSPEÇÃO DE ATMOSFERA E ILUMINAÇÃO (ETAPA 1.4)")
    print("=" * 80)

    print(f"\n[+] 1. ILUMINAÇÃO SOLAR & CÉU: Chunk {map_name}")
    sun = env_data.get("sunlight")
    if sun:
        print(f"    -> Nome do Ator      : {sun['name']}")
        print(f"    -> Tipo de Nó Godot  : {sun['type']}")
        print(f"    -> Vetor Direção 3D  : {sun['direction']}")
        print(f"    -> Cor Albedo (RGB)  : {sun['color_rgb']}")
        print(f"    -> Energia / Brilho  : {sun['energy']}")
        if "rotator_ue2" in sun:
            print(f"    -> Rotator UE2       : Pitch={sun['rotator_ue2'][0]}, Yaw={sun['rotator_ue2'][1]}")

    moon = env_data.get("moonlight")
    if moon:
        print(f"\n    [LUA / ATMOSFERA NOTURNA]")
        print(f"    -> Posição no Céu (m): {moon.get('position_m')}")
        print(f"    -> Cor Albedo (RGB)  : {moon.get('color_rgb')}")

    print(f"\n[+] 2. NÉVOA DE DISTÂNCIA & LUZ AMBIENTE (ZoneInfo)")
    fog = env_data.get("distance_fog")
    if fog:
        print(f"    -> Névoa Ativa       : {fog['enabled']}")
        print(f"    -> Cor da Névoa (RGB): {fog['color_rgb']}")
        print(f"    -> Início da Névoa   : {fog['begin_meters']:.1f} metros")
        print(f"    -> Fim da Névoa (Max): {fog['end_meters']:.1f} metros")

    amb = env_data.get("ambient_lighting")
    if amb:
        print(f"    -> Cor Ambiente (RGB): {amb['color_rgb']}")
        print(f"    -> Energia Ambiente  : {amb['energy']}")

    print(f"\n[+] 3. VOLUMES DE ÁGUA (WaterVolume)")
    waters = env_data.get("water_volumes", [])
    print(f"    -> Total de Superfícies de Água: {len(waters)}")
    for w in waters:
        print(f"       * {w['name']}: Altura do Plano Z = {w['water_plane_height_m']:.2f}m (Atrito: {w['fluid_friction']})")

    point_lights = env_data.get("point_lights", [])
    print(f"\n[+] 4. LUZES PONTUAIS LOCAIS (Tochas / Postes)")
    print(f"    -> Total de Luzes Pontuais: {len(point_lights)}")
    for l in point_lights[:3]:
        print(f"       * {l['name']}: Pos={l['position_m']}, Cor={l['color_rgb']}, Raio={l['radius_meters']}m")

    # Inspeciona receitas geradas no disco
    recipe_file = Path(f"assets/maps/{map_name}/client/environment_recipe.json")
    mat_file = Path(f"assets/maps/{map_name}/client/material_recipes.json")
    print(f"\n[+] 5. ARQUIVOS DE CONFIGURAÇÃO NO DISCO")
    if recipe_file.is_file():
        print(f"    -> [OK] Receita Ambiental : {recipe_file} ({recipe_file.stat().st_size/1024.0:.1f} KB)")
    else:
        print(f"    -> [!] Receita Ambiental pendente de compilação.")

    if mat_file.is_file():
        with open(mat_file, "r", encoding="utf-8") as f:
            mats = json.load(f)
        print(f"    -> [OK] Manifesto Materiais: {mat_file} ({len(mats)} materiais mapeados)")
    else:
        print(f"    -> [!] Manifesto de materiais pendente de compilação.")

    print("\n" + "=" * 80 + "\n")


def main():
    parser = argparse.ArgumentParser(description="Inspetor de Atmosfera e Iluminação (Godotage II)")
    parser.add_argument("map", nargs="?", default="16_24", help="Nome do mapa (padrão: 16_24)")
    args = parser.parse_args()

    env = L2Environment()
    inspect_map_atmosphere(args.map.lower(), env)


if __name__ == "__main__":
    main()
