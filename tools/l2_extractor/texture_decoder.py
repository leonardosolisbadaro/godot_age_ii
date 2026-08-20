#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/texture_decoder.py — Decodificador de Alta Fidelidade de Texturas UE2

@description
Implementa decodificação vetorizada em NumPy para todos os formatos de textura do Lineage II:
- DXT1 / BC1 (RGB565 com 1-bit alpha condicional)
- DXT3 / BC2 (Alfa explícito de 4 bits + Cores DXT1)
- DXT5 / BC3 (Alfa interpolado de 8 bits + Cores DXT1)
- P8 (Paletizado de 8 bits com 256 entradas RGBA/RGB)
- G8 / L8 (Tons de cinza de 8 bits)
- RGBA8 / BGRA8 (32-bit não comprimido)

@created 2026-08-18
@updated 2026-08-20
@author Leonardo S. Badaró
"""

import struct
from typing import List, Optional, Tuple, Union
import numpy as np
from PIL import Image

from .config import (
    DXT1_BLOCK_BYTE_SIZE,
    DXT3_5_BLOCK_BYTE_SIZE,
    DXT_BLOCK_PIXELS_DIM,
    PALETTE_ENTRIES_COUNT,
)


# ==============================================================================
# CONSTANTES SEMÂNTICAS DE DECODIFICAÇÃO DE TEXTURA
# ==============================================================================

## @const OPAQUE_ALPHA_VALUE (int)
## O que: Valor máximo de opacidade para canal alfa de 8 bits (255).
## Porque: Representa pixel 100% visível/opaco.
OPAQUE_ALPHA_VALUE: int = 255

## @const TRANSPARENT_ALPHA_VALUE (int)
## O que: Valor de transparência total para canal alfa de 8 bits (0).
## Porque: Representa pixel 100% invisível/transparente.
TRANSPARENT_ALPHA_VALUE: int = 0

## @const RGB565_RED_MASK (int)
## O que: Máscara binária de 5 bits para extração do canal vermelho em RGB565 (0x1F = 31).
## Porque: Os 5 bits mais significativos de RGB565 correspondem ao canal R.
RGB565_RED_MASK: int = 0x1F

## @const RGB565_GREEN_MASK (int)
## O que: Máscara binária de 6 bits para extração do canal verde em RGB565 (0x3F = 63).
## Porque: Os 6 bits centrais de RGB565 correspondem ao canal G.
RGB565_GREEN_MASK: int = 0x3F

## @const RGB565_BLUE_MASK (int)
## O que: Máscara binária de 5 bits para extração do canal azul em RGB565 (0x1F = 31).
## Porque: Os 5 bits menos significativos de RGB565 correspondem ao canal B.
RGB565_BLUE_MASK: int = 0x1F

## @const RGB565_RED_SHIFT (int)
## O que: Quantidade de deslocamento à direita para alinhar o canal R de RGB565 (11 bits).
## Porque: Bits 11 a 15 compõem o canal R.
RGB565_RED_SHIFT: int = 11

## @const RGB565_GREEN_SHIFT (int)
## O que: Quantidade de deslocamento à direita para alinhar o canal G de RGB565 (5 bits).
## Porque: Bits 5 a 10 compõem o canal G.
RGB565_GREEN_SHIFT: int = 5

## @const RGBA_BYTES_PER_PIXEL (int)
## O que: Quantidade de bytes por pixel em uma imagem não comprimida RGBA (4 bytes).
## Porque: 1 byte por canal (R, G, B, A).
RGBA_BYTES_PER_PIXEL: int = 4

## @const DXT3_ALPHA_MULTIPLIER (int)
## O que: Fator de escala para converter alfa de 4 bits (0..15) para 8 bits (0..255) (17).
## Porque: 15 * 17 = 255 (0x0F * 0x11 = 0xFF).
DXT3_ALPHA_MULTIPLIER: int = 17


def decode_dxt1(data: bytes, width: int, height: int) -> Optional[Image.Image]:
    """Decodifica buffer DXT1 (BC1) para Pillow Image (RGB ou RGBA)."""
    bx = max(1, width // DXT_BLOCK_PIXELS_DIM)
    by = max(1, height // DXT_BLOCK_PIXELS_DIM)
    num_blocks = bx * by
    needed = num_blocks * DXT1_BLOCK_BYTE_SIZE
    if len(data) < needed:
        return None

    blocks = np.frombuffer(
        data[:needed], dtype=[("c0", "<u2"), ("c1", "<u2"), ("bits", "<u4")]
    )
    c0 = blocks["c0"].astype(np.uint32)
    c1 = blocks["c1"].astype(np.uint32)
    bits = blocks["bits"]

    r0 = (((c0 >> RGB565_RED_SHIFT) & RGB565_RED_MASK) * 255 + 15) // 31
    g0 = (((c0 >> RGB565_GREEN_SHIFT) & RGB565_GREEN_MASK) * 255 + 31) // 63
    b0 = ((c0 & RGB565_BLUE_MASK) * 255 + 15) // 31

    r1 = (((c1 >> RGB565_RED_SHIFT) & RGB565_RED_MASK) * 255 + 15) // 31
    g1 = (((c1 >> RGB565_GREEN_SHIFT) & RGB565_GREEN_MASK) * 255 + 31) // 63
    b1 = ((c1 & RGB565_BLUE_MASK) * 255 + 15) // 31

    palette = np.zeros((num_blocks, 4, 4), dtype=np.uint8)
    palette[:, 0, 0] = r0
    palette[:, 0, 1] = g0
    palette[:, 0, 2] = b0
    palette[:, 0, 3] = OPAQUE_ALPHA_VALUE

    palette[:, 1, 0] = r1
    palette[:, 1, 1] = g1
    palette[:, 1, 2] = b1
    palette[:, 1, 3] = OPAQUE_ALPHA_VALUE

    mask = c0 > c1
    palette[mask, 2, 0] = (2 * r0[mask] + r1[mask]) // 3
    palette[mask, 2, 1] = (2 * g0[mask] + g1[mask]) // 3
    palette[mask, 2, 2] = (2 * b0[mask] + b1[mask]) // 3
    palette[mask, 2, 3] = OPAQUE_ALPHA_VALUE

    palette[mask, 3, 0] = (r0[mask] + 2 * r1[mask]) // 3
    palette[mask, 3, 1] = (g0[mask] + 2 * r1[mask]) // 3
    palette[mask, 3, 2] = (b0[mask] + 2 * r1[mask]) // 3
    palette[mask, 3, 3] = OPAQUE_ALPHA_VALUE

    palette[~mask, 2, 0] = (r0[~mask] + r1[~mask]) // 2
    palette[~mask, 2, 1] = (g0[~mask] + g1[~mask]) // 2
    palette[~mask, 2, 2] = (b0[~mask] + b1[~mask]) // 2
    palette[~mask, 2, 3] = OPAQUE_ALPHA_VALUE

    palette[~mask, 3, 0] = TRANSPARENT_ALPHA_VALUE
    palette[~mask, 3, 1] = TRANSPARENT_ALPHA_VALUE
    palette[~mask, 3, 2] = TRANSPARENT_ALPHA_VALUE
    palette[~mask, 3, 3] = TRANSPARENT_ALPHA_VALUE  # 1-bit transparente

    shifts = np.arange(0, 32, 2, dtype=np.uint32)
    indices = (bits[:, None] >> shifts[None, :]) & 3
    block_pixels = np.take_along_axis(palette, indices[:, :, None], axis=1)
    block_pixels = block_pixels.reshape((by, bx, DXT_BLOCK_PIXELS_DIM, DXT_BLOCK_PIXELS_DIM, 4))
    img_arr = block_pixels.transpose((0, 2, 1, 3, 4)).reshape((by * DXT_BLOCK_PIXELS_DIM, bx * DXT_BLOCK_PIXELS_DIM, 4))

    cropped = img_arr[:height, :width, :]
    if np.all(cropped[:, :, 3] == OPAQUE_ALPHA_VALUE):
        return Image.fromarray(cropped[:, :, :3], mode="RGB")
    return Image.fromarray(cropped, mode="RGBA")


def decode_dxt3(data: bytes, width: int, height: int) -> Optional[Image.Image]:
    """Decodifica buffer DXT3 (BC2) com canal alfa explícito de 4 bits para RGBA."""
    bx = max(1, width // DXT_BLOCK_PIXELS_DIM)
    by = max(1, height // DXT_BLOCK_PIXELS_DIM)
    num_blocks = bx * by
    needed = num_blocks * DXT3_5_BLOCK_BYTE_SIZE
    if len(data) < needed:
        return None

    raw_arr = np.frombuffer(data[:needed], dtype=np.uint8).reshape((num_blocks, DXT3_5_BLOCK_BYTE_SIZE))
    alpha_bytes = raw_arr[:, :8]
    color_bytes = raw_arr[:, 8:].tobytes()

    rgb_img = decode_dxt1(color_bytes, width, height)
    if rgb_img is None:
        return None

    rgb_arr = np.array(rgb_img.convert("RGB"))

    # Decodifica 16 valores de alfa de 4 bits por bloco (2 valores por byte)
    a_low = (alpha_bytes & 0x0F) * DXT3_ALPHA_MULTIPLIER
    a_high = ((alpha_bytes >> 4) & 0x0F) * DXT3_ALPHA_MULTIPLIER
    alphas = np.empty((num_blocks, 16), dtype=np.uint8)
    alphas[:, 0::2] = a_low
    alphas[:, 1::2] = a_high

    alpha_grid = alphas.reshape((by, bx, DXT_BLOCK_PIXELS_DIM, DXT_BLOCK_PIXELS_DIM)).transpose((0, 2, 1, 3)).reshape((by * DXT_BLOCK_PIXELS_DIM, bx * DXT_BLOCK_PIXELS_DIM))
    alpha_cropped = alpha_grid[:height, :width]

    rgba_arr = np.dstack([rgb_arr, alpha_cropped])
    return Image.fromarray(rgba_arr, mode="RGBA")


def decode_dxt5(data: bytes, width: int, height: int) -> Optional[Image.Image]:
    """Decodifica buffer DXT5 (BC3) com interpolação de alfa de 8 bits para RGBA."""
    bx = max(1, width // DXT_BLOCK_PIXELS_DIM)
    by = max(1, height // DXT_BLOCK_PIXELS_DIM)
    num_blocks = bx * by
    needed = num_blocks * DXT3_5_BLOCK_BYTE_SIZE
    if len(data) < needed:
        return None

    raw_arr = np.frombuffer(data[:needed], dtype=np.uint8).reshape((num_blocks, DXT3_5_BLOCK_BYTE_SIZE))
    alpha_blocks = raw_arr[:, :8]
    color_bytes = raw_arr[:, 8:].tobytes()

    # 1. Bloco de cor DXT1
    rgb_img = decode_dxt1(color_bytes, width, height)
    if rgb_img is None:
        return None
    rgb_arr = np.array(rgb_img.convert("RGB"))

    # 2. Alfa Interpolado de 8 bits
    a0 = alpha_blocks[:, 0].astype(np.float32)
    a1 = alpha_blocks[:, 1].astype(np.float32)

    alpha_palette = np.zeros((num_blocks, 8), dtype=np.uint8)
    alpha_palette[:, 0] = a0.astype(np.uint8)
    alpha_palette[:, 1] = a1.astype(np.uint8)

    mask = a0 > a1
    for i in range(1, 7):
        alpha_palette[mask, i + 1] = np.round(
            ((7 - i) * a0[mask] + i * a1[mask]) / 7.0
        ).astype(np.uint8)

    for i in range(1, 5):
        alpha_palette[~mask, i + 1] = np.round(
            ((5 - i) * a0[~mask] + i * a1[~mask]) / 5.0
        ).astype(np.uint8)
    alpha_palette[~mask, 6] = TRANSPARENT_ALPHA_VALUE
    alpha_palette[~mask, 7] = OPAQUE_ALPHA_VALUE

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
        block_alphas.reshape((by, bx, DXT_BLOCK_PIXELS_DIM, DXT_BLOCK_PIXELS_DIM))
        .transpose((0, 2, 1, 3))
        .reshape((by * DXT_BLOCK_PIXELS_DIM, bx * DXT_BLOCK_PIXELS_DIM))
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

    if palette and len(palette) >= PALETTE_ENTRIES_COUNT:
        pal_arr = np.array(palette[:PALETTE_ENTRIES_COUNT], dtype=np.uint8)
        r = pal_arr[:, 0]
        g = pal_arr[:, 1]
        b = pal_arr[:, 2]
        a = pal_arr[:, 3] if pal_arr.shape[1] > 3 else np.full(PALETTE_ENTRIES_COUNT, OPAQUE_ALPHA_VALUE, dtype=np.uint8)

        if np.array_equal(r, g) and np.array_equal(g, b) and np.all(a == OPAQUE_ALPHA_VALUE):
            arr = r[indices].reshape((height, width))
            return Image.fromarray(arr, mode="L")

        if not np.all(a == OPAQUE_ALPHA_VALUE):
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
    needed = width * height * RGBA_BYTES_PER_PIXEL
    if len(data) < needed:
        return None
    arr = np.frombuffer(data[:needed], dtype=np.uint8).reshape((height, width, RGBA_BYTES_PER_PIXEL))
    if is_bgra:
        arr = arr[:, :, [2, 1, 0, 3]]
    return Image.fromarray(arr, mode="RGBA")
