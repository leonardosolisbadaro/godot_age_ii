#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/umodel_wrapper.py — Wrapper de Automação para UModel CLI

@description
Gerencia a execução em segundo plano do UModel CLI para extração de malhas 3D (.gltf)
e pacotes de texturas (.png). Opera estritamente com o binário localizado na raiz do projeto
(umodel_win32/umodel_64.exe ou umodel_win32/umodel.exe) sem qualquer fallback externo.

@created 2026-08-18
@updated 2026-08-20
@author Leonardo S. Badaró
"""

import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Optional, Union

from .config import (
    PipelineConfig,
    UMODEL_MESH_TIMEOUT_SECS,
    UMODEL_TEXTURE_TIMEOUT_SECS,
)


def find_umodel_executable(config: Optional[PipelineConfig] = None) -> Optional[Path]:
    """
    Retorna o caminho do executável UModel CLI estritamente dentro da raiz do projeto.
    Não busca em nenhum outro diretório do sistema operacional.
    """
    cfg = config or PipelineConfig()
    if cfg.umodel_exe_path and cfg.umodel_exe_path.is_file():
        return cfg.umodel_exe_path

    # Fallback exclusivo na pasta umodel_win32/ da raiz do projeto
    cand_64 = cfg.project_root / "umodel_win32" / "umodel_64.exe"
    if cand_64.is_file():
        return cand_64

    cand_32 = cfg.project_root / "umodel_win32" / "umodel.exe"
    if cand_32.is_file():
        return cand_32

    return None


def export_package_textures(
    pkg_name: str,
    l2_root: Path,
    out_textures_dir: Path,
    umodel_exe: Optional[Path] = None,
    timeout: int = UMODEL_TEXTURE_TIMEOUT_SECS,
) -> bool:
    """
    Extrai todas as texturas de um pacote .utx para PNG em out_textures_dir/<pkg_name>/
    utilizando o executável UModel CLI.
    """
    if umodel_exe is None:
        umodel_exe = find_umodel_executable()

    if not umodel_exe or not umodel_exe.is_file():
        print(f"    [AVISO] UModel CLI não encontrado para extrair texturas de '{pkg_name}'.", file=sys.stderr)
        return False

    clean_pkg = pkg_name.lower().replace(".utx", "").replace(".usx", "")
    target_dir = out_textures_dir / clean_pkg

    # Cria diretório temporário para extração isolada
    temp_out = out_textures_dir / f"_temp_{clean_pkg}"
    temp_out.mkdir(parents=True, exist_ok=True)

    cmd = [
        str(umodel_exe),
        f"-path={l2_root}",
        "-export",
        "-png",
        f"-out={temp_out}",
        clean_pkg,
    ]

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        if res.returncode == 0:
            target_dir.mkdir(parents=True, exist_ok=True)
            exported_images = list(temp_out.glob("**/*.png")) + list(temp_out.glob("**/*.tga"))
            for src_p in exported_images:
                dst_p = target_dir / src_p.name
                shutil.copy2(src_p, dst_p)

            shutil.rmtree(temp_out, ignore_errors=True)
            return True
        else:
            err_msg = res.stderr.strip() or res.stdout.strip()
            print(f"    [AVISO] UModel retornou código {res.returncode} para pacote '{clean_pkg}': {err_msg[:120]}", file=sys.stderr)
    except subprocess.TimeoutExpired:
        print(f"    [AVISO] Timeout de {timeout}s excedido ao extrair texturas de '{clean_pkg}' via UModel.", file=sys.stderr)
    except Exception as e:
        print(f"    [AVISO] Exceção ao executar UModel CLI para '{clean_pkg}': {e}", file=sys.stderr)

    shutil.rmtree(temp_out, ignore_errors=True)
    return False


def export_package_meshes(
    pkg_name: str,
    l2_root: Path,
    out_umodel_export_dir: Path,
    umodel_exe: Optional[Path] = None,
    timeout: int = UMODEL_MESH_TIMEOUT_SECS,
) -> bool:
    """
    Extrai todas as StaticMeshes de um pacote .usx para GLTF em out_umodel_export_dir/<pkg_name>/StaticMesh/*.gltf
    utilizando o executável UModel CLI.
    """
    if umodel_exe is None:
        umodel_exe = find_umodel_executable()

    if not umodel_exe or not umodel_exe.is_file():
        print(f"    [AVISO] UModel CLI não encontrado para extrair malhas de '{pkg_name}'.", file=sys.stderr)
        return False

    clean_pkg = pkg_name.lower().replace(".usx", "")
    cmd = [
        str(umodel_exe),
        f"-path={l2_root}",
        "-export",
        "-gltf",
        f"-out={out_umodel_export_dir}",
        clean_pkg,
    ]

    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        if res.returncode == 0:
            return True
        else:
            err_msg = res.stderr.strip() or res.stdout.strip()
            print(f"    [AVISO] UModel retornou código {res.returncode} para malhas de '{clean_pkg}': {err_msg[:120]}", file=sys.stderr)
    except subprocess.TimeoutExpired:
        print(f"    [AVISO] Timeout de {timeout}s excedido ao extrair malhas de '{clean_pkg}' via UModel.", file=sys.stderr)
    except Exception as e:
        print(f"    [AVISO] Exceção ao executar UModel CLI para malhas de '{clean_pkg}': {e}", file=sys.stderr)

    return False
