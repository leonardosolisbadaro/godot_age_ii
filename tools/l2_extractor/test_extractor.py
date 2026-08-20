#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/test_extractor.py — Bateria de Testes Automatizados para o Pipeline L2 Extractor

@description
Executa testes unitários e de integração governados pelo padrão AAA (Arrange, Act, Assert):
1. Configuração e Pre-flight Health Check (PipelineConfig, ValidationResult, validate_pipeline_environment)
2. Desencriptação de cabeçalhos e verificação de assinatura UE2 (0x9E2A83C1)
3. Decodificadores de textura (DXT1, DXT3, DXT5 com alpha interpolado, P8, G8, RGBA8)
4. CompactIndex e serialização de tipos primitivos/vetores/rotators
5. Compilação de malha de terreno e soldagem contínua (2-Pass Seamless Alignment)
6. Conversão de Rotators UE2 para Euler/radianos e vetores direcionais 3D
7. Testes de integração com pacotes reais do Lineage II (quando presentes)

@created 2026-08-18
@updated 2026-08-20
@author Leonardo S. Badaró
"""

import math
import os
from pathlib import Path
import struct
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image

# Adiciona a raiz do projeto ao path
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from tools.l2_extractor import (
    L2Decryptor,
    L2Environment,
    PipelineConfig,
    StaticMeshParser,
    TerrainChunkCompiler,
    UE2_PACKAGE_TAG,
    UMODEL_TO_CANONICAL_SCALE,
    UU_TO_METERS_CANONICAL,
    UnrealPackageReader,
    build_terrain_mesh,
    compile_cluster,
    decode_dxt1,
    decode_dxt3,
    decode_dxt5,
    decode_g8,
    decode_p8,
    decode_rgba8,
    strip_to_triangles,
    ue2_rotator_to_direction_vector,
    ue2_rotator_to_euler,
    validate_pipeline_environment,
    write_glb,
)


class TestPipelineConfigAndValidator(unittest.TestCase):
    """Testes unitários para os módulos de configuração e pre-flight check (AAA)."""

    def test_pipeline_config_defaults(self):
        # Arrange
        root = PROJECT_ROOT

        # Act
        config = PipelineConfig(project_root=root)

        # Assert
        self.assertEqual(config.project_root, root)
        self.assertEqual(config.l2_root_dir, root / "Lineage II")
        self.assertEqual(config.maps_output_dir, root / "assets" / "maps")
        self.assertEqual(config.models_output_dir, root / "assets" / "models")
        self.assertEqual(config.textures_output_dir, root / "assets" / "textures")
        self.assertEqual(config.unit_scale, UU_TO_METERS_CANONICAL)
        self.assertEqual(config.mesh_scale_factor, UMODEL_TO_CANONICAL_SCALE)

    def test_validator_fails_on_missing_l2_root(self):
        # Arrange
        with tempfile.TemporaryDirectory() as tmpdir:
            fake_config = PipelineConfig(
                project_root=Path(tmpdir),
                l2_root_dir=Path(tmpdir) / "Inexistent_Lineage_II",
            )

            # Act
            result = validate_pipeline_environment(fake_config, require_l2_root=True, abort_on_error=False)

            # Assert
            self.assertFalse(result.is_valid)
            self.assertGreater(len(result.errors), 0)
            self.assertTrue(any("Diretório de dados RAW" in e for e in result.errors))

    def test_validator_passes_when_directories_exist(self):
        # Arrange
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            l2_dir = tmp_path / "Lineage II"
            for sub in ("maps", "textures", "systextures", "staticmeshes"):
                (l2_dir / sub).mkdir(parents=True, exist_ok=True)

            config = PipelineConfig(
                project_root=tmp_path,
                l2_root_dir=l2_dir,
            )

            # Act
            result = validate_pipeline_environment(config, require_l2_root=True, require_umodel=False, abort_on_error=False)

            # Assert
            self.assertTrue(result.is_valid)
            self.assertEqual(len(result.errors), 0)


class TestL2Decryptor(unittest.TestCase):
    """Testes unitários para o módulo L2Decryptor (AAA)."""

    def test_header_validation(self):
        # Arrange: Cabeçalho inválido por tamanho
        short_data = b"short"

        # Act & Assert
        self.assertFalse(L2Decryptor.is_valid_ue2_header(short_data))

        # Arrange: Cabeçalho com tag incorreta
        fake_data = struct.pack("<IIIIIIIII", 0x12345678, 120, 0, 10, 100, 5, 200, 5, 300)

        # Act & Assert
        self.assertFalse(L2Decryptor.is_valid_ue2_header(fake_data))

        # Arrange: Cabeçalho sintético válido
        valid_data = bytearray(500)
        struct.pack_into("<IIIIIIIII", valid_data, 0, UE2_PACKAGE_TAG, 128, 0, 10, 100, 5, 200, 5, 300)

        # Act & Assert
        self.assertTrue(L2Decryptor.is_valid_ue2_header(bytes(valid_data)))


class TestTextureDecoders(unittest.TestCase):
    """Testes unitários para os decodificadores de textura (AAA)."""

    def test_decode_g8(self):
        # Arrange
        raw = bytes([i % 256 for i in range(16 * 16)])

        # Act
        img = decode_g8(raw, 16, 16)

        # Assert
        self.assertIsNotNone(img)
        self.assertEqual(img.size, (16, 16))
        self.assertEqual(img.mode, "L")

    def test_decode_p8(self):
        # Arrange
        raw = bytes([i % 256 for i in range(16 * 16)])
        palette = [(i, i, i, 255) for i in range(256)]

        # Act
        img = decode_p8(raw, 16, 16, palette)

        # Assert
        self.assertIsNotNone(img)
        self.assertEqual(img.size, (16, 16))

        # Arrange: Paleta com transparência
        palette_alpha = [(i, 255 - i, 128, 0 if i < 10 else 255) for i in range(256)]

        # Act
        img_alpha = decode_p8(raw, 16, 16, palette_alpha)

        # Assert
        self.assertIsNotNone(img_alpha)
        self.assertEqual(img_alpha.mode, "RGBA")

    def test_decode_dxt1(self):
        # Arrange: 1 bloco 4x4 DXT1 (8 bytes) todos brancos
        block = struct.pack("<HHI", 0xFFFF, 0x0000, 0x00000000)

        # Act
        img = decode_dxt1(block, 4, 4)

        # Assert
        self.assertIsNotNone(img)
        self.assertEqual(img.size, (4, 4))
        arr = np.array(img)
        self.assertEqual(arr.shape, (4, 4, 3))
        self.assertTrue(np.all(arr >= 250))

    def test_decode_dxt3(self):
        # Arrange: 1 bloco 4x4 DXT3 (16 bytes)
        alpha_block = bytes([0x0F] * 8)
        color_block = struct.pack("<HHI", 0xFFFF, 0x0000, 0x00000000)
        dxt3_data = alpha_block + color_block

        # Act
        img = decode_dxt3(dxt3_data, 4, 4)

        # Assert
        self.assertIsNotNone(img)
        self.assertEqual(img.size, (4, 4))
        self.assertEqual(img.mode, "RGBA")
        arr = np.array(img)
        self.assertEqual(arr[0, 0, 3], 255)
        self.assertEqual(arr[0, 1, 3], 0)

    def test_decode_rgba8(self):
        # Arrange
        raw = bytes([255, 128, 64, 200] * (4 * 4))

        # Act
        img = decode_rgba8(raw, 4, 4)

        # Assert
        self.assertIsNotNone(img)
        self.assertEqual(img.size, (4, 4))
        self.assertEqual(img.mode, "RGBA")
        arr = np.array(img)
        self.assertEqual(arr[0, 0, 0], 255)
        self.assertEqual(arr[0, 0, 1], 128)
        self.assertEqual(arr[0, 0, 2], 64)
        self.assertEqual(arr[0, 0, 3], 200)

    def test_compact_index_logic(self):
        # Arrange: Pacote sintético com CompactIndices
        reader = UnrealPackageReader.__new__(UnrealPackageReader)
        reader.data = bytes([0x05, 0x45, 0x01, 0x85, 0x00])
        reader.pos = 0

        # Act & Assert
        self.assertEqual(reader.read_compact_index(), 5)
        self.assertEqual(reader.read_compact_index(), 69)
        self.assertEqual(reader.read_compact_index(), -5)


class TestTerrainBuilder(unittest.TestCase):
    """Testes unitários para o pipeline de terreno (AAA)."""

    def test_build_terrain_mesh_synthetic(self):
        # Arrange
        heights = np.full((16, 16), 32768, dtype=np.uint16)
        scale = (64.0, 64.0, 32.0)
        location = (0.0, 0.0, 0.0)

        # Act
        positions, normals, uvs, triangles, world_y = build_terrain_mesh(heights, scale, location)

        # Assert
        self.assertEqual(positions.shape, (16 * 16, 3))
        self.assertEqual(normals.shape, (16 * 16, 3))
        self.assertEqual(uvs.shape, (16 * 16, 2))
        self.assertEqual(triangles.shape, (15 * 15 * 2, 3))
        self.assertEqual(world_y.shape, (16, 16))
        self.assertAlmostEqual(float(world_y.min()), 0.0, places=2)


class TestStaticMeshBuilder(unittest.TestCase):
    """Testes unitários para o pipeline de extração de StaticMeshes (AAA)."""

    def test_strip_to_triangles(self):
        # Arrange: Faixa de 4 vértices com restart index 0xFFFF
        strip = [0, 1, 2, 3, 0xFFFF, 4, 5, 6]

        # Act
        tris = strip_to_triangles(strip)

        # Assert
        self.assertEqual(len(tris), 3)
        self.assertEqual(tris[0], [0, 1, 2])
        self.assertEqual(tris[1], [1, 3, 2])
        self.assertEqual(tris[2], [4, 5, 6])

    def test_ue2_rotator_to_euler(self):
        # Arrange: 16384 unidades UE2 = 90 graus = pi/2 radianos
        pitch = 16384
        yaw = 0
        roll = 0

        # Act
        p, y, r = ue2_rotator_to_euler(pitch, yaw, roll)

        # Assert
        self.assertAlmostEqual(p, math.pi / 2.0, places=3)
        self.assertAlmostEqual(y, 0.0, places=3)


class TestEnvironmentAndMaterials(unittest.TestCase):
    """Testes unitários para Materiais, Iluminação e Atmosfera (AAA)."""

    def test_sunlight_vector_calculation(self):
        # Arrange: Pitch = -16384 (90 graus apontando para baixo / Y negativo no Godot)
        pitch = -16384
        yaw = 0

        # Act
        vec_down = ue2_rotator_to_direction_vector(pitch=pitch, yaw=yaw)

        # Assert
        self.assertAlmostEqual(vec_down[1], -1.0, places=3)

        # Arrange: Ângulo oblíquo (Pitch=-10923, Yaw=16383)
        # Act
        vec_oblique = ue2_rotator_to_direction_vector(pitch=-10923, yaw=16383)

        # Assert
        length = math.sqrt(vec_oblique[0]**2 + vec_oblique[1]**2 + vec_oblique[2]**2)
        self.assertAlmostEqual(length, 1.0, places=4)


class TestRealL2Packages(unittest.TestCase):
    """Testes de integração com pacotes reais do Lineage II na raiz (se disponíveis)."""

    def setUp(self):
        self.config = PipelineConfig()
        self.l2_env = L2Environment(config=self.config)

    def test_environment_discovery(self):
        if not self.l2_env.l2_root or not self.l2_env.l2_root.is_dir():
            self.skipTest("Pasta Lineage II/ não encontrada na raiz.")
        self.assertGreater(len(self.l2_env.available_unr), 0, "Deve encontrar mapas .unr")
        self.assertGreater(len(self.l2_env.available_utx), 0, "Deve encontrar pacotes .utx")
        self.assertGreater(len(self.l2_env.available_usx), 0, "Deve encontrar pacotes .usx")

    def test_parse_map_16_24(self):
        if not self.l2_env.l2_root or not self.l2_env.l2_root.is_dir():
            self.skipTest("Pasta Lineage II/ não encontrada.")
        map_path = self.l2_env.available_unr.get("16_24")
        if not map_path or not map_path.is_file():
            self.skipTest("Mapa 16_24.unr não encontrado.")

        reader = UnrealPackageReader(map_path)
        self.assertEqual(reader.tag, UE2_PACKAGE_TAG)
        self.assertGreater(len(reader.names), 0)
        self.assertGreater(len(reader.exports), 0)
        self.assertGreater(len(reader.imports), 0)


def run_tests():
    suite = unittest.TestLoader().loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
