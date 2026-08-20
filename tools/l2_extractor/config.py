#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/config.py — Configuração Centralizada e Constantes Semânticas do Pipeline

@description
Define todas as constantes matemáticas, fatores de escala métrica, estruturas de dados,
caminhos canônicos e a estrutura de configuração injetável (PipelineConfig) para todo o
pipeline de extração e compilação do Lineage II para Godot 4.7.
Elimina 100% de números mágicos e caminhos hardcoded espalhados no código.

@created 2026-08-20
@updated 2026-08-20
@author Leonardo S. Badaró
"""

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union


# ==============================================================================
# BLOCO 1: CONSTANTES DE CONVERSÃO ESPACIAL E ESCALAS MÉTRICAS
# ==============================================================================

## @const UU_TO_METERS_CANONICAL (float)
## O que: Fator de conversão padrão de Unreal Units (UU) para metros no Godot (0.08).
## Porque: Na Unreal Engine 2 de Lineage II, 1 UU equivale a 8 centímetros (0.08m = 1/12.5).
UU_TO_METERS_CANONICAL: float = 0.08

## @const UMODEL_TO_CANONICAL_SCALE (float)
## O que: Multiplicador de escala de malhas GLTF exportadas pelo UModel (8.0x).
## Porque: O UModel normaliza malhas para 0.01m (1 UU = 1cm). Para atingir a escala canônica
## do Lineage II (0.08m), os vértices precisam ser multiplicados por 8.0x (0.08 / 0.01 = 8.0).
UMODEL_TO_CANONICAL_SCALE: float = 8.0

## @const UE2_ROTATOR_FULL_CIRCLE (float)
## O que: Quantidade de unidades angulares discretas em uma volta completa (360 graus / 2*pi radianos).
## Porque: A UE2 utiliza inteiros de 16 bits não sinalizados (0..65535) para representar rotações completas.
UE2_ROTATOR_FULL_CIRCLE: float = 65536.0

## @const UE2_ROTATOR_QUARTER_CIRCLE (float)
## O que: Quantidade de unidades angulares discretas em um quarto de volta (90 graus / pi/2 radianos).
## Porque: 65536 / 4 = 16384 unidades. Usado para calibração e testes de rotação.
UE2_ROTATOR_QUARTER_CIRCLE: float = 16384.0


# ==============================================================================
# BLOCO 2: CONSTANTES DO TERRENO E HEIGHTFIELD
# ==============================================================================

## @const TERRAIN_GRID_RESOLUTION (int)
## O que: Resolução padrão de vértices por eixo em um chunk de terreno do Lineage II (256x256).
## Porque: Cada pacote de mapa (.unr) possui um heightmap G16 de exatamente 256x256 pontos.
TERRAIN_GRID_RESOLUTION: int = 256

## @const TERRAIN_HEIGHT_OFFSET_U16 (float)
## O que: Valor de ponto neutro (nível zero de elevação) em heightmaps G16 de 16 bits (32768.0).
## Porque: Formato uint16 varia de 0 a 65535, onde 32768 representa o plano central de altitude zero na UE2.
TERRAIN_HEIGHT_OFFSET_U16: float = 32768.0

## @const TERRAIN_HEIGHT_DIVISOR (float)
## O que: Divisor canônico para conversão de escala Z da UE2 para metros (256.0).
## Porque: A fórmula canônica da UE2 para altitude mundial é: (Height - 32768) * (ZScale / 256.0) * UnitScale.
TERRAIN_HEIGHT_DIVISOR: float = 256.0

## @const TERRAIN_SECTOR_SIZE_DEFAULT (int)
## O que: Tamanho padrão de subdivisão de setor de terreno (16 quads por setor).
## Porque: Utilizado para particionamento de visibilidade de quads (QuadVisibilityBitmap).
TERRAIN_SECTOR_SIZE_DEFAULT: int = 16

## @const SPLATMAP_RESOLUTION (int)
## O que: Resolução de textura para Splatmaps RGBA gerados (1024x1024 pixels).
## Porque: Oferece fidelidade de blend suave entre camadas com 4x a densidade do grid de vértices.
SPLATMAP_RESOLUTION: int = 1024

## @const SPLATMAP_MAX_LAYERS_PER_MAP (int)
## O que: Número de canais de cor por arquivo Splatmap RGBA (4 camadas por textura).
## Porque: Cada textura RGBA de 8 bits armazena 4 canais de pesos de mistura independentes (R, G, B, A).
SPLATMAP_MAX_LAYERS_PER_MAP: int = 4

## @const TERRAIN_MAX_TOTAL_LAYERS (int)
## O que: Limite máximo de camadas de textura de solo por chunk de terreno (12 camadas).
## Porque: 12 camadas correspondem a exatamente 3 texturas de Splatmaps RGBA (3 * 4 = 12), suportadas pelo shader.
TERRAIN_MAX_TOTAL_LAYERS: int = 12


# ==============================================================================
# BLOCO 3: CONSTANTES DE PACOTES UNREAL ENGINE 2 (UE2)
# ==============================================================================

## @const UE2_PACKAGE_TAG (int)
## O que: Número mágico (assinatura de 32 bits) presente no início de todo pacote UE2 válido (0x9E2A83C1).
## Porque: Identificador oficial do cabeçalho da Unreal Engine 2 (Little-Endian).
UE2_PACKAGE_TAG: int = 0x9E2A83C1

## @const UE2_MIN_VALID_VERSION (int)
## O que: Versão mínima de arquivo de pacote UE2 aceita pelo parser (60).
## Porque: Pacotes anteriores à versão 60 usam formatos legados de Unreal 1 incompatíveis com L2.
UE2_MIN_VALID_VERSION: int = 60

## @const UE2_MAX_VALID_VERSION (int)
## O que: Versão máxima de arquivo de pacote UE2 aceita pelo parser (300).
## Porque: Versões acima de 300 pertencem à Unreal Engine 3 ou superior.
UE2_MAX_VALID_VERSION: int = 300

## @const UE2_HEADER_MIN_BYTE_SIZE (int)
## O que: Tamanho mínimo em bytes do cabeçalho de um pacote UE2 (36 bytes).
## Porque: 9 campos inteiros de 4 bytes (Tag, Versão, Flags, NameCount, NameOffset, ExportCount, ExportOffset, ImportCount, ImportOffset).
UE2_HEADER_MIN_BYTE_SIZE: int = 36

## @const L2_BLOWFISH_KEY (bytes)
## O que: Chave simétrica Blowfish padrão utilizada pelo cliente Lineage II (b"lineage2").
## Porque: Utilizada para decodificar o encapsulamento criptográfico de pacotes do jogo.
L2_BLOWFISH_KEY: bytes = b"lineage2"

## @const BLOWFISH_BLOCK_SIZE (int)
## O que: Tamanho do bloco do algoritmo de cifra simétrica Blowfish em bytes (8 bytes / 64 bits).
## Porque: A cifra Blowfish opera estritamente em blocos de 64 bits.
BLOWFISH_BLOCK_SIZE: int = 8

## @const TRIANGLE_STRIP_RESTART_INDEX (int)
## O que: Índice especial de reinício de faixa de triângulos na UE2 (0xFFFF = 65535).
## Porque: Na geometria da UE2, 0xFFFF demarca o fim de uma tira de triângulos e o início de outra.
TRIANGLE_STRIP_RESTART_INDEX: int = 0xFFFF


# ==============================================================================
# BLOCO 4: CONSTANTES DE FORMATOS DE TEXTURA
# ==============================================================================

## @const DXT_BLOCK_PIXELS_DIM (int)
## O que: Largura e altura de cada bloco de compressão DXT em pixels (4x4).
## Porque: Formatos de compressão de blocos S3TC (DXT1/DXT3/DXT5) operam em matrizes 4x4.
DXT_BLOCK_PIXELS_DIM: int = 4

## @const DXT1_BLOCK_BYTE_SIZE (int)
## O que: Tamanho em bytes de 1 bloco comprimido DXT1/BC1 (8 bytes).
## Porque: Contém 2 cores de 16 bits (4 bytes) + matriz de índices de 32 bits (4 bytes).
DXT1_BLOCK_BYTE_SIZE: int = 8

## @const DXT3_5_BLOCK_BYTE_SIZE (int)
## O que: Tamanho em bytes de 1 bloco comprimido DXT3/BC2 ou DXT5/BC3 (16 bytes).
## Porque: Contém 8 bytes de dados de canal alfa + 8 bytes de bloco de cores DXT1.
DXT3_5_BLOCK_BYTE_SIZE: int = 16

## @const PALETTE_ENTRIES_COUNT (int)
## O que: Quantidade de cores em uma paleta de textura indexada P8 (256 cores).
## Porque: Formato de 8 bits suporta exatamente 2^8 = 256 entradas de cor RGBA.
PALETTE_ENTRIES_COUNT: int = 256


# ==============================================================================
# BLOCO 5: CONSTANTES DE TIMEOUT E PROCESSAMENTO EXTERNO
# ==============================================================================

## @const UMODEL_TEXTURE_TIMEOUT_SECS (int)
## O que: Tempo limite em segundos para extração de um pacote de texturas via UModel CLI (45s).
## Porque: Evita travamento infinito caso o UModel entre em loop em arquivos corrompidos.
UMODEL_TEXTURE_TIMEOUT_SECS: int = 45

## @const UMODEL_MESH_TIMEOUT_SECS (int)
## O que: Tempo limite em segundos para extração de um pacote de malhas 3D via UModel CLI (60s).
## Porque: Pacotes de malhas complexas requerem decodificação de múltiplos LODs e buffers binários.
UMODEL_MESH_TIMEOUT_SECS: int = 60


# ==============================================================================
# BLOCO 6: DATACLASS DE CONFIGURAÇÃO DO PIPELINE (INJEÇÃO DE DEPENDÊNCIAS)
# ==============================================================================

@dataclass
class PipelineConfig:
    """
    Configuração fortemente tipada e injetável para todo o pipeline de extração.
    Centraliza os caminhos físicos do projeto e parâmetros operacionais.
    """
    # Raiz do projeto
    project_root: Path = field(default_factory=lambda: Path(__file__).resolve().parent.parent.parent)

    # Diretório dos dados RAW do Lineage II (estritamente na raiz)
    l2_root_dir: Optional[Path] = None

    # Executável UModel CLI (estritamente na raiz do projeto)
    umodel_exe_path: Optional[Path] = None

    # Diretórios de saída dos artefatos compilados
    maps_output_dir: Optional[Path] = None
    models_output_dir: Optional[Path] = None
    textures_output_dir: Optional[Path] = None
    umodel_export_dir: Optional[Path] = None

    # Parâmetros de escala e compilação
    unit_scale: float = UU_TO_METERS_CANONICAL
    mesh_scale_factor: float = UMODEL_TO_CANONICAL_SCALE
    pack_splatmaps: bool = True
    force_rebuild: bool = False

    def __post_init__(self) -> None:
        """Inicializa caminhos canônicos padrão relativos à raiz do projeto."""
        self.project_root = self.project_root.resolve()

        if self.l2_root_dir is None:
            self.l2_root_dir = self.project_root / "Lineage II"
        else:
            self.l2_root_dir = Path(self.l2_root_dir).resolve()

        if self.umodel_exe_path is None:
            primary_umodel = self.project_root / "umodel_win32" / "umodel_64.exe"
            fallback_umodel = self.project_root / "umodel_win32" / "umodel.exe"
            self.umodel_exe_path = primary_umodel if primary_umodel.is_file() else fallback_umodel
        else:
            self.umodel_exe_path = Path(self.umodel_exe_path).resolve()

        if self.maps_output_dir is None:
            self.maps_output_dir = self.project_root / "assets" / "maps"
        else:
            self.maps_output_dir = Path(self.maps_output_dir).resolve()

        if self.models_output_dir is None:
            self.models_output_dir = self.project_root / "assets" / "models"
        else:
            self.models_output_dir = Path(self.models_output_dir).resolve()

        if self.textures_output_dir is None:
            self.textures_output_dir = self.project_root / "assets" / "textures"
        else:
            self.textures_output_dir = Path(self.textures_output_dir).resolve()

        if self.umodel_export_dir is None:
            self.umodel_export_dir = self.project_root / "UmodelExport"
        else:
            self.umodel_export_dir = Path(self.umodel_export_dir).resolve()
