#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/texture_decoder.py — Decodificador de Alta Fidelidade de Texturas UE2

Implementa decodificação vetorizada em NumPy para os formatos de textura do Lineage II:
- DXT1 (RGB565 com 1-bit alpha condicional)
- DXT3 (Alfa explícito de 4 bits + Cores DXT1)
- DXT5 (Alfa interpolado de 8 bits + Cores DXT1)
- P8   (Paletizado de 8 bits com 256 entradas RGBA/RGB)
- G8   (Tons de cinza de 8 bits)
- RGBA8 / BGRA8 (Não comprimido)
"""

import struct
from typing import List, Optional, Tuple, Union
import numpy as np
from PIL import Image


def decode_dxt1(data: bytes, width: int, height: int) -> Optional[Image.Image]:
    """Decodifica buffer DXT1 (BC1) para Pillow Image (RGB ou RGBA)."""
    bx = max(1, width // 4)
    by = max(1, height // 4)
    num_blocks = bx * by
    needed = num_blocks * 8
    if len(data) < needed:
        return None

    blocks = np.frombuffer(
        data[:needed], dtype=[("c0", "<u2"), ("c1", "<u2"), ("bits", "<u4")]
    )
    c0 = blocks["c0"].astype(np.uint32)
    c1 = blocks["c1"].astype(np.uint32)
    bits = blocks["bits"]

    r0 = (((c0 >> 11) & 0x1F) * 255 + 15) // 31
    g0 = (((c0 >> 5) & 0x3F) * 255 + 31) // 63
    b0 = ((c0 & 0x1F) * 255 + 15) // 31

    r1 = (((c1 >> 11) & 0x1F) * 255 + 15) // 31
    g1 = (((c1 >> 5) & 0x3F) * 255 + 31) // 63
    b1 = ((c1 & 0x1F) * 255 + 15) // 31

    palette = np.zeros((num_blocks, 4, 4), dtype=np.uint8)
    palette[:, 0, 0] = r0
    palette[:, 0, 1] = g0
    palette[:, 0, 2] = b0
    palette[:, 0, 3] = 255

    palette[:, 1, 0] = r1
    palette[:, 1, 1] = g1
    palette[:, 1, 2] = b1
    palette[:, 1, 3] = 255

    mask = c0 > c1
    palette[mask, 2, 0] = (2 * r0[mask] + r1[mask]) // 3
    palette[mask, 2, 1] = (2 * g0[mask] + g1[mask]) // 3
    palette[mask, 2, 2] = (2 * b0[mask] + b1[mask]) // 3
    palette[mask, 2, 3] = 255

    palette[mask, 3, 0] = (r0[mask] + 2 * r1[mask]) // 3
    palette[mask, 3, 1] = (g0[mask] + 2 * g1[mask]) // 3
    palette[mask, 3, 2] = (b0[mask] + 2 * g1[mask]) // 3
    palette[mask, 3, 3] = 255

    palette[~mask, 2, 0] = (r0[~mask] + r1[~mask]) // 2
    palette[~mask, 2, 1] = (g0[~mask] + g1[~mask]) // 2
    palette[~mask, 2, 2] = (b0[~mask] + b1[~mask]) // 2
    palette[~mask, 2, 3] = 255

    palette[~mask, 3, 0] = 0
    palette[~mask, 3, 1] = 0
    palette[~mask, 3, 2] = 0
    palette[~mask, 3, 3] = 0  # 1-bit transparente

    shifts = np.arange(0, 32, 2, dtype=np.uint32)
    indices = (bits[:, None] >> shifts[None, :]) & 3
    block_pixels = np.take_along_axis(palette, indices[:, :, None], axis=1)
    block_pixels = block_pixels.reshape((by, bx, 4, 4, 4))
    img_arr = block_pixels.transpose((0, 2, 1, 3, 4)).reshape((by * 4, bx * 4, 4))

    cropped = img_arr[:height, :width, :]
    # Se todos os alphas forem 255, salva como RGB para economizar espaço
    if np.all(cropped[:, :, 3] == 255):
        return Image.fromarray(cropped[:, :, :3], mode="RGB")
    return Image.fromarray(cropped, mode="RGBA")


def decode_dxt3(data: bytes, width: int, height: int) -> Optional[Image.Image]:
    """Decodifica buffer DXT3 (BC2) com canal alfa explícito de 4 bits para RGBA."""
    bx = max(1, width // 4)
    by = max(1, height // 4)
    num_blocks = bx * by
    needed = num_blocks * 16
    if len(data) < needed:
        return None

    raw_arr = np.frombuffer(data[:needed], dtype=np.uint8).reshape((num_blocks, 16))
    alpha_bytes = raw_arr[:, :8]
    color_bytes = raw_arr[:, 8:].tobytes()

    # Decodifica bloco de cor DXT1
    rgb_img = decode_dxt1(color_bytes, width, height)
    if rgb_img is None:
        return None

    rgb_arr = np.array(rgb_img.convert("RGB"))

    # Decodifica 16 valores de alfa de 4 bits por bloco (2 valores por byte)
    a_low = (alpha_bytes & 0x0F) * 17
    a_high = ((alpha_bytes >> 4) & 0x0F) * 17
    alphas = np.empty((num_blocks, 16), dtype=np.uint8)
    alphas[:, 0::2] = a_low
    alphas[:, 1::2] = a_high

    alpha_grid = alphas.reshape((by, bx, 4, 4)).transpose((0, 2, 1, 3)).reshape((by * 4, bx * 4))
    alpha_cropped = alpha_grid[:height, :width]

    rgba_arr = np.dstack([rgb_arr, alpha_cropped])
    return Image.fromarray(rgba_arr, mode="RGBA")


def decode_dxt5(data: bytes, width: int, height: int) -> Optional[Image.Image]:
    """Decodifica buffer DXT5 (BC3) com interpolação de alfa de 8 bits para RGBA."""
    bx = max(1, width // 4)
    by = max(1, height // 4)
    num_blocks = bx * by
    needed = num_blocks * 16
    if len(data) < needed:
        return None

    raw_arr = np.frombuffer(data[:needed], dtype=np.uint8).reshape((num_blocks, 16))
    alpha_blocks = raw_arr[:, :8]
    color_bytes = raw_arr[:, 8:].tobytes()

    # 1. Decodifica bloco de cor DXT1
    rgb_img = decode_dxt1(color_bytes, width, height)
    if rgb_img is None:
        return None
    rgb_arr = np.array(rgb_img.convert("RGB"))

    # 2. Decodifica Alfa Interpolado de 8 bits
    a0 = alpha_blocks[:, 0].astype(np.float32)
    a1 = alpha_blocks[:, 1].astype(np.float32)

    alpha_palette = np.zeros((num_blocks, 8), dtype=np.uint8)
    alpha_palette[:, 0] = a0.astype(np.uint8)
    alpha_palette[:, 1] = a1.astype(np.uint8)

    mask = a0 > a1
    # Se a0 > a1: 6 valores intermediários interpolados
    for i in range(1, 7):
        alpha_palette[mask, i + 1] = np.round(
            ((7 - i) * a0[mask] + i * a1[mask]) / 7.0
        ).astype(np.uint8)

    # Se a0 <= a1: 4 valores intermediários + 0 e 255
    for i in range(1, 5):
        alpha_palette[~mask, i + 1] = np.round(
            ((5 - i) * a0[~mask] + i * a1[~mask]) / 5.0
        ).astype(np.uint8)
    alpha_palette[~mask, 6] = 0
    alpha_palette[~mask, 7] = 255

    # 3. Extrai 16 índices de 3 bits dos 6 bytes de máscara de alfa
    bit_bytes = alpha_blocks[:, 2:8].astype(np.uint64)
    bits48 = (
        bit_bytes[:, 0]
        | (bit_bytes[:, 1] << 8)
        | (bit_bytes[:, 2] << 16)
        | (bit_bytes[:, 3] << 24)
        | (bit_bytes[:, 4] << 32)
        | (bit_bytes[:, 5] << 40)
    )

    shifts = np.arange(0, 48, 3, dtype=np.uint64)
    alpha_indices = ((bits48[:, None] >> shifts[None, :]) & 7).astype(np.int32)

    block_alphas = np.take_along_axis(alpha_palette, alpha_indices, axis=1)
    alpha_grid = (
        block_alphas.reshape((by, bx, 4, 4))
        .transpose((0, 2, 1, 3))
        .reshape((by * 4, bx * 4))
    )
    alpha_cropped = alpha_grid[:height, :width]

    rgba_arr = np.dstack([rgb_arr, alpha_cropped])
    return Image.fromarray(rgba_arr, mode="RGBA")


def decode_p8(
    data: bytes, width: int, height: int, palette: Optional[List[Tuple[int, int, int, int]]]
) -> Optional[Image.Image]:
    """Decodifica textura P8 (Paletizada 8-bit, 256 cores) para Pillow Image."""
    needed = width * height
    if len(data) < needed:
        return None

    indices = np.frombuffer(data[:needed], dtype=np.uint8)

    if palette and len(palette) >= 256:
        pal_arr = np.array(palette[:256], dtype=np.uint8)
        r = pal_arr[:, 0]
        g = pal_arr[:, 1]
        b = pal_arr[:, 2]
        a = pal_arr[:, 3] if pal_arr.shape[1] > 3 else np.full(256, 255, dtype=np.uint8)

        # Se a paleta for em escala de cinza pura
        if np.array_equal(r, g) and np.array_equal(g, b) and np.all(a == 255):
            arr = r[indices].reshape((height, width))
            return Image.fromarray(arr, mode="L")

        # Se houver transparência na paleta
        if not np.all(a == 255):
            rgba = np.stack(
                [
                    r[indices].reshape((height, width)),
                    g[indices].reshape((height, width)),
                    b[indices].reshape((height, width)),
                    a[indices].reshape((height, width)),
                ],
                axis=-1,
            )
            return Image.fromarray(rgba, mode="RGBA")

        rgb = np.stack(
            [
                r[indices].reshape((height, width)),
                g[indices].reshape((height, width)),
                b[indices].reshape((height, width)),
            ],
            axis=-1,
        )
        return Image.fromarray(rgb, mode="RGB")

    # Fallback: Escala de cinza direta
    arr = indices.reshape((height, width))
    return Image.fromarray(arr, mode="L")


def decode_g8(data: bytes, width: int, height: int) -> Optional[Image.Image]:
    """Decodifica textura G8 / L8 (Grayscale de 8 bits)."""
    needed = width * height
    if len(data) < needed:
        return None
    arr = np.frombuffer(data[:needed], dtype=np.uint8).reshape((height, width))
    return Image.fromarray(arr, mode="L")


def decode_rgba8(data: bytes, width: int, height: int, is_bgra: bool = False) -> Optional[Image.Image]:
    """Decodifica buffer não comprimido de 32 bits (RGBA8 / BGRA8)."""
    needed = width * height * 4
    if len(data) < needed:
        return None
    arr = np.frombuffer(data[:needed], dtype=np.uint8).reshape((height, width, 4))
    if is_bgra:
        arr = arr[:, :, [2, 1, 0, 3]]
    return Image.fromarray(arr, mode="RGBA")
