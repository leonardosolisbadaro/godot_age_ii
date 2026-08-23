"""
Pipeline CLI para Compilação (Bake) da NavMesh Definitiva do Servidor.

Orquestra a execução do compilador Godot headless (src/infrastructure/bake_navmesh.gd)
para gerar arquivos binários otimizados de navegação 3D (assets/maps/<chunk>/server/navmesh.res).

Uso:
    python tools/bake_navmesh.py --chunk 17_25
    python tools/bake_navmesh.py --all
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

# Localização canônica do binário do Godot Engine no ambiente
DEFAULT_GODOT_PATH = Path(
    r"C:\Users\LEONARDO\Documents\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
)


def get_godot_executable() -> Path:
    env_path = os.environ.get("GODOT_BIN")
    if env_path and Path(env_path).is_file():
        return Path(env_path)
    if DEFAULT_GODOT_PATH.is_file():
        return DEFAULT_GODOT_PATH
    raise FileNotFoundError(
        f"Executável do Godot não encontrado em '{DEFAULT_GODOT_PATH}'. "
        f"Defina a variável de ambiente GODOT_BIN com o caminho correto."
    )


def run_navmesh_bake(chunk_name: str | None = None) -> int:
    godot_exe = get_godot_executable()
    cmd = [
        str(godot_exe),
        "--headless",
        "-s",
        "res://src/infrastructure/bake_navmesh.gd",
    ]

    if chunk_name:
        cmd.extend(["--", "--chunk", chunk_name])

    print(f"[BAKE NAVMESH CLI] Executando comando: {' '.join(cmd)}")
    result = subprocess.run(cmd)
    return result.returncode


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Compilador CLI de NavMesh Definitiva para Chunks do godot_age_ii",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "--chunk",
        "-c",
        type=str,
        default=None,
        help="Nome do chunk específico para compilar (ex: 17_25).",
    )
    parser.add_argument(
        "--all",
        "-a",
        action="store_true",
        help="Compilar a NavMesh de todos os chunks disponíveis em assets/maps.",
    )

    args = parser.parse_args()

    try:
        if args.chunk:
            code = run_navmesh_bake(args.chunk)
        else:
            code = run_navmesh_bake(None)
        sys.exit(code)
    except Exception as e:
        print(f"[ERRO CRÍTICO] {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
