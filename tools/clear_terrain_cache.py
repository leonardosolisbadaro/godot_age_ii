#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/clear_terrain_cache.py — Utilitário de Limpeza Seletiva de Cache de Shaders e Texturas

@description
Limpa os arquivos de cache de compilação de shaders (.godot/shader_cache) e arquivos de
importação de textura/splatmaps (.godot/imported) para forçar recarregamento limpo no Godot 4.7.

@created 2026-08-18
@updated 2026-08-20
@author Leonardo S. Badaró
"""

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Optional

# Força UTF-8 no stdout/stderr no Windows
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

PROJECT_ROOT = Path(__file__).resolve().parent.parent


def clear_terrain_cache(run_godot: bool = False, godot_exe_path: Optional[str] = None) -> None:
    """Remove arquivos de cache de shaders e imported de terreno."""
    project_root = PROJECT_ROOT
    shader_cache = project_root / ".godot" / "shader_cache"
    imported = project_root / ".godot" / "imported"

    print("=" * 70)
    print(" [*] GODOTAGE II — LIMPEZA SELETIVA DE CACHE DE TERRENO E SHADERS")
    print("=" * 70)

    if shader_cache.is_dir():
        shutil.rmtree(shader_cache, ignore_errors=True)
        print(" [+] Shader cache (.godot/shader_cache) removido.")
    else:
        print(" [.] Nenhum shader cache pendente.")

    if imported.is_dir():
        count = 0
        patterns = ["*splatmap*", "*layer_*", "*l2_terrain*", "*visual*"]
        for pattern in patterns:
            for f in imported.glob(pattern):
                try:
                    f.unlink(missing_ok=True)
                    count += 1
                except Exception:
                    pass
        print(f" [+] {count} arquivo(s) de textura/splatmap em cache removido(s).")

    print("=" * 70)
    print(" [OK] Cache limpo com sucesso!")
    print("=" * 70)

    if run_godot:
        godot_exe = Path(godot_exe_path) if godot_exe_path else None
        if not godot_exe or not godot_exe.is_file():
            # Tenta encontrar no PATH
            which_godot = shutil.which("godot") or shutil.which("godot_console")
            if which_godot:
                godot_exe = Path(which_godot)

        if godot_exe and godot_exe.is_file():
            print(f"\n[+] Iniciando o Godot 4.7 ({godot_exe.name})...")
            subprocess.run([str(godot_exe), "--path", str(project_root)])
        else:
            print("\n[AVISO] Executável do Godot não especificado ou não encontrado no PATH.", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(
        description=(
            "GODOTAGE II — Limpeza Seletiva de Cache de Terreno e Shaders\n\n"
            "Remove artefatos em cache de .godot/shader_cache e .godot/imported para forçar\n"
            "uma reimportação limpa de texturas e recompilação de shaders no Godot 4.7."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "Exemplos de uso:\n"
            "  python tools/clear_terrain_cache.py\n"
            "  python tools/clear_terrain_cache.py --run\n"
            "  python tools/clear_terrain_cache.py --run --godot-exe \"C:/Godot/godot.exe\"\n"
        ),
    )
    parser.add_argument(
        "--run",
        "-r",
        action="store_true",
        help="Inicia o Godot automaticamente após a limpeza de cache",
    )
    parser.add_argument(
        "--godot-exe",
        default=None,
        help="Caminho personalizado do executável Godot",
    )

    args = parser.parse_args()
    clear_terrain_cache(run_godot=args.run, godot_exe_path=args.godot_exe)


if __name__ == "__main__":
    main()
