#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/decryptor.py — Desencriptador Universal de Pacotes Lineage II (UE2)

@description
Implementa algoritmos de desencriptação e sincronização de fluxo binário para arquivos de pacote
da Unreal Engine 2 (Lineage II), cobrindo pacotes plain, com máscara XOR de 4 bytes e pacotes
criptografados com Blowfish (ECB com words-swapped e raw).

@created 2026-08-18
@updated 2026-08-20
@author Leonardo S. Badaró
"""

import struct
from typing import List, Optional
import numpy as np

from .config import (
    BLOWFISH_BLOCK_SIZE,
    L2_BLOWFISH_KEY,
    UE2_HEADER_MIN_BYTE_SIZE,
    UE2_MAX_VALID_VERSION,
    UE2_MIN_VALID_VERSION,
    UE2_PACKAGE_TAG,
)


# ==============================================================================
# CONSTANTES SEMÂNTICAS DO DESENCRIPTADOR
# ==============================================================================

## @const HEADER_SCAN_WINDOW_BYTES (int)
## O que: Janela de busca em bytes para varredura de cabeçalho UE2 não alinhado (512 bytes).
## Porque: Alguns instaladores de Lineage II inserem metadados proprietários de 28 a 512 bytes antes da tag real.
HEADER_SCAN_WINDOW_BYTES: int = 512

## @const CANDIDATE_HEADER_OFFSETS (List[int])
## O que: Offsets de cabeçalhos clássicos conhecidos de pacotes Lineage II (28, 156, 128, 64, 32, 20, 0).
## Porque: Reduz o tempo de busca direta antes de executar a varredura linear completa.
CANDIDATE_HEADER_OFFSETS: List[int] = [28, 156, 128, 64, 32, 20, 0]

## @const XOR_KEY_BYTE_SIZE (int)
## O que: Tamanho da chave de desencriptação XOR de 32 bits (4 bytes).
## Porque: A cifra XOR da UE2 opera aplicando uma chave de 4 bytes ciclicamente sobre os dados.
XOR_KEY_BYTE_SIZE: int = 4


class L2Decryptor:
    """Desencriptador e validador de pacotes Unreal Engine 2 de Lineage II."""

    @staticmethod
    def is_valid_ue2_header(data: bytes, pos: int = 0) -> bool:
        """
        Verifica se os bytes a partir de `pos` compõem um cabeçalho UE2 válido.
        Valida Tag (0x9E2A83C1), versão de arquivo (60..300) e integridade da tabela de nomes.
        """
        if len(data) < pos + UE2_HEADER_MIN_BYTE_SIZE:
            return False

        tag = struct.unpack_from("<I", data, pos)[0]
        if tag != UE2_PACKAGE_TAG:
            return False

        file_version = struct.unpack_from("<I", data, pos + 4)[0] & 0xFFFF
        if not (UE2_MIN_VALID_VERSION <= file_version <= UE2_MAX_VALID_VERSION):
            return False

        name_count = struct.unpack_from("<I", data, pos + 12)[0]
        name_offset = struct.unpack_from("<I", data, pos + 16)[0]
        return name_count > 0 and pos <= name_offset < len(data)

    @classmethod
    def decrypt(cls, raw_data: bytes) -> bytes:
        """
        Desencripta os dados brutos de um arquivo .unr, .utx, .usx ou .u do Lineage II.
        Retorna os bytes decodificados a partir do início do cabeçalho válido do pacote.
        """
        # 1. Verifica se já está desencriptado no offset zero
        if cls.is_valid_ue2_header(raw_data, 0):
            return raw_data

        # 2. Verifica se há cabeçalho plain deslocado nos primeiros 512 bytes
        max_scan = min(HEADER_SCAN_WINDOW_BYTES, len(raw_data) - UE2_HEADER_MIN_BYTE_SIZE)
        for pos in range(0, max_scan):
            if cls.is_valid_ue2_header(raw_data, pos):
                return raw_data[pos:]

        target_magic = struct.pack("<I", UE2_PACKAGE_TAG)

        # 3. Tentativa de Desencriptação por XOR de 4 bytes
        for offset in CANDIDATE_HEADER_OFFSETS:
            if offset + XOR_KEY_BYTE_SIZE > len(raw_data):
                continue
            k0 = raw_data[offset] ^ target_magic[0]
            k1 = raw_data[offset + 1] ^ target_magic[1]
            k2 = raw_data[offset + 2] ^ target_magic[2]
            k3 = raw_data[offset + 3] ^ target_magic[3]
            xor_key = bytes([k0, k1, k2, k3])
            payload = raw_data[offset:]
            key_block = (xor_key * (len(payload) // XOR_KEY_BYTE_SIZE + 1))[: len(payload)]
            dec = np.bitwise_xor(
                np.frombuffer(payload, dtype=np.uint8),
                np.frombuffer(key_block, dtype=np.uint8),
            ).tobytes()
            if cls.is_valid_ue2_header(dec, 0):
                return dec

        # 4. Tentativa de Desencriptação Blowfish Words-Swapped (Padrão Lineage II)
        for offset in CANDIDATE_HEADER_OFFSETS:
            if offset >= len(raw_data):
                continue
            dec = cls._decrypt_blowfish_words_swapped(raw_data[offset:], L2_BLOWFISH_KEY)
            if cls.is_valid_ue2_header(dec, 0):
                return dec
            tag_pos = dec.find(target_magic)
            if tag_pos != -1 and cls.is_valid_ue2_header(dec, tag_pos):
                return dec[tag_pos:]

        # 5. Tentativa de Desencriptação Blowfish Raw ECB
        for offset in CANDIDATE_HEADER_OFFSETS:
            if offset >= len(raw_data):
                continue
            dec = cls._decrypt_blowfish_raw(raw_data[offset:], L2_BLOWFISH_KEY)
            if cls.is_valid_ue2_header(dec, 0):
                return dec
            tag_pos = dec.find(target_magic)
            if tag_pos != -1 and cls.is_valid_ue2_header(dec, tag_pos):
                return dec[tag_pos:]

        raise ValueError(
            f"Não foi possível sincronizar ou desencriptar a assinatura Unreal Package (0x{UE2_PACKAGE_TAG:08X})."
        )

    @staticmethod
    def _decrypt_blowfish_words_swapped(data: bytes, key: bytes) -> bytes:
        from Crypto.Cipher import Blowfish

        rem = len(data) % BLOWFISH_BLOCK_SIZE
        unpadded_len = len(data) - rem
        if unpadded_len <= 0:
            return data
        arr = np.frombuffer(data[:unpadded_len], dtype="<u4").copy()
        arr.byteswap(inplace=True)
        cipher = Blowfish.new(key, Blowfish.MODE_ECB)
        decrypted_bytes = cipher.decrypt(arr.tobytes())
        dec_arr = np.frombuffer(decrypted_bytes, dtype="<u4").copy()
        dec_arr.byteswap(inplace=True)
        res = dec_arr.tobytes()
        if rem > 0:
            res += data[unpadded_len:]
        return res

    @staticmethod
    def _decrypt_blowfish_raw(data: bytes, key: bytes) -> bytes:
        from Crypto.Cipher import Blowfish

        rem = len(data) % BLOWFISH_BLOCK_SIZE
        unpadded_len = len(data) - rem
        if unpadded_len <= 0:
            return data
        cipher = Blowfish.new(key, Blowfish.MODE_ECB)
        res = cipher.decrypt(data[:unpadded_len])
        if rem > 0:
            res += data[unpadded_len:]
        return res
