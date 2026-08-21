#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/environment_builder.py — Extrator de Iluminação, Atmosfera e Água

@description
Responsabilidades:
1. Extração de atores de iluminação solar e pontual (NMovableSunLight, Sunlight, Light):
   - Conversão de rotação UE2 (Yaw/Pitch) para vetor 3D de direção de luz no Godot (DirectionalLight3D).
   - Conversão de cores RGB e intensidade calibrada.
2. Extração de parâmetros ambientais de ZoneInfo:
   - Luz ambiente (AmbientLightColor, energia).
   - Névoa de distância (DistanceFogColor, DistanceFogStart, DistanceFogEnd em metros).
3. Extração de SkyZoneInfo e NMoon para ciclo de céu e atmosfera.
4. Extração de volumes de água (WaterVolume, FluidSurfaceInfo) para física autoritativa e renderização.

@created 2026-08-18
@updated 2026-08-20
@author Leonardo S. Badaró
"""

import json
import math
from pathlib import Path
import struct
from typing import Any, Dict, List, Optional, Tuple, Union

from .config import (
    PipelineConfig,
    UE2_ROTATOR_FULL_CIRCLE,
    UU_TO_METERS_CANONICAL,
)
from .package_reader import UnrealPackageReader


# ==============================================================================
# CONSTANTES SEMÂNTICAS DE AMBIENTE E ILUMINAÇÃO
# ==============================================================================

## @const DEFAULT_SUN_DIRECTION (List[float])
## O que: Vetor 3D normalizado de direção padrão para iluminação solar no Godot ([-0.5, -0.8, -0.3]).
## Porque: Aponta em ângulo oblíquo para baixo iluminando o terreno uniformemente.
DEFAULT_SUN_DIRECTION: List[float] = [-0.5, -0.8, -0.3]

## @const DEFAULT_SUN_COLOR_RGB (List[float])
## O que: Cor albedo padrão do sol em RGB normalizado ([1.0, 0.95, 0.88]).
## Porque: Temperatura de cor solar levemente aquecida (luz natural).
DEFAULT_SUN_COLOR_RGB: List[float] = [1.0, 0.95, 0.88]

## @const DEFAULT_FOG_BEGIN_METERS (float)
## O que: Distância inicial padrão em metros para o início da névoa de distância (50.0m).
## Porque: Mantém o entorno imediato do avatar perfeitamente nítido.
DEFAULT_FOG_BEGIN_METERS: float = 50.0

## @const DEFAULT_FOG_END_METERS (float)
## O que: Distância máxima padrão em metros para opacidade total da névoa (1200.0m).
## Porque: Oculta o fim do raio de visão dos chunks de forma suave no horizonte.
DEFAULT_FOG_END_METERS: float = 1200.0


def ue2_rotator_to_direction_vector(pitch: int, yaw: int, roll: int = 0) -> List[float]:
    """
    Converte rotação angular de ator de luz da UE2 (65536 unidades = 360 graus)
    para o vetor unitário 3D de direção de luz que o Godot espera.
    """
    p_rad = (pitch / UE2_ROTATOR_FULL_CIRCLE) * 2.0 * math.pi
    y_rad = (yaw / UE2_ROTATOR_FULL_CIRCLE) * 2.0 * math.pi

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


def _safe_get_vector3(val: Any, default: Tuple[float, float, float] = (0.0, 0.0, 0.0)) -> Tuple[float, float, float]:
    """Extrai com segurança uma tripla de coordenadas (X, Y, Z) de qualquer estrutura."""
    if val is None:
        return default
    if isinstance(val, dict) and val.get("_is_array"):
        val = val.get(0, default)
    if isinstance(val, (list, tuple)):
        if len(val) > 0 and isinstance(val[0], (list, tuple)):
            val = val[0]
        try:
            x = float(val[0]) if len(val) > 0 and val[0] is not None else default[0]
            y = float(val[1]) if len(val) > 1 and val[1] is not None else default[1]
            z = float(val[2]) if len(val) > 2 and val[2] is not None else default[2]
            return (x, y, z)
        except (ValueError, TypeError, IndexError):
            return default
    return default


def _safe_get_color(val: Any, default: Tuple[int, int, int] = (255, 255, 255)) -> Tuple[int, int, int]:
    """Extrai com segurança uma tripla de cores RGB [0..255]."""
    if val is None:
        return default
    if isinstance(val, dict) and val.get("_is_array"):
        val = val.get(0, default)
    if isinstance(val, (list, tuple)):
        try:
            r = int(val[0]) if len(val) > 0 and val[0] is not None else default[0]
            g = int(val[1]) if len(val) > 1 and val[1] is not None else default[1]
            b = int(val[2]) if len(val) > 2 and val[2] is not None else default[2]
            return (r, g, b)
        except (ValueError, TypeError, IndexError):
            return default
    return default


def _safe_get_float(val: Any, default: float = 0.0) -> float:
    """Converte com segurança qualquer valor para float, usando default se nulo ou inválido."""
    if val is None:
        return default
    try:
        return float(val)
    except (ValueError, TypeError):
        return default


def extract_model_bounds(
    reader: UnrealPackageReader, model_exp: Dict[str, Any]
) -> Optional[Tuple[Tuple[float, float, float], Tuple[float, float, float]]]:
    """Extrai os limites tridimensionais (BoundingBox FBox) de um Model/Brush da UE2."""
    data = reader.data[model_exp["offset"] : model_exp["offset"] + model_exp["size"]]
    if len(data) >= 25:
        for off in range(len(data) - 25, max(0, len(data) - 120), -1):
            floats = struct.unpack_from("<ffffff", data, off)
            if floats[0] <= floats[3] and floats[1] <= floats[4] and floats[2] <= floats[5]:
                if all(abs(f) < 2000000.0 for f in floats):
                    return (
                        (floats[0], floats[1], floats[2]),
                        (floats[3], floats[4], floats[5]),
                    )
    return None


def extract_map_environment(
    map_pkg: UnrealPackageReader,
    unit_scale: float = UU_TO_METERS_CANONICAL,
    config: Optional[PipelineConfig] = None,
) -> Dict[str, Any]:
    """
    Varre os exports do pacote de mapa buscando instâncias de ZoneInfo, Sunlight,
    WaterVolume, NMoon e PointLights para montar a receita de atmosfera 1:1.
    """
    env_data: Dict[str, Any] = {
        "sunlight": None,
        "moonlight": None,
        "distance_fog": None,
        "ambient_lighting": None,
        "sky_info": None,
        "water_volumes": [],
        "point_lights": [],
    }

    for exp in map_pkg.exports:
        c_name = exp.get("class_name", "")
        o_name = exp.get("object_name", "")

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
                rot = props.get("Rotation", (0, 0, 0))
                rot_vec = _safe_get_vector3(rot, (0.0, 0.0, 0.0))
                p_val, y_val, r_val = int(rot_vec[0]), int(rot_vec[1]), int(rot_vec[2])
                dir_vec = ue2_rotator_to_direction_vector(p_val, y_val, r_val)
                tex_mod = props.get("TexModifyInfo", {})
                color = _safe_get_color(tex_mod.get("Color") if isinstance(tex_mod, dict) else None, (255, 245, 230))
                brightness = _safe_get_float(props.get("LightBrightness"), 1.0)
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
                loc = _safe_get_vector3(props.get("Location"), (0.0, 0.0, 0.0))
                pos_m = [
                    round(loc[0] * unit_scale, 2),
                    round(loc[2] * unit_scale, 2),
                    round(loc[1] * unit_scale, 2),
                ]
                tex_mod = props.get("TexModifyInfo", {})
                color = _safe_get_color(tex_mod.get("Color") if isinstance(tex_mod, dict) else None, (200, 220, 255))

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
                fog_color = _safe_get_color(props.get("DistanceFogColor"), (180, 200, 220))
                fog_start = _safe_get_float(props.get("DistanceFogStart"), 1000.0) * unit_scale
                fog_end = _safe_get_float(props.get("DistanceFogEnd"), 80000.0) * unit_scale
                if fog_end <= fog_start:
                    fog_end = 800.0

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

                amb_color = _safe_get_color(props.get("AmbientLightColor"), (120, 130, 140))
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
                loc = _safe_get_vector3(props.get("Location"), (0.0, 0.0, 0.0))
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
                loc = _safe_get_vector3(props.get("Location"), (0.0, 0.0, -3776.0))
                brush_ref = props.get("Brush")
                bounds = None
                if brush_ref and isinstance(brush_ref, dict):
                    m_name = brush_ref.get("object_name", "")
                    m_exps = [
                        x
                        for x in map_pkg.exports
                        if x.get("class_name") == "Model" and x.get("object_name") == m_name
                    ]
                    if m_exps:
                        bounds = extract_model_bounds(map_pkg, m_exps[0])

                if bounds:
                    min_v, max_v = bounds
                    center_x = (loc[0] + (min_v[0] + max_v[0]) / 2.0) * unit_scale
                    center_z = (loc[1] + (min_v[1] + max_v[1]) / 2.0) * unit_scale
                    size_x = max(1.0, (max_v[0] - min_v[0]) * unit_scale)
                    size_z = max(1.0, (max_v[1] - min_v[1]) * unit_scale)
                    surface_y = (loc[2] + max_v[2]) * unit_scale
                    bottom_y = (loc[2] + min_v[2]) * unit_scale
                else:
                    center_x = loc[0] * unit_scale
                    center_z = loc[1] * unit_scale
                    size_x = 2621.44
                    size_z = 2621.44
                    surface_y = loc[2] * unit_scale if loc[2] != -10.0 else -320.0
                    bottom_y = surface_y - 10.0

                env_data["water_volumes"].append(
                    {
                        "name": o_name,
                        "center_m": [round(center_x, 2), round(center_z, 2)],
                        "size_m": [round(size_x, 2), round(size_z, 2)],
                        "water_plane_height_m": round(surface_y, 2),
                        "surface_y_m": round(surface_y, 2),
                        "bottom_y_m": round(bottom_y, 2),
                        "fluid_friction": _safe_get_float(props.get("FluidFriction"), 1.2),
                        "b_water_volume": True,
                    }
                )

            # 6. Luzes Pontuais (Tochas, Postes, Fontes)
            elif c_name == "Light":
                loc = _safe_get_vector3(props.get("Location"), (0.0, 0.0, 0.0))
                color = _safe_get_color(props.get("LightColor"), (255, 220, 180))
                radius = _safe_get_float(props.get("LightRadius"), 64.0) * unit_scale * 10.0
                brightness = _safe_get_float(props.get("LightBrightness"), 1.0)
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

    # Defaults de fallback
    if env_data["sunlight"] is None:
        env_data["sunlight"] = {
            "name": "DefaultSunlight",
            "type": "DirectionalLight3D",
            "direction": DEFAULT_SUN_DIRECTION,
            "color_rgb": DEFAULT_SUN_COLOR_RGB,
            "energy": 1.2,
        }

    if env_data["distance_fog"] is None:
        env_data["distance_fog"] = {
            "enabled": True,
            "color_rgb": [0.65, 0.75, 0.85],
            "begin_meters": DEFAULT_FOG_BEGIN_METERS,
            "end_meters": DEFAULT_FOG_END_METERS,
        }

    if env_data["ambient_lighting"] is None:
        env_data["ambient_lighting"] = {
            "color_rgb": [0.4, 0.45, 0.5],
            "energy": 0.4,
        }

    return env_data
