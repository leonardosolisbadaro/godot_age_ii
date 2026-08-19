#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/package_reader.py — Leitor e Parser de Pacotes Unreal Engine 2 (.UNR / .UTX / .USX / .U)

Analisa a estrutura interna de pacotes da UE2:
- Tabela de Nomes (ASCII / UTF-16)
- Tabela de Importações (Hierarquia de pacotes e classes)
- Tabela de Exportações (Tamanho serializado, offset, flags e outers)
- Serializador de Propriedades (Structs, Vetores, Rotators, Arrays e Referências)
- Extração de Paletas e Texturas
"""

from pathlib import Path
import struct
from typing import Any, Dict, List, Optional, Tuple, Union
import numpy as np
from PIL import Image

from .decryptor import L2Decryptor
from .texture_decoder import (
    decode_dxt1,
    decode_dxt3,
    decode_dxt5,
    decode_g8,
    decode_p8,
    decode_rgba8,
)


class UnrealPackageReader:
    """Parser de baixo nível para arquivos de pacote da Unreal Engine 2."""

    def __init__(self, filepath: Union[str, Path]):
        self.filepath = Path(filepath).resolve()
        raw = self.filepath.read_bytes()
        self.data = L2Decryptor.decrypt(raw)
        self.pos = 0
        self.names: List[str] = []
        self.exports: List[Dict[str, Any]] = []
        self.imports: List[Dict[str, Any]] = []
        self._parse_header()

    def _parse_header(self) -> None:
        (
            self.tag,
            self.file_version,
            self.pkg_flags,
        ) = struct.unpack_from("<III", self.data, 0)
        self.pos = 12
        name_count, name_offset = struct.unpack_from("<II", self.data, self.pos)
        self.pos += 8
        export_count, export_offset = struct.unpack_from("<II", self.data, self.pos)
        self.pos += 8
        import_count, import_offset = struct.unpack_from("<II", self.data, self.pos)
        self.pos += 8

        self._read_names(name_count, name_offset)
        self._read_imports(import_count, import_offset)
        self._read_exports(export_count, export_offset)

    def read_compact_index(self, offset: Optional[int] = None) -> int:
        """Lê um inteiro de tamanho variável (CompactIndex da UE2)."""
        if offset is not None:
            self.pos = offset
        b0 = self.data[self.pos]
        self.pos += 1
        sign = b0 & 0x80
        more = b0 & 0x40
        value = b0 & 0x3F

        if more:
            b1 = self.data[self.pos]
            self.pos += 1
            more = b1 & 0x80
            value |= (b1 & 0x7F) << 6
            if more:
                b2 = self.data[self.pos]
                self.pos += 1
                more = b2 & 0x80
                value |= (b2 & 0x7F) << 13
                if more:
                    b3 = self.data[self.pos]
                    self.pos += 1
                    more = b3 & 0x80
                    value |= (b3 & 0x7F) << 20
                    if more:
                        b4 = self.data[self.pos]
                        self.pos += 1
                        value |= (b4 & 0x1F) << 27
        return -value if sign else value

    def _read_names(self, count: int, offset: int) -> None:
        self.pos = offset
        for _ in range(count):
            length = self.read_compact_index()
            if length > 0:
                name_str = self.data[self.pos : self.pos + length - 1].decode(
                    "latin-1", errors="replace"
                )
                self.pos += length
            elif length < 0:
                utf16_len = -length * 2
                name_str = self.data[self.pos : self.pos + utf16_len - 2].decode(
                    "utf-16le", errors="replace"
                )
                self.pos += utf16_len
            else:
                name_str = ""
            self.pos += 4  # Flags do nome (uint32)
            self.names.append(name_str)

    def _read_imports(self, count: int, offset: int) -> None:
        self.pos = offset
        for _ in range(count):
            class_pkg = self.read_compact_index()
            class_name = self.read_compact_index()
            outer = struct.unpack_from("<i", self.data, self.pos)[0]
            self.pos += 4
            obj_name = self.read_compact_index()
            self.imports.append(
                {
                    "class_package": (
                        self.names[class_pkg] if 0 <= class_pkg < len(self.names) else ""
                    ),
                    "class_name": (
                        self.names[class_name] if 0 <= class_name < len(self.names) else ""
                    ),
                    "outer": outer,
                    "object_name": (
                        self.names[obj_name] if 0 <= obj_name < len(self.names) else ""
                    ),
                }
            )

    def _read_exports(self, count: int, offset: int) -> None:
        self.pos = offset
        for _ in range(count):
            class_idx = self.read_compact_index()
            _super_idx = self.read_compact_index()
            outer_idx = struct.unpack_from("<i", self.data, self.pos)[0]
            self.pos += 4
            name_idx = self.read_compact_index()
            flags = struct.unpack_from("<I", self.data, self.pos)[0]
            self.pos += 4
            serial_size = self.read_compact_index()
            serial_offset = self.read_compact_index() if serial_size > 0 else 0

            class_name = "Class"
            if class_idx < 0:
                imp_idx = -class_idx - 1
                if 0 <= imp_idx < len(self.imports):
                    class_name = self.imports[imp_idx]["object_name"]
            elif class_idx > 0:
                exp_idx = class_idx - 1
                if 0 <= exp_idx < len(self.exports):
                    class_name = self.exports[exp_idx]["object_name"]

            obj_name = (
                self.names[name_idx]
                if 0 <= name_idx < len(self.names)
                else f"Export_{len(self.exports)}"
            )
            self.exports.append(
                {
                    "class_name": class_name,
                    "object_name": obj_name,
                    "class_idx": class_idx,
                    "outer": outer_idx,
                    "size": serial_size,
                    "offset": serial_offset,
                    "flags": flags,
                }
            )

    def resolve_object_reference(self, index: int) -> Optional[Dict[str, Any]]:
        """Resolve um índice de objeto (+ para Export, - para Import, 0 para None)."""
        if index == 0:
            return None
        chain = []
        curr = index
        class_name = ""

        if curr < 0:
            while curr < 0:
                imp_idx = -curr - 1
                if 0 <= imp_idx < len(self.imports):
                    imp = self.imports[imp_idx]
                    chain.append(imp["object_name"])
                    if not class_name:
                        class_name = imp["class_name"]
                    curr = imp["outer"]
                else:
                    break
            chain.reverse()
            pkg_name = (
                chain[0]
                if len(chain) > 1
                else (
                    self.imports[-index - 1]["class_package"]
                    if 0 <= -index - 1 < len(self.imports)
                    else ""
                )
            )
            return {
                "type": "import",
                "package": pkg_name,
                "object_name": chain[-1] if chain else "",
                "class_name": class_name,
                "full_path": ".".join(chain),
            }
        else:
            exp_idx = curr - 1
            if 0 <= exp_idx < len(self.exports):
                exp = self.exports[exp_idx]
                chain.append(exp["object_name"])
                class_name = exp["class_name"]
                outer = exp.get("outer", 0)
                while outer > 0:
                    p_idx = outer - 1
                    if 0 <= p_idx < len(self.exports):
                        p_exp = self.exports[p_idx]
                        chain.append(p_exp["object_name"])
                        outer = p_exp.get("outer", 0)
                    else:
                        break
            chain.reverse()
            return {
                "type": "export",
                "package": self.filepath.stem,
                "object_name": chain[-1] if chain else "",
                "class_name": class_name,
                "full_path": ".".join(chain),
            }

    def find_properties_start(self, exp_offset: int, exp_size: int) -> int:
        """Localiza o offset de início da lista de propriedades serializadas."""
        strong_initial_props = {
            "TerrainMap",
            "TerrainScale",
            "Layers",
            "StaticMesh",
            "Location",
            "Rotation",
            "Format",
            "Palette",
            "USize",
            "VSize",
            "Tag",
            "bHidden",
            "bStaticLighting",
            "TerrainSectorSize",
        }
        limit = min(exp_offset + 96, exp_offset + exp_size)
        for offset in range(exp_offset, limit):
            self.pos = offset
            try:
                name_idx = self.read_compact_index()
                if 0 <= name_idx < len(self.names):
                    prop_name = self.names[name_idx]
                    if prop_name in strong_initial_props:
                        info_byte = self.data[self.pos]
                        prop_type = info_byte & 0x0F
                        if 1 <= prop_type <= 14:
                            return offset
            except Exception:
                pass
        return exp_offset

    def read_properties(self, start_offset: int, max_bytes: int) -> Dict[str, Any]:
        """Lê e deserializa todas as propriedades de um objeto exportado."""
        self.pos = start_offset
        limit = start_offset + max_bytes
        props: Dict[str, Any] = {}

        while self.pos < limit:
            name_idx = self.read_compact_index()
            if name_idx < 0 or name_idx >= len(self.names):
                break
            prop_name = self.names[name_idx]
            if prop_name == "None":
                break

            info_byte = self.data[self.pos]
            self.pos += 1
            prop_type = info_byte & 0x0F
            size_type = (info_byte >> 4) & 0x07
            is_array = (info_byte >> 7) & 0x01

            struct_name = ""
            if prop_type == 10:  # StructProperty
                struct_name_idx = self.read_compact_index()
                struct_name = (
                    self.names[struct_name_idx]
                    if 0 <= struct_name_idx < len(self.names)
                    else ""
                )

            size = 0
            if size_type == 0:
                size = 1
            elif size_type == 1:
                size = 2
            elif size_type == 2:
                size = 4
            elif size_type == 3:
                size = 12
            elif size_type == 4:
                size = 16
            elif size_type == 5:
                size = self.data[self.pos]
                self.pos += 1
            elif size_type == 6:
                size = struct.unpack_from("<H", self.data, self.pos)[0]
                self.pos += 2
            elif size_type == 7:
                size = struct.unpack_from("<I", self.data, self.pos)[0]
                self.pos += 4

            array_index = 0
            if is_array and prop_type != 3:
                array_index = self.read_compact_index()

            prop_data_start = self.pos
            val: Any = None

            if prop_type == 1:  # ByteProperty
                if size == 1:
                    val = self.data[self.pos]
                else:
                    idx = self.read_compact_index()
                    val = self.names[idx] if 0 <= idx < len(self.names) else ""
            elif prop_type == 2:  # IntProperty
                val = struct.unpack_from("<i", self.data, self.pos)[0]
            elif prop_type == 3:  # BoolProperty
                val = bool(is_array)
            elif prop_type == 4:  # FloatProperty
                val = struct.unpack_from("<f", self.data, self.pos)[0]
            elif prop_type == 5:  # ObjectProperty
                val = self.resolve_object_reference(self.read_compact_index())
            elif prop_type == 6:  # NameProperty
                idx = self.read_compact_index()
                val = self.names[idx] if 0 <= idx < len(self.names) else ""
            elif prop_type == 10:  # StructProperty
                payload_len = prop_data_start + size - self.pos
                if struct_name == "Vector" and payload_len >= 12:
                    val = struct.unpack_from("<fff", self.data, self.pos)
                elif struct_name == "Rotator" and payload_len >= 12:
                    val = struct.unpack_from("<iii", self.data, self.pos)
                elif struct_name == "Color" and payload_len >= 4:
                    val = struct.unpack_from("<BBBB", self.data, self.pos)
                elif struct_name == "Plane" and payload_len >= 16:
                    v = struct.unpack_from("<ffff", self.data, self.pos)
                    val = {"X": v[0], "Y": v[1], "Z": v[2], "W": v[3]}
                elif struct_name == "Matrix" and payload_len >= 64:
                    m = struct.unpack_from("<ffffffffffffffff", self.data, self.pos)
                    val = {
                        "XPlane": {"X": m[0], "Y": m[1], "Z": m[2], "W": m[3]},
                        "YPlane": {"X": m[4], "Y": m[5], "Z": m[6], "W": m[7]},
                        "ZPlane": {"X": m[8], "Y": m[9], "Z": m[10], "W": m[11]},
                        "WPlane": {"X": m[12], "Y": m[13], "Z": m[14], "W": m[15]},
                    }
                elif struct_name == "Box" and payload_len >= 25:
                    min_v = struct.unpack_from("<fff", self.data, self.pos)
                    max_v = struct.unpack_from("<fff", self.data, self.pos + 12)
                    is_valid = self.data[self.pos + 24]
                    val = {"Min": min_v, "Max": max_v, "IsValid": is_valid}
                else:
                    val = self.read_properties(self.pos, payload_len)
            elif prop_type == 11:  # VectorProperty
                val = struct.unpack_from("<fff", self.data, self.pos)
            elif prop_type == 12:  # RotatorProperty
                val = struct.unpack_from("<iii", self.data, self.pos)
            elif prop_type == 13:  # StrProperty
                s_len = self.read_compact_index()
                if s_len > 0:
                    val = self.data[self.pos : self.pos + s_len - 1].decode(
                        "latin-1", errors="replace"
                    )
                elif s_len < 0:
                    val = self.data[self.pos : self.pos + (-s_len * 2) - 2].decode(
                        "utf-16le", errors="replace"
                    )
                else:
                    val = ""

            self.pos = prop_data_start + size

            if prop_name not in props:
                if is_array or array_index > 0:
                    props[prop_name] = {"_is_array": True, array_index: val}
                else:
                    props[prop_name] = val
            else:
                if not isinstance(props[prop_name], dict) or not props[prop_name].get(
                    "_is_array"
                ):
                    old_v = props[prop_name]
                    props[prop_name] = {"_is_array": True, 0: old_v}
                props[prop_name][array_index] = val

        return props

    def extract_palette(self, pal_ref: Any) -> Optional[List[Tuple[int, int, int, int]]]:
        """Extrai a tabela de 256 cores (RGBA) de um Palette exportado."""
        if not pal_ref:
            return None
        pal_name = (
            pal_ref.get("object_name") if isinstance(pal_ref, dict) else str(pal_ref)
        )
        if not pal_name:
            return None
        clean_name = str(pal_name).lower().split(".")[-1]
        matched = next(
            (e for e in self.exports if e["object_name"].lower() == clean_name), None
        )
        if not matched:
            matched = next(
                (e for e in self.exports if clean_name in e["object_name"].lower()),
                None,
            )
        if not matched:
            return None
        pal_data = self.data[matched["offset"] : matched["offset"] + matched["size"]]
        if len(pal_data) >= 1024:
            raw_colors = pal_data[-1024:]
            palette = []
            for i in range(0, 1024, 4):
                r, g, b, a = struct.unpack_from("<BBBB", raw_colors, i)
                palette.append((r, g, b, a))
            return palette
        return None

    def extract_image_by_export_name(self, target_name: str) -> Optional[Image.Image]:
        """Extrai e decodifica a imagem de uma textura pelo nome do Export."""
        if not target_name:
            return None
        clean_target = target_name.lower().split(".")[-1]

        matched = next(
            (e for e in self.exports if e["object_name"].lower() == clean_target), None
        )
        if not matched:
            matched = next(
                (e for e in self.exports if clean_target in e["object_name"].lower()),
                None,
            )
        if not matched:
            return None

        # 1. Lê propriedades para inspecionar formato e dimensões declaradas
        prop_start = self.find_properties_start(matched["offset"], matched["size"])
        props = self.read_properties(
            prop_start, matched["size"] - (prop_start - matched["offset"])
        )

        # 2. Desembrulha Shaders e Materiais da UE2 (Diffuse / Material)
        if matched["class_name"] in (
            "Shader",
            "FinalBlend",
            "Combiner",
            "Material",
            "TexPanner",
            "TexRotator",
            "ColorModifier",
        ):
            diff_ref = (
                props.get("Diffuse")
                or props.get("Material")
                or props.get("Material1")
                or props.get("Alpha")
            )
            if isinstance(diff_ref, dict) and diff_ref.get("_is_array"):
                diff_ref = diff_ref.get(0)
            if isinstance(diff_ref, dict) and "object_name" in diff_ref:
                return self.extract_image_by_export_name(diff_ref["object_name"])

        format_val = props.get("Format")
        u_size = props.get("USize", 0)
        v_size = props.get("VSize", 0)
        pal_ref = props.get("Palette")

        exp_data = self.data[matched["offset"] : matched["offset"] + matched["size"]]

        target_resolutions = []
        if (
            isinstance(u_size, int)
            and isinstance(v_size, int)
            and u_size > 0
            and v_size > 0
        ):
            target_resolutions.append((u_size, v_size))
        for res in [2048, 1024, 512, 256, 128, 64, 32, 16]:
            if (res, res) not in target_resolutions:
                target_resolutions.append((res, res))

        for rw, rh in target_resolutions:
            footer_pattern = struct.pack("<II", rw, rh)
            pos = exp_data.rfind(footer_pattern)
            if pos != -1:
                # 1. P8 / Paletizado 8-bit (Format 0, None ou possui Palette declarada)
                if pal_ref is not None or format_val in (0, None):
                    p8_sz = rw * rh
                    if pos >= p8_sz:
                        pal_colors = self.extract_palette(pal_ref) if pal_ref else None
                        raw_indices = exp_data[pos - p8_sz : pos]
                        img = decode_p8(raw_indices, rw, rh, pal_colors)
                        if img:
                            return img

                # 2. DXT1 (Format 3)
                if format_val == 3:
                    dxt1_sz = (rw * rh) // 2
                    if pos >= dxt1_sz:
                        img = decode_dxt1(exp_data[pos - dxt1_sz : pos], rw, rh)
                        if img:
                            return img

                # 3. DXT3 (Format 5)
                if format_val == 5:
                    dxt3_sz = rw * rh
                    if pos >= dxt3_sz:
                        img = decode_dxt3(exp_data[pos - dxt3_sz : pos], rw, rh)
                        if img:
                            return img

                # 4. DXT5 (Format 6 ou 7 em Lineage II UE2.5)
                if format_val in (6, 7):
                    dxt5_sz = rw * rh
                    if pos >= dxt5_sz:
                        img = decode_dxt5(exp_data[pos - dxt5_sz : pos], rw, rh)
                        if img:
                            return img

                # 5. G16 / Heightfield 16-bit (Format 8 ou 131072 bytes para 256x256)
                if format_val == 8 or (rw == 256 and rh == 256 and pos >= 131072):
                    g16_raw = exp_data[pos - 131072 : pos]
                    arr = np.frombuffer(g16_raw, dtype="<u2").reshape((rh, rw))
                    return Image.fromarray(arr)

                # 6. G8 / Grayscale
                g8_sz = rw * rh
                if pos >= g8_sz:
                    img = decode_g8(exp_data[pos - g8_sz : pos], rw, rh)
                    if img:
                        return img

                # 7. RGBA8 (Format 1 ou 4)
                if format_val in (1, 4):
                    rgba_sz = rw * rh * 4
                    if pos >= rgba_sz:
                        img = decode_rgba8(exp_data[pos - rgba_sz : pos], rw, rh)
                        if img:
                            return img

                # Fallback DXT1 / DXT5
                dxt1_sz = (rw * rh) // 2
                if pos >= dxt1_sz:
                    img = decode_dxt1(exp_data[pos - dxt1_sz : pos], rw, rh)
                    if img:
                        return img

        return None
