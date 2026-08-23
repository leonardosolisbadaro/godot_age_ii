#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/bake_collisions.py — Utilitário CLI para Compilação e Bake de Colisões 3D no Godotage II

@description
Orquestrador CLI em Python para execução do pipeline de pré-compilação (bake) de colisões
estáticas do mundo. Utiliza estritamente o caminho explícito do executável do Godot 4.7
definido no projeto e dispara o SceneTree script canônico
(res://src/infrastructure/bake_collisions.gd) em modo headless.

Uso:
  python tools/bake_collisions.py
  python tools/bake_collisions.py --chunk 17_25
  python tools/bake_collisions.py --all
  python tools/bake_collisions.py --godot-exe "C:/Godot/godot.exe"

@created 2026-08-22
@updated 2026-08-22
@author Leonardo S. Badaró
"""

import argparse
import subprocess
import sys
from pathlib import Path
from typing import List, Optional

## @const DEFAULT_GODOT_EXE (Path)
## O que: Caminho canônico estrito e explícito do executável do Godot 4.7 no projeto.
## Porque: Evita heurísticas de busca e garante execução determinística do pipeline.
DEFAULT_GODOT_EXE: Path = Path(
	r"C:\Users\LEONARDO\Documents\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
)


def get_godot_executable(custom_path: Optional[str] = None) -> Path:
	"""Retorna o caminho explícito do executável do Godot 4.7."""
	if custom_path:
		return Path(custom_path).resolve()
	return DEFAULT_GODOT_EXE.resolve()


def run_bake_collisions(
	chunk_name: Optional[str] = None,
	godot_exe_path: Optional[str] = None,
	project_root: Optional[Path] = None,
) -> int:
	"""Executa o script de bake de colisões no Godot Headless."""
	if project_root is None:
		project_root = Path(__file__).resolve().parent.parent

	godot_exe = get_godot_executable(godot_exe_path)

	print("=" * 70)
	print(" [*] GODOTAGE II — PIPELINE DE BAKE DE COLISÕES 3D")
	print("=" * 70)
	print(f" [+] Raiz do Projeto: {project_root}")
	print(f" [+] Executável Godot: {godot_exe}")

	if not godot_exe.is_file():
		print(
			f"\n [ERRO] Executável do Godot não encontrado no caminho explícito:\n"
			f"        {godot_exe}\n"
			f"        Verifique a instalação ou especifique via --godot-exe.",
			file=sys.stderr,
		)
		return 1

	gdscript_target = "res://src/infrastructure/bake_collisions.gd"
	gdscript_local = project_root / "src" / "infrastructure" / "bake_collisions.gd"

	if not gdscript_local.is_file():
		print(f"\n [ERRO] Script GDScript não encontrado em: {gdscript_local}", file=sys.stderr)
		return 1

	cmd: List[str] = [
		str(godot_exe),
		"--headless",
		"--path",
		str(project_root),
		"-s",
		gdscript_target,
	]

	if chunk_name:
		cmd.extend(["--", "--chunk", chunk_name])
		print(f" [+] Alvo de Compilação: Chunk '{chunk_name}'")
	else:
		print(" [+] Alvo de Compilação: Todos os Chunks Disponíveis")

	print("\n [*] Iniciando execução do SceneTree script no Godot...\n")
	sys.stdout.flush()

	try:
		result = subprocess.run(cmd, cwd=str(project_root))
		if result.returncode == 0:
			print("\n" + "=" * 70)
			print(" [OK] Processo de Bake de Colisões finalizado com sucesso!")
			print("=" * 70)
			return 0
		else:
			print(f"\n [ERRO] O processo do Godot encerrou com código de erro {result.returncode}.", file=sys.stderr)
			return result.returncode
	except Exception as exc:
		print(f"\n [ERRO] Falha ao invocar o subprocesso do Godot: {exc}", file=sys.stderr)
		return 1


def main() -> None:
	parser = argparse.ArgumentParser(
		description=(
			"GODOTAGE II — Compilador e Gerador de Colisões 3D Estáticas\n\n"
			"Executa o script de infraestrutura no Godot 4.7 (Headless) para ler regras\n"
			"de colisão centralizadas e gerar recursos de colisão (.tres) por chunk."
		),
		formatter_class=argparse.RawDescriptionHelpFormatter,
		epilog=(
			"Exemplos de uso:\n"
			"  python tools/bake_collisions.py\n"
			"  python tools/bake_collisions.py --chunk 17_25\n"
			"  python tools/bake_collisions.py -c 16_24\n"
			"  python tools/bake_collisions.py --all\n"
			"  python tools/bake_collisions.py --godot-exe \"C:/Godot/godot.exe\"\n"
		),
	)

	parser.add_argument(
		"--chunk",
		"-c",
		default=None,
		help="Identificador do chunk específico a compilar (ex: 17_25)",
	)

	parser.add_argument(
		"--all",
		"-a",
		action="store_true",
		help="Força compilação de todos os chunks disponíveis (padrão quando --chunk não é passado)",
	)

	parser.add_argument(
		"--godot-exe",
		default=None,
		help="Caminho manual alternativo do executável Godot 4.7",
	)

	args = parser.parse_args()
	exit_code = run_bake_collisions(
		chunk_name=args.chunk,
		godot_exe_path=args.godot_exe,
	)
	sys.exit(exit_code)


if __name__ == "__main__":
	main()
