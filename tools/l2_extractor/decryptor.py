#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/decryptor.py — Desencriptador Universal de Pacotes Lineage II (UE2)

Suporta detecção automática de pacotes desencriptados (plain), pacotes encriptados
com XOR de 4 bytes e pacotes protegidos com Blowfish (padrão L2 com words-swapped ou raw).
"""

import struct
import numpy as np

UE2_PACKAGE_TAG = 0x9E2A83C1
L2_BLOWFISH_KEY = b"lineage2"


class L2Decryptor:
    """Desencriptador e validador de pacotes Unreal Engine 2 de Lineage II."""

    @staticmethod
    def is_valid_ue2_header(data: bytes, pos: int = 0) -> bool:
        """Verifica se os bytes a partir de `pos` compõem um cabeçalho UE2 válido."""
        if len(data) < pos + 36:
            return False
        tag = struct.unpack_from("<I", data, pos)[0]
        if tag != UE2_PACKAGE_TAG:
            return False
        file_version = struct.unpack_from("<I", data, pos + 4)[0] & 0xFFFF
        if not (60 <= file_version <= 300):
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
        # 1. Verifica se já está desencriptado no offset 0
        if cls.is_valid_ue2_header(raw_data, 0):
            return raw_data

        # 2. Verifica se há cabeçalho plain deslocado nos primeiros 512 bytes
        for pos in range(0, min(512, len(raw_data) - 36)):
            if cls.is_valid_ue2_header(raw_data, pos):
                return raw_data[pos:]

        candidate_offsets = [28, 156, 128, 64, 32, 20, 0]
        target_magic = struct.pack("<I", UE2_PACKAGE_TAG)

        # 3. Tentativa de Desencriptação por XOR de 4 bytes
        for offset in candidate_offsets:
            if offset + 4 > len(raw_data):
                continue
            k0 = raw_data[offset] ^ target_magic[0]
            k1 = raw_data[offset + 1] ^ target_magic[1]
            k2 = raw_data[offset + 2] ^ target_magic[2]
            k3 = raw_data[offset + 3] ^ target_magic[3]
            xor_key = bytes([k0, k1, k2, k3])
            payload = raw_data[offset:]
            key_block = (xor_key * (len(payload) // 4 + 1))[: len(payload)]
            dec = np.bitwise_xor(
                np.frombuffer(payload, dtype=np.uint8),
                np.frombuffer(key_block, dtype=np.uint8),
            ).tobytes()
            if cls.is_valid_ue2_header(dec, 0):
                return dec

        # 4. Tentativa de Desencriptação Blowfish Words-Swapped (Padrão Lineage II)
        for offset in candidate_offsets:
            if offset >= len(raw_data):
                continue
            dec = cls._decrypt_blowfish_words_swapped(raw_data[offset:], L2_BLOWFISH_KEY)
            if cls.is_valid_ue2_header(dec, 0):
                return dec
            tag_pos = dec.find(target_magic)
            if tag_pos != -1 and cls.is_valid_ue2_header(dec, tag_pos):
                return dec[tag_pos:]

        # 5. Tentativa de Desencriptação Blowfish Raw ECB
        for offset in candidate_offsets:
            if offset >= len(raw_data):
                continue
            dec = cls._decrypt_blowfish_raw(raw_data[offset:], L2_BLOWFISH_KEY)
            if cls.is_valid_ue2_header(dec, 0):
                return dec
            tag_pos = dec.find(target_magic)
            if tag_pos != -1 and cls.is_valid_ue2_header(dec, tag_pos):
                return dec[tag_pos:]

        raise ValueError(
            "Não foi possível sincronizar ou desencriptar a assinatura Unreal Package (0x9E2A83C1)."
        )

    @staticmethod
    def _decrypt_blowfish_words_swapped(data: bytes, key: bytes) -> bytes:
        from Crypto.Cipher import Blowfish

        rem = len(data) % 8
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

        rem = len(data) % 8
        unpadded_len = len(data) - rem
        if unpadded_len <= 0:
            return data
        cipher = Blowfish.new(key, Blowfish.MODE_ECB)
        res = cipher.decrypt(data[:unpadded_len])
        if rem > 0:
            res += data[unpadded_len:]
        return res
