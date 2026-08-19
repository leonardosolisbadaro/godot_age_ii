#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/environment_builder.py — Extrator de Iluminação, Atmosfera e Água

Responsabilidades:
1. Extração de atores de iluminação solar e pontual (NMovableSunLight, Sunlight, Light):
   - Conversão de rotação UE2 (Yaw/Pitch) para vetor 3D de direção de luz no Godot (DirectionalLight3D).
   - Conversão de cores RGB e intensidade.
2. Extração de parâmetros ambientais de ZoneInfo:
   - Luz ambiente (AmbientLightColor).
   - Névoa de distância (DistanceFogColor, DistanceFogStart, DistanceFogEnd em metros).
3. Extração de SkyZoneInfo e NMoon para ciclo de céu e atmosfera.
4. Extração de volumes de água (WaterVolume, FluidSurfaceInfo) para física e renderização.
"""

import json
import math
import struct
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union

from .package_reader import UnrealPackageReader
from .static_mesh_builder import UU_TO_METERS_DEFAULT, ue2_rotator_to_euler


def ue2_rotator_to_direction_vector(pitch: int, yaw: int, roll: int = 0) -> List[float]:
    """
    Converte rotação angular de ator de luz da UE2 (65536 unidades = 360 graus)
    para o vetor unitário 3D de direção de luz que o Godot espera.
    """
    # Na UE2: Yaw gira no plano horizontal em torno do eixo Z (altura)
    # Pitch inclina para cima/baixo em torno do eixo Y
    # 65536 = 2 * PI radianos
    p_rad = (pitch / 65536.0) * 2.0 * math.pi
    y_rad = (yaw / 65536.0) * 2.0 * math.pi

    # Vetor de apontamento na UE2 (X=Frente, Y=Direita, Z=Cima)
    dx_ue = math.cos(p_rad) * math.cos(y_rad)
    dy_ue = math.cos(p_rad) * math.sin(y_rad)
    dz_ue = math.sin(p_rad)

    # Conversão canônica para Godot (X_godot = X_ue, Y_godot = Z_ue, Z_godot = Y_ue)
    dx_godot = dx_ue
    dy_godot = dz_ue
    dz_godot = dy_ue

    length = math.sqrt(dx_godot**2 + dy_godot**2 + dz_godot**2)
    if length > 0.00001:
        return [dx_godot / length, dy_godot / length, dz_godot / length]
    return [0.0, -1.0, 0.0]


def extract_map_environment(
    map_pkg: UnrealPackageReader,
    unit_scale: float = UU_TO_METERS_DEFAULT,
) -> Dict[str, Any]:
    """
    Analisa um arquivo .unr e extrai todos os parâmetros de atmosfera, luz solar,
    ZoneInfo e volumes de água.
    """
    env_data: Dict[str, Any] = {
        "sunlight": None,
        "moonlight": None,
        "ambient_lighting": None,
        "distance_fog": None,
        "sky_info": None,
        "water_volumes": [],
        "point_lights": [],
    }

    for exp in map_pkg.exports:
        c_name = exp["class_name"]
        o_name = exp["object_name"]

        if c_name in (
            "NMovableSunLight",
            "Sunlight",
            "ZoneInfo",
            "SkyZoneInfo",
            "WaterVolume",
            "NMoon",
            "Light",
        ):
            p_start = map_pkg.find_properties_start(exp["offset"], exp["size"])
            props = map_pkg.read_properties(
                p_start, exp["size"] - (p_start - exp["offset"])
            )

            # 1. Luz Solar Principal
            if c_name in ("NMovableSunLight", "Sunlight") and env_data["sunlight"] is None:
                rot = props.get("Rotation", [0, 0, 0])
                p_val, y_val, r_val = (
                    int(rot[0]) if len(rot) > 0 else 0,
                    int(rot[1]) if len(rot) > 1 else 0,
                    int(rot[2]) if len(rot) > 2 else 0,
                )
                dir_vec = ue2_rotator_to_direction_vector(p_val, y_val, r_val)
                tex_mod = props.get("TexModifyInfo", {})
                color = tex_mod.get("Color", [255, 245, 230, 255])
                brightness = float(props.get("LightBrightness", 1.0))
                if brightness <= 0.01:
                    brightness = 1.0

                env_data["sunlight"] = {
                    "name": o_name,
                    "type": "DirectionalLight3D",
                    "direction": [round(c, 5) for c in dir_vec],
                    "color_rgb": [
                        round(color[0] / 255.0, 4),
                        round(color[1] / 255.0, 4),
                        round(color[2] / 255.0, 4),
                    ],
                    "energy": round(brightness, 2),
                    "rotator_ue2": [p_val, y_val, r_val],
                }

            # 2. Lua / Luz Noturna
            elif c_name == "NMoon" and env_data["moonlight"] is None:
                loc = props.get("Location", [0.0, 0.0, 0.0])
                pos_m = [
                    round(loc[0] * unit_scale, 2),
                    round(loc[2] * unit_scale, 2),
                    round(loc[1] * unit_scale, 2),
                ]
                tex_mod = props.get("TexModifyInfo", {})
                color = tex_mod.get("Color", [200, 220, 255, 255])

                env_data["moonlight"] = {
                    "name": o_name,
                    "position_m": pos_m,
                    "color_rgb": [
                        round(color[0] / 255.0, 4),
                        round(color[1] / 255.0, 4),
                        round(color[2] / 255.0, 4),
                    ],
                }

            # 3. ZoneInfo (Névoa e Luz Ambiente)
            elif c_name == "ZoneInfo":
                # Fog
                fog_color = props.get("DistanceFogColor", [180, 200, 220, 255])
                fog_start = float(props.get("DistanceFogStart", 1000.0)) * unit_scale
                fog_end = float(props.get("DistanceFogEnd", 80000.0)) * unit_scale
                if fog_end <= fog_start:
                    fog_end = 800.0  # Fallback de 800m

                env_data["distance_fog"] = {
                    "enabled": True,
                    "color_rgb": [
                        round(fog_color[0] / 255.0, 4),
                        round(fog_color[1] / 255.0, 4),
                        round(fog_color[2] / 255.0, 4),
                    ],
                    "begin_meters": round(fog_start, 2),
                    "end_meters": round(fog_end, 2),
                }

                # Luz ambiente
                amb_color = props.get("AmbientLightColor", [120, 130, 140, 255])
                env_data["ambient_lighting"] = {
                    "color_rgb": [
                        round(amb_color[0] / 255.0, 4),
                        round(amb_color[1] / 255.0, 4),
                        round(amb_color[2] / 255.0, 4),
                    ],
                    "energy": 0.5,
                }

            # 4. SkyZoneInfo
            elif c_name == "SkyZoneInfo" and env_data["sky_info"] is None:
                loc = props.get("Location", [0.0, 0.0, 0.0])
                env_data["sky_info"] = {
                    "name": o_name,
                    "camera_location_m": [
                        round(loc[0] * unit_scale, 2),
                        round(loc[2] * unit_scale, 2),
                        round(loc[1] * unit_scale, 2),
                    ],
                }

            # 5. WaterVolume
            elif c_name == "WaterVolume":
                loc = props.get("Location", [0.0, 0.0, 0.0])
                water_z = loc[2] * unit_scale if len(loc) > 2 else -10.0
                env_data["water_volumes"].append(
                    {
                        "name": o_name,
                        "water_plane_height_m": round(water_z, 2),
                        "fluid_friction": float(props.get("FluidFriction", 1.2)),
                        "b_water_volume": True,
                    }
                )

            # 6. Luzes Pontuais (Tochas, Postes, Fontes)
            elif c_name == "Light":
                loc = props.get("Location", [0.0, 0.0, 0.0])
                color = props.get("LightColor", [255, 220, 180])
                radius = float(props.get("LightRadius", 64.0)) * unit_scale * 10.0
                brightness = float(props.get("LightBrightness", 1.0))
                env_data["point_lights"].append(
                    {
                        "name": o_name,
                        "position_m": [
                            round(loc[0] * unit_scale, 2),
                            round(loc[2] * unit_scale, 2),
                            round(loc[1] * unit_scale, 2),
                        ],
                        "color_rgb": [
                            round(color[0] / 255.0, 4),
                            round(color[1] / 255.0, 4),
                            round(color[2] / 255.0, 4),
                        ],
                        "radius_meters": round(radius, 2),
                        "energy": round(brightness, 2),
                    }
                )

    # Defaults caso algum parâmetro não tenha sido declarado no mapa
    if env_data["sunlight"] is None:
        env_data["sunlight"] = {
            "name": "DefaultSunlight",
            "type": "DirectionalLight3D",
            "direction": [-0.5, -0.8, -0.3],
            "color_rgb": [1.0, 0.95, 0.88],
            "energy": 1.2,
        }

    if env_data["distance_fog"] is None:
        env_data["distance_fog"] = {
            "enabled": True,
            "color_rgb": [0.65, 0.75, 0.85],
            "begin_meters": 50.0,
            "end_meters": 1200.0,
        }

    if env_data["ambient_lighting"] is None:
        env_data["ambient_lighting"] = {
            "color_rgb": [0.4, 0.45, 0.5],
            "energy": 0.4,
        }

    return env_data
