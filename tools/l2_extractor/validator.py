#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/validator.py — Validador de Ambiente e Pre-flight Health Check

@description
Realiza a validação rigorosa de todos os pré-requisitos antes da execução do pipeline:
- Verifica a existência e integridade da pasta raiz do Lineage II (Lineage II/).
- Verifica as subpastas essenciais (maps, textures, systextures, staticmeshes).
- Verifica a ferramenta UModel CLI (umodel_win32/umodel_64.exe).
- Verifica dependências Python essenciais (numpy, Pillow, pycryptodome).
- Interrompe a execução imediatamente e emite relatórios detalhados caso falte algo.

@created 2026-08-20
@updated 2026-08-20
@author Leonardo S. Badaró
"""

from dataclasses import dataclass, field
import importlib.util
from pathlib import Path
import sys
from typing import List, Optional

from .config import PipelineConfig


@dataclass
class ValidationResult:
    """Resultado da checagem de saúde do ambiente do pipeline."""
    is_valid: bool
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)

    def add_error(self, message: str) -> None:
        self.errors.append(message)
        self.is_valid = False

    def add_warning(self, message: str) -> None:
        self.warnings.append(message)


def validate_pipeline_environment(
    config: Optional[PipelineConfig] = None,
    require_l2_root: bool = True,
    require_umodel: bool = False,
    abort_on_error: bool = True,
) -> ValidationResult:
    """
    Executa a verificação prévia de pré-requisitos (Pre-flight Check).
    Se abort_on_error for True e houver erros impeditivos, aborta o processo
    com código de saída não-zero e imprime um relatório de diagnóstico rico.
    """
    if config is None:
        config = PipelineConfig()

    result = ValidationResult(is_valid=True)

    # 1. Validação de Módulos Python
    required_python_modules = [
        ("numpy", "NumPy (Cálculo Numérico e Manipulação de Vértices)"),
        ("PIL", "Pillow (Decodificação e Gravação de Texturas PNG)"),
        ("Crypto", "pycryptodome (Desencriptação Criptográfica Blowfish UE2)"),
    ]

    for mod_name, desc in required_python_modules:
        if importlib.util.find_spec(mod_name) is None:
            result.add_error(
                f"Módulo Python '{mod_name}' não instalado ({desc}).\n"
                f"    -> Solução: Execute 'pip install numpy Pillow pycryptodome'"
            )

    # 2. Validação da Pasta de Dados RAW do Lineage II
    if require_l2_root:
        if config.l2_root_dir is None or not config.l2_root_dir.is_dir():
            result.add_error(
                f"Diretório de dados RAW do Lineage II não encontrado na raiz do projeto:\n"
                f"    -> Caminho Esperado: {config.l2_root_dir}\n"
                f"    -> Solução: Coloque a pasta 'Lineage II' instalada diretamente na raiz do projeto."
            )
        else:
            # Verifica subdiretórios essenciais
            subdirs_to_check = [
                ("maps", "Mapas e Chunks de Terreno (.UNR)"),
                ("textures", "Texturas de Solo e Materiais (.UTX)"),
                ("systextures", "Texturas de Sistema (.UTX)"),
                ("staticmeshes", "Malhas 3D e Modelos Estáticos (.USX)"),
            ]
            for sub, sub_desc in subdirs_to_check:
                target_sub = config.l2_root_dir / sub
                if not target_sub.is_dir():
                    result.add_error(
                        f"Subpasta essencial '{sub}' não encontrada dentro de '{config.l2_root_dir.name}':\n"
                        f"    -> Caminho Esperado: {target_sub}\n"
                        f"    -> Finalidade: {sub_desc}\n"
                        f"    -> Solução: Verifique se a instalação do Lineage II está completa."
                    )

    # 3. Validação do Executável UModel CLI
    if require_umodel:
        if config.umodel_exe_path is None or not config.umodel_exe_path.is_file():
            result.add_error(
                f"Executável UModel CLI não encontrado na raiz do projeto:\n"
                f"    -> Caminho Esperado: {config.project_root / 'umodel_win32' / 'umodel_64.exe'} "
                f"ou {config.project_root / 'umodel_win32' / 'umodel.exe'}\n"
                f"    -> Solução: Coloque o executável do UModel na pasta 'umodel_win32/' na raiz do projeto."
            )
    else:
        if config.umodel_exe_path is None or not config.umodel_exe_path.is_file():
            result.add_warning(
                f"UModel CLI não detectado em '{config.umodel_exe_path}'. "
                f"A extração de malhas GLTF multi-primitivas dependerá de exports locais prévios."
            )

    # 4. Tratamento de Erro / Abort
    if not result.is_valid and abort_on_error:
        print("\n" + "=" * 80, file=sys.stderr)
        print(" [!] FALHA NO PRE-FLIGHT CHECK — PRÉ-REQUISITOS AUSENTES", file=sys.stderr)
        print("=" * 80, file=sys.stderr)
        print("\nO pipeline de compilação foi interrompido antes do início para evitar corrupção:\n", file=sys.stderr)
        for idx, err in enumerate(result.errors, 1):
            print(f" [{idx}] {err}\n", file=sys.stderr)
        print("=" * 80 + "\n", file=sys.stderr)
        sys.exit(1)

    return result
