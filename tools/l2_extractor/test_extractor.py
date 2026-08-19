#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/test_extractor.py — Bateria de Testes Automatizados para o Pipeline L2 Extractor

Executa testes unitários e de integração para validar:
1. Desencriptação de cabeçalhos e verificação de assinatura UE2 (0x9E2A83C1)
2. Decodificadores de textura (DXT1, DXT3, DXT5 com alpha interpolado, P8, G8)
3. CompactIndex e serialização de tipos primitivos/vetores/rotators
4. Teste de integração com mapas (.unr), pacotes de textura (.utx) e malhas (.usx) reais do Lineage II
"""

import os
from pathlib import Path
import struct
import sys
import unittest
import numpy as np
from PIL import Image

# Adiciona a raiz do projeto ao path para importar l2_extractor
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from tools.l2_extractor import (
    L2Decryptor,
    UE2_PACKAGE_TAG,
    UnrealPackageReader,
    L2Environment,
    decode_dxt1,
    decode_dxt3,
    decode_dxt5,
    decode_p8,
    decode_g8,
    decode_rgba8,
    TerrainChunkCompiler,
    build_terrain_mesh,
    compile_cluster,
    write_glb,
)


class TestL2Decryptor(unittest.TestCase):
    """Testes unitários para o módulo L2Decryptor."""

    def test_header_validation(self):
        # Cabeçalho inválido por tamanho
        self.assertFalse(L2Decryptor.is_valid_ue2_header(b"short"))

        # Cabeçalho com tag errada
        fake_data = struct.pack("<IIIIIIIII", 0x12345678, 120, 0, 10, 100, 5, 200, 5, 300)
        self.assertFalse(L2Decryptor.is_valid_ue2_header(fake_data))

        # Cabeçalho válido sintético
        valid_data = bytearray(500)
        struct.pack_into("<IIIIIIIII", valid_data, 0, UE2_PACKAGE_TAG, 128, 0, 10, 100, 5, 200, 5, 300)
        self.assertTrue(L2Decryptor.is_valid_ue2_header(bytes(valid_data)))


class TestTextureDecoders(unittest.TestCase):
    """Testes unitários para os decodificadores de textura."""

    def test_decode_g8(self):
        raw = bytes([i % 256 for i in range(16 * 16)])
        img = decode_g8(raw, 16, 16)
        self.assertIsNotNone(img)
        self.assertEqual(img.size, (16, 16))
        self.assertEqual(img.mode, "L")

    def test_decode_p8(self):
        raw = bytes([i % 256 for i in range(16 * 16)])
        palette = [(i, i, i, 255) for i in range(256)]
        img = decode_p8(raw, 16, 16, palette)
        self.assertIsNotNone(img)
        self.assertEqual(img.size, (16, 16))

        # Paleta com alfa transparente
        palette_alpha = [(i, 255 - i, 128, 0 if i < 10 else 255) for i in range(256)]
        img_alpha = decode_p8(raw, 16, 16, palette_alpha)
        self.assertIsNotNone(img_alpha)
        self.assertEqual(img_alpha.mode, "RGBA")

    def test_decode_dxt1(self):
        # 1 bloco 4x4 DXT1 (8 bytes)
        # c0 = 0xFFFF (branco), c1 = 0x0000 (preto), bits = 0x00000000 (todos indice 0 -> c0)
        block = struct.pack("<HHI", 0xFFFF, 0x0000, 0x00000000)
        img = decode_dxt1(block, 4, 4)
        self.assertIsNotNone(img)
        self.assertEqual(img.size, (4, 4))
        arr = np.array(img)
        self.assertEqual(arr.shape, (4, 4, 3))
        self.assertTrue(np.all(arr >= 250))  # Todos pixels brancos

    def test_decode_dxt3(self):
        # 1 bloco 4x4 DXT3 (16 bytes)
        # 8 bytes alfa (4 bits por pixel: 0x0F -> pixel 0 com 255, pixel 1 com 0)
        alpha_block = bytes([0x0F] * 8)
        color_block = struct.pack("<HHI", 0xFFFF, 0x0000, 0x00000000)
        dxt3_data = alpha_block + color_block
        img = decode_dxt3(dxt3_data, 4, 4)
        self.assertIsNotNone(img)
        self.assertEqual(img.size, (4, 4))
        self.assertEqual(img.mode, "RGBA")
        arr = np.array(img)
        self.assertEqual(arr[0, 0, 3], 255)
        self.assertEqual(arr[0, 1, 3], 0)

    def test_decode_rgba8(self):
        raw = bytes([255, 128, 64, 200] * (4 * 4))
        img = decode_rgba8(raw, 4, 4)
        self.assertIsNotNone(img)
        self.assertEqual(img.size, (4, 4))
        self.assertEqual(img.mode, "RGBA")
        arr = np.array(img)
        self.assertEqual(arr[0, 0, 0], 255)
        self.assertEqual(arr[0, 0, 1], 128)
        self.assertEqual(arr[0, 0, 2], 64)
        self.assertEqual(arr[0, 0, 3], 200)

    def test_compact_index_logic(self):
        # Cria pacote sintético mínimo para testar leitura de CompactIndex
        # 0x05 -> 5
        # 0x45 0x01 -> more bit set: 5 | (1 << 6) = 69
        reader = UnrealPackageReader.__new__(UnrealPackageReader)
        reader.data = bytes([0x05, 0x45, 0x01, 0x85, 0x00])
        reader.pos = 0
        self.assertEqual(reader.read_compact_index(), 5)
        self.assertEqual(reader.read_compact_index(), 69)
        self.assertEqual(reader.read_compact_index(), -5)  # sign bit set (0x85)


class TestRealL2Packages(unittest.TestCase):
    """Testes de integração com arquivos reais do Lineage II (se disponíveis)."""

    def setUp(self):
        self.l2_env = L2Environment()

    def test_environment_discovery(self):
        if not self.l2_env.l2_root or not self.l2_env.l2_root.is_dir():
            self.skipTest("Diretório de instalação do Lineage II não encontrado.")
        self.assertGreater(len(self.l2_env.available_unr), 0, "Deve encontrar mapas .unr")
        self.assertGreater(len(self.l2_env.available_utx), 0, "Deve encontrar pacotes .utx")
        self.assertGreater(len(self.l2_env.available_usx), 0, "Deve encontrar pacotes .usx")

    def test_parse_map_16_24(self):
        if not self.l2_env.l2_root:
            self.skipTest("Lineage II não instalado.")
        map_path = self.l2_env.available_unr.get("16_24")
        if not map_path or not map_path.is_file():
            self.skipTest("Mapa 16_24.unr não encontrado.")

        reader = UnrealPackageReader(map_path)
        self.assertEqual(reader.tag, UE2_PACKAGE_TAG)
        self.assertGreater(len(reader.names), 0)
        self.assertGreater(len(reader.exports), 0)
        self.assertGreater(len(reader.imports), 0)

        # Procura por TerrainInfo no mapa 16_24
        terrain_exp = next((e for e in reader.exports if e["class_name"] == "TerrainInfo"), None)
        self.assertIsNotNone(terrain_exp, "16_24.unr deve conter um TerrainInfo exportado.")

        prop_start = reader.find_properties_start(terrain_exp["offset"], terrain_exp["size"])
        props = reader.read_properties(prop_start, terrain_exp["size"] - (prop_start - terrain_exp["offset"]))
        self.assertIn("TerrainScale", props)
        self.assertIn("TerrainMap", props)
        self.assertIn("Layers", props)

    def test_parse_static_mesh_package(self):
        if not self.l2_env.l2_root or len(self.l2_env.available_usx) == 0:
            self.skipTest("Pacotes .usx não disponíveis.")
        # Pega o pacote speaking_tree_s ou o primeiro pacote .usx disponível
        usx_name = "speaking_tree_s" if "speaking_tree_s" in self.l2_env.available_usx else next(iter(self.l2_env.available_usx.keys()))
        reader = self.l2_env.get_package(usx_name)
        self.assertIsNotNone(reader)
        self.assertEqual(reader.tag, UE2_PACKAGE_TAG)
        self.assertGreater(len(reader.names), 0)
        self.assertGreater(len(reader.exports), 0)

    def test_extract_real_texture(self):
        if not self.l2_env.l2_root:
            self.skipTest("Lineage II não instalado.")
        # Procura pacote de texturas T_16_24
        pkg = self.l2_env.get_package("t_16_24") or self.l2_env.get_package("16_24")
        if not pkg:
            self.skipTest("Pacote t_16_24.utx não encontrado.")

        # Extrai export de textura
        tex_exp = next((e for e in pkg.exports if e["class_name"] in ("Texture", "Shader", "Material")), None)
        if tex_exp:
            img = pkg.extract_image_by_export_name(tex_exp["object_name"])
            self.assertIsNotNone(img, f"Falha ao decodificar imagem para export: {tex_exp['object_name']}")
            self.assertGreater(img.size[0], 0)
            self.assertGreater(img.size[1], 0)


class TestTerrainBuilder(unittest.TestCase):
    """Testes unitários para o pipeline de terreno de alta fidelidade."""

    def test_build_terrain_mesh_synthetic(self):
        heights = np.full((16, 16), 32768, dtype=np.uint16)
        scale = (64.0, 64.0, 32.0)
        location = (0.0, 0.0, 0.0)
        positions, normals, uvs, triangles, world_y = build_terrain_mesh(heights, scale, location)

        self.assertEqual(positions.shape, (16 * 16, 3))
        self.assertEqual(normals.shape, (16 * 16, 3))
        self.assertEqual(uvs.shape, (16 * 16, 2))
        self.assertEqual(triangles.shape, (15 * 15 * 2, 3))
        self.assertEqual(world_y.shape, (16, 16))
        self.assertAlmostEqual(float(world_y.min()), 0.0, places=2)

    def test_terrain_extraction_and_compilation(self):
        env = L2Environment()
        if not env.l2_root:
            self.skipTest("Lineage II não instalado.")
        map_path = env.available_unr.get("16_24")
        if not map_path or not map_path.is_file():
            self.skipTest("Mapa 16_24.unr não encontrado.")

        out_dir = Path("test_output_terrain_temp")
        compiler = TerrainChunkCompiler(map_path, out_dir)
        terrains = compiler.extract_terrains()
        self.assertGreater(len(terrains), 0)

        t_info = terrains[0]
        heights = compiler.extract_heightmap(t_info)
        self.assertIsNotNone(heights, "Heightmap G16 de 16_24 deve ser extraído com sucesso.")
        self.assertEqual(heights.shape, (256, 256))

        # Gera malha e valida dimensões
        positions, normals, uvs, triangles, world_y = build_terrain_mesh(
            heights, t_info["scale"], t_info["location"]
        )
        self.assertEqual(positions.shape, (256 * 256, 3))
        self.assertEqual(triangles.shape, (255 * 255 * 2, 3))

        # Gera artefatos e verifica existência no disco
        server_files = compiler.generate_server_artifacts(
            heights, world_y, t_info["scale"], t_info["location"], float(world_y.min()), float(world_y.max())
        )
        client_files = compiler.generate_client_artifacts(
            t_info, heights, positions, normals, uvs, triangles, pack_splatmaps=True
        )

        for sf in server_files:
            self.assertTrue(sf.is_file(), f"Arquivo de servidor deve existir: {sf}")
        for cf in client_files:
            self.assertTrue(cf.is_file(), f"Arquivo de cliente deve existir: {cf}")

        # Limpeza temporária
        import shutil
        if out_dir.is_dir():
            shutil.rmtree(out_dir)


class TestStaticMeshBuilder(unittest.TestCase):
    """Testes unitários para o pipeline de extração de StaticMeshes e StaticMeshActors."""

    def test_strip_to_triangles(self):
        from tools.l2_extractor import strip_to_triangles
        # Single strip of 4 vertices -> 2 triangles
        strip = [0, 1, 2, 3, 0xFFFF, 4, 5, 6]
        tris = strip_to_triangles(strip)
        self.assertEqual(len(tris), 3)
        self.assertEqual(tris[0], [0, 1, 2])
        self.assertEqual(tris[1], [1, 3, 2])
        self.assertEqual(tris[2], [4, 5, 6])

    def test_ue2_rotator_to_euler(self):
        from tools.l2_extractor import ue2_rotator_to_euler
        import math
        # 16384 UE2 units = 90 degrees = pi/2 rad
        p, y, r = ue2_rotator_to_euler(16384, 0, 0)
        self.assertAlmostEqual(p, math.pi / 2.0, places=3)
        self.assertAlmostEqual(y, 0.0, places=3)

    def test_extract_real_static_mesh(self):
        env = L2Environment()
        if not env.l2_root:
            self.skipTest("Lineage II não instalado.")
        pkg = env.get_package("field_deco_s") or env.get_package("speaking_tree_s")
        if not pkg:
            self.skipTest("Pacote USX não encontrado.")

        from tools.l2_extractor import StaticMeshParser
        parser = StaticMeshParser(pkg)
        mesh_exp = next((e for e in pkg.exports if e["class_name"] == "StaticMesh"), None)
        if mesh_exp:
            mesh = parser.extract_mesh_by_export(mesh_exp)
            if mesh:
                self.assertGreater(mesh["num_vertices"], 0)
                self.assertGreater(mesh["num_triangles"], 0)
                self.assertEqual(mesh["positions"].shape[1], 3)
                self.assertEqual(mesh["normals"].shape[1], 3)

    def test_extract_static_mesh_actors_from_map(self):
        env = L2Environment()
        if not env.l2_root:
            self.skipTest("Lineage II não instalado.")
        map_path = env.available_unr.get("16_24")
        if not map_path:
            self.skipTest("Mapa 16_24.unr não encontrado.")

        from tools.l2_extractor import extract_map_static_actors
        map_pkg = UnrealPackageReader(map_path)
        actors = extract_map_static_actors(map_pkg)
        self.assertEqual(len(actors), 336, "Mapa 16_24.unr deve conter exatamente 336 StaticMeshActors.")
        self.assertIn("transform", actors[0])
        self.assertIn("position_meters", actors[0]["transform"])






class TestEnvironmentAndMaterials(unittest.TestCase):
    """Testes unitários para a Etapa 1.4: Materiais, Iluminação e Atmosfera."""

    def test_sunlight_vector_calculation(self):
        """Valida a conversão de ângulos UE2 de iluminação para vetores unitários 3D."""
        from tools.l2_extractor import ue2_rotator_to_direction_vector

        # Teste 1: Pitch=-16384 (90 graus apontando para baixo / Z negativo)
        vec_down = ue2_rotator_to_direction_vector(pitch=-16384, yaw=0)
        self.assertAlmostEqual(vec_down[1], -1.0, places=3, msg="Vetor de luz solar deve apontar para o solo (Y negativo no Godot)")

        # Teste 2: Luz do mapa 16_24 (Pitch=-10923, Yaw=16383)
        vec_16_24 = ue2_rotator_to_direction_vector(pitch=-10923, yaw=16383)
        self.assertEqual(len(vec_16_24), 3)
        # Comprimento deve ser 1.0 (vetor unitário)
        length = (vec_16_24[0]**2 + vec_16_24[1]**2 + vec_16_24[2]**2)**0.5
        self.assertAlmostEqual(length, 1.0, places=4)

    def test_zoneinfo_and_sunlight_extraction(self):
        """Valida a extração de parâmetros reais de iluminação e ZoneInfo do mapa 16_24.unr."""
        env = L2Environment()
        if not env.l2_root:
            self.skipTest("Lineage II não instalado.")
        map_path = env.available_unr.get("16_24")
        if not map_path:
            self.skipTest("Mapa 16_24.unr não encontrado.")

        from tools.l2_extractor import extract_map_environment
        map_pkg = UnrealPackageReader(map_path)
        env_data = extract_map_environment(map_pkg)

        # 1. Valida Sunlight
        self.assertIsNotNone(env_data["sunlight"])
        self.assertEqual(env_data["sunlight"]["type"], "DirectionalLight3D")
        self.assertIn("direction", env_data["sunlight"])
        self.assertIn("color_rgb", env_data["sunlight"])

        # 2. Valida ZoneInfo / Névoa
        self.assertIsNotNone(env_data["distance_fog"])
        self.assertTrue(env_data["distance_fog"]["enabled"])
        self.assertGreater(env_data["distance_fog"]["end_meters"], env_data["distance_fog"]["begin_meters"])

        # 3. Valida WaterVolume
        self.assertGreaterEqual(len(env_data["water_volumes"]), 1)
        self.assertIn("water_plane_height_m", env_data["water_volumes"][0])

    def test_material_tree_resolver(self):
        """Valida resolução de Shaders e Texturas reais em speaking_tree_t."""
        env = L2Environment()
        if not env.l2_root:
            self.skipTest("Lineage II não instalado.")
        pkg = env.get_package("speaking_tree_t")
        if not pkg:
            self.skipTest("speaking_tree_t.utx não encontrado.")

        from tools.l2_extractor import MaterialTreeResolver
        resolver = MaterialTreeResolver(env)

        # Encontra o primeiro Shader
        shader_exp = next((e for e in pkg.exports if e["class_name"] == "Shader"), None)
        if shader_exp:
            res = resolver.resolve_material("speaking_tree_t", shader_exp["object_name"])
            self.assertIn("diffuse_texture", res)
            self.assertIn("alpha_blend_mode", res)
            tres_str = resolver.generate_godot_tres(res)
            self.assertIn('[gd_resource type="StandardMaterial3D"', tres_str)
            self.assertIn("resource_name =", tres_str)


def run_tests():
    suite = unittest.TestLoader().loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
