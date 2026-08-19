#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/material_builder.py — Resolvedor de Árvore de Materiais UE2 para Godot 4

Responsabilidades:
1. Navegação recursiva na árvore de materiais da Unreal Engine 2.5:
   - Shader: Diffuse, Specular, SpecularMask, Opacity.
   - FinalBlend: Blend modes (AlphaBlend, Translucent, Modulated, AlphaTest).
   - TexPanner / TexRotator: Propriedades de animação UV.
   - ColorModifier: Multiplicadores de cor e matiz.
2. Extração automática de texturas PNG associadas em assets/textures/<pacote>/<nome>.png.
3. Geração de receitas de materiais para Godot 4 (StandardMaterial3D e ShaderMaterial).
"""

import json
import os
import struct
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple, Union
from PIL import Image

from .package_reader import UnrealPackageReader
from .environment import L2Environment


class MaterialTreeResolver:
    """Resolve árvores de nós de materiais e shaders do Lineage II para materiais do Godot 4."""

    def __init__(self, env: L2Environment, textures_out_dir: Optional[Path] = None):
        self.env = env
        self.textures_out_dir = textures_out_dir or Path("assets/textures")
        self._material_cache: Dict[str, Dict[str, Any]] = {}

    def _resolve_object_ref(
        self,
        ref: Any,
        source_pkg: UnrealPackageReader,
    ) -> Optional[Tuple[UnrealPackageReader, Dict[str, Any]]]:
        """Resolve uma referência de export/import para o pacote e exportação correspondentes."""
        if not ref or not isinstance(ref, dict):
            return None

        ref_type = ref.get("type")
        if ref_type == "export":
            obj_name = ref.get("object_name")
            exp = next(
                (e for e in source_pkg.exports if e["object_name"].lower() == str(obj_name).lower()),
                None,
            )
            if exp:
                return (source_pkg, exp)
        elif ref_type == "import":
            pkg_name = ref.get("package")
            obj_name = ref.get("object_name")
            if pkg_name and obj_name:
                target_pkg = self.env.get_package(pkg_name)
                if target_pkg:
                    exp = next(
                        (e for e in target_pkg.exports if e["object_name"].lower() == str(obj_name).lower()),
                        None,
                    )
                    if exp:
                        return (target_pkg, exp)

        return None

    def resolve_material(
        self,
        pkg_name: str,
        material_name: str,
        visited: Optional[Set[str]] = None,
    ) -> Dict[str, Any]:
        """
        Analisa recursivamente o nó de material (Shader, FinalBlend, Texture, etc.)
        e retorna uma estrutura padronizada para o Godot 4.
        """
        cache_key = f"{pkg_name.lower()}.{material_name.lower()}"
        if cache_key in self._material_cache:
            return self._material_cache[cache_key]

        if visited is None:
            visited = set()
        if cache_key in visited:
            return {"name": material_name, "class": "Texture", "package": pkg_name}
        visited.add(cache_key)

        pkg = self.env.get_package(pkg_name)
        if not pkg:
            return {
                "name": material_name,
                "package": pkg_name,
                "class": "Unknown",
                "diffuse_texture": None,
            }

        exp = next(
            (e for e in pkg.exports if e["object_name"].lower() == material_name.lower()),
            None,
        )
        if not exp:
            return {
                "name": material_name,
                "package": pkg_name,
                "class": "Unknown",
                "diffuse_texture": None,
            }

        class_name = exp["class_name"]
        p_start = pkg.find_properties_start(exp["offset"], exp["size"])
        props = pkg.read_properties(p_start, exp["size"] - (p_start - exp["offset"]))

        result: Dict[str, Any] = {
            "name": material_name,
            "package": pkg_name,
            "class": class_name,
            "diffuse_texture": None,
            "opacity_texture": None,
            "specular_texture": None,
            "two_sided": False,
            "alpha_blend_mode": "Opaque",
            "alpha_test_threshold": 0.5,
            "uv_animation": None,
            "color_multiplier": [1.0, 1.0, 1.0, 1.0],
        }

        if class_name == "Texture":
            # Extrai imagem PNG
            png_path = self.extract_and_save_texture(pkg, material_name)
            result["diffuse_texture"] = str(png_path.as_posix()) if png_path else None
            # Verifica se possui canal Alpha ativo
            fmt = props.get("Format")
            if fmt in ("DXT3", "DXT5", "RGBA8"):
                result["alpha_blend_mode"] = "AlphaTest"
            result["two_sided"] = bool(props.get("bTwoSided", False))

        elif class_name == "Shader":
            result["two_sided"] = bool(props.get("TwoSided", False))

            # 1. Tenta carregar .mat pré-exportado pelo UModel se existir
            umodel_mat = self.textures_root.parent.parent / "UmodelExport" / pkg_name.lower() / "Shader" / f"{material_name}.mat"
            if not umodel_mat.is_file():
                # Tenta caminhos alternativos de UmodelExport
                for alt_root in [Path("UmodelExport"), Path(r"C:\Users\LEONARDO\Downloads\Compressed\umodel_win32\UmodelExport")]:
                    cand_mat = alt_root / pkg_name.lower() / "Shader" / f"{material_name}.mat"
                    if cand_mat.is_file():
                        umodel_mat = cand_mat
                        break

            if umodel_mat.is_file():
                mat_text = umodel_mat.read_text(encoding="utf-8", errors="ignore")
                mat_props = {}
                for line in mat_text.splitlines():
                    if "=" in line:
                        k, v = line.split("=", 1)
                        mat_props[k.strip().lower()] = v.strip()

                diff_name = mat_props.get("diffuse")
                if diff_name:
                    sub_res = self.resolve_material(pkg_name, diff_name, visited)
                    result["diffuse_texture"] = sub_res.get("diffuse_texture")

                op_name = mat_props.get("opacity")
                if op_name:
                    sub_res_op = self.resolve_material(pkg_name, op_name, visited)
                    result["opacity_texture"] = sub_res_op.get("diffuse_texture")
                    result["alpha_blend_mode"] = "AlphaTest"

                spec_name = mat_props.get("specular")
                if spec_name:
                    sub_res_spec = self.resolve_material(pkg_name, spec_name, visited)
                    result["specular_texture"] = sub_res_spec.get("diffuse_texture")
            else:
                # 2. Fallback: Se o nome do Shader termina com _1 (ex: Leaf21_1 -> leaf21), resolve o nome base
                base_cand = material_name
                if "_" in base_cand:
                    base_cand = base_cand.rsplit("_", 1)[0]
                if any(e["object_name"].lower() == base_cand.lower() for e in pkg.exports):
                    sub_res = self.resolve_material(pkg_name, base_cand, visited)
                    result["diffuse_texture"] = sub_res.get("diffuse_texture")
                    result["opacity_texture"] = sub_res.get("diffuse_texture")
                    result["alpha_blend_mode"] = "AlphaTest"

            # Diffuse via propriedades UE2 diretas
            diff_ref = props.get("Diffuse")
            if diff_ref:
                target = self._resolve_object_ref(diff_ref, pkg)
                if target:
                    sub_pkg, sub_exp = target
                    sub_res = self.resolve_material(
                        Path(sub_pkg.filepath).stem, sub_exp["object_name"], visited
                    )
                    result["diffuse_texture"] = sub_res.get("diffuse_texture")
                    if sub_res.get("uv_animation"):
                        result["uv_animation"] = sub_res["uv_animation"]

            # Opacity
            op_ref = props.get("Opacity")
            if op_ref:
                target = self._resolve_object_ref(op_ref, pkg)
                if target:
                    sub_pkg, sub_exp = target
                    sub_res = self.resolve_material(
                        Path(sub_pkg.filepath).stem, sub_exp["object_name"], visited
                    )
                    result["opacity_texture"] = sub_res.get("diffuse_texture")
                    result["alpha_blend_mode"] = "AlphaBlend"

            # Specular
            spec_ref = props.get("Specular")
            if spec_ref:
                target = self._resolve_object_ref(spec_ref, pkg)
                if target:
                    sub_pkg, sub_exp = target
                    sub_res = self.resolve_material(
                        Path(sub_pkg.filepath).stem, sub_exp["object_name"], visited
                    )
                    result["specular_texture"] = sub_res.get("diffuse_texture")

        elif class_name == "FinalBlend":
            frame_blend = props.get("FrameBufferBlending", 0)
            # 0=FB_Overwrite, 1=FB_Modulated, 2=FB_AlphaBlend, 3=FB_AlphaModulate, 4=FB_Translucent
            if frame_blend == 2:
                result["alpha_blend_mode"] = "AlphaBlend"
            elif frame_blend == 4:
                result["alpha_blend_mode"] = "Additive"
            elif frame_blend == 1:
                result["alpha_blend_mode"] = "Modulated"

            if props.get("ZWrite", True) is False:
                result["depth_draw"] = "Never"

            mat_ref = props.get("Material")
            if mat_ref:
                target = self._resolve_object_ref(mat_ref, pkg)
                if target:
                    sub_pkg, sub_exp = target
                    sub_res = self.resolve_material(
                        Path(sub_pkg.filepath).stem, sub_exp["object_name"], visited
                    )
                    result["diffuse_texture"] = sub_res.get("diffuse_texture")
                    result["two_sided"] = sub_res.get("two_sided", False)

        elif class_name in ("TexPanner", "TexRotator"):
            mat_ref = props.get("Material")
            if mat_ref:
                target = self._resolve_object_ref(mat_ref, pkg)
                if target:
                    sub_pkg, sub_exp = target
                    sub_res = self.resolve_material(
                        Path(sub_pkg.filepath).stem, sub_exp["object_name"], visited
                    )
                    result["diffuse_texture"] = sub_res.get("diffuse_texture")

            if class_name == "TexPanner":
                pan_rate = props.get("PanRate", 0.1)
                pan_dir = props.get("PanDirection", [1.0, 0.0])
                result["uv_animation"] = {
                    "type": "panner",
                    "rate": pan_rate,
                    "direction": pan_dir,
                }
            else:
                rot_rate = props.get("Rotation", 0.1)
                result["uv_animation"] = {"type": "rotator", "rate": rot_rate}

        elif class_name == "ColorModifier":
            color = props.get("Color", [255, 255, 255, 255])
            if isinstance(color, (list, tuple)) and len(color) >= 3:
                result["color_multiplier"] = [
                    color[0] / 255.0,
                    color[1] / 255.0,
                    color[2] / 255.0,
                    color[3] / 255.0 if len(color) > 3 else 1.0,
                ]

            mat_ref = props.get("Material")
            if mat_ref:
                target = self._resolve_object_ref(mat_ref, pkg)
                if target:
                    sub_pkg, sub_exp = target
                    sub_res = self.resolve_material(
                        Path(sub_pkg.filepath).stem, sub_exp["object_name"], visited
                    )
                    result["diffuse_texture"] = sub_res.get("diffuse_texture")

        self._material_cache[cache_key] = result
        return result

    def extract_and_save_texture(
        self, pkg: UnrealPackageReader, texture_name: str
    ) -> Optional[Path]:
        """Extrai imagem de textura de um pacote para arquivo PNG no disco."""
        pkg_name = Path(pkg.filepath).stem.lower()
        out_pkg_dir = self.textures_out_dir / pkg_name
        out_png = out_pkg_dir / f"{texture_name}.png"

        if out_png.is_file():
            return out_png

        img = pkg.extract_image_by_export_name(texture_name)
        if img:
            out_pkg_dir.mkdir(parents=True, exist_ok=True)
            img.save(out_png, "PNG")
            return out_png

        return None

    def generate_godot_tres(self, material_info: Dict[str, Any]) -> str:
        """Gera o texto de um recurso StandardMaterial3D (.tres) nativo do Godot 4."""
        name = material_info["name"]
        diffuse_path = material_info.get("diffuse_texture")
        two_sided = material_info.get("two_sided", False)
        blend_mode = material_info.get("alpha_blend_mode", "Opaque")
        color = material_info.get("color_multiplier", [1.0, 1.0, 1.0, 1.0])

        lines = [
            '[gd_resource type="StandardMaterial3D" format=3]',
            "",
            "[resource]",
            f'resource_name = "{name}"',
        ]

        if two_sided:
            lines.append("cull_mode = 2")  # Disabled / Two-sided

        if blend_mode == "AlphaTest":
            lines.append("transparency = 2")  # Alpha Scissor
            lines.append(f"alpha_scissor_threshold = {material_info.get('alpha_test_threshold', 0.5)}")
        elif blend_mode == "AlphaBlend":
            lines.append("transparency = 1")  # Alpha Blend
        elif blend_mode == "Additive":
            lines.append("blend_mode = 1")  # Additive

        if color != [1.0, 1.0, 1.0, 1.0]:
            lines.append(f"albedo_color = Color({color[0]:.4f}, {color[1]:.4f}, {color[2]:.4f}, {color[3]:.4f})")

        if diffuse_path:
            # Caminho relativo para res://
            rel_path = Path(diffuse_path).as_posix()
            lines.append(f'albedo_texture = ExtResource("res://{rel_path}")')

        return "\n".join(lines) + "\n"
