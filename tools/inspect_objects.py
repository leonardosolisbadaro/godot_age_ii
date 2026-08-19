#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/inspect_objects.py — Utilitário de Inspeção de StaticMeshes e Atores (Etapa 1.3)

Inspeciona e valida as malhas 3D e instâncias de atores extraídos:
- Total de atores instanciados e distribuição por tipo de malha
- Modelos 3D (.glb) gerados em assets/models/
- Coordenadas de mundo, rotações e escalas métricas

Uso:
    python tools/inspect_objects.py
    python tools/inspect_objects.py --chunk 16_24
    python tools/inspect_objects.py --open-folder
"""

import argparse
from collections import Counter
import json
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


def main():
    parser = argparse.ArgumentParser(
        description="Inspetor de StaticMeshes e Atores (Godotage II / Etapa 1.3)"
    )
    parser.add_argument(
        "--chunk",
        default="16_24",
        help="Chunk específico para inspecionar (padrão: 16_24)",
    )
    parser.add_argument(
        "--open-folder",
        action="store_true",
        help="Abre a pasta de modelos no Windows Explorer",
    )

    args = parser.parse_args()

    project_root = Path(__file__).resolve().parent.parent
    maps_dir = project_root / "assets" / "maps"
    models_dir = project_root / "assets" / "models"

    print("=" * 80)
    print(" [*] GODOTAGE II — INSPEÇÃO DE STATICMESHES E ATORES (ETAPA 1.3)")
    print("=" * 80)

    # 1. Inspeciona chunk_static_actors.json
    actors_json = maps_dir / args.chunk / "client" / "chunk_static_actors.json"
    if actors_json.is_file():
        with open(actors_json, "r", encoding="utf-8") as f:
            data = json.load(f)

        total_actors = data.get("total_actors", 0)
        unique_meshes = data.get("unique_meshes_count", 0)
        actors = data.get("actors", [])

        print(f"\n[+] ATORES NO MAPA: Chunk {args.chunk}")
        print(f"    -> Total de StaticMeshActors : {total_actors}")
        print(f"    -> Tipos de Malhas Únicas   : {unique_meshes}")

        # Contagem por tipo de malha
        counts = Counter()
        for a in actors:
            m = a.get("mesh_ref", {})
            if isinstance(m, dict):
                counts[f"{m.get('package')}.{m.get('object_name')}"] += 1

        print("\n    [TOP 8 MALHAS MAIS FREQUENTES NO MAPA]")
        for m_name, c in counts.most_common(8):
            print(f"       * {c:>3}x  {m_name}")

        # Exemplo de Ator
        if actors:
            sample = actors[0]
            t = sample.get("transform", {})
            print(f"\n    [EXEMPLO DE INSTÂNCIA: {sample.get('actor_name')}]")
            print(f"       * Malha Ref   : {sample.get('mesh_ref', {}).get('full_path')}")
            print(f"       * Posição (m) : X={t.get('position_meters', [0])[0]:.2f}, Y={t.get('position_meters', [0,0])[1]:.2f}, Z={t.get('position_meters', [0,0,0])[2]:.2f}")
            print(f"       * Rotação Rad : {t.get('rotation_euler_rad')}")
            print(f"       * Escala 3D   : {t.get('scale')}")
    else:
        print(f"\n[AVISO] Arquivo {actors_json.name} não encontrado. Execute 'python tools/build_objects.py {args.chunk}' primeiro.")

    # 2. Inspeciona Modelos GLB Gerados
    glbs = list(models_dir.glob("**/*.glb"))
    print(f"\n[+] BIBLIOTECA DE MODELOS 3D (.GLB)")
    print(f"    -> Total de Modelos Extraídos : {len(glbs)} arquivo(s)")
    for g in sorted(glbs)[:8]:
        size_kb = g.stat().st_size / 1024.0
        rel_path = g.relative_to(models_dir)
        print(f"       * {str(rel_path):<35} ({size_kb:>6.1f} KB)")

    print("\n" + "=" * 80)
    print(" [*] DICA: Para abrir a pasta de modelos 3D (.glb) no Windows Explorer:")
    print(f"     explorer assets\\models")
    print("=" * 80 + "\n")

    if args.open_folder and models_dir.is_dir():
        os.startfile(str(models_dir))


if __name__ == "__main__":
    main()
