#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/l2_extractor/environment.py — Descoberta de Ambiente e Gerenciamento de Pacotes L2

Varre a árvore de diretórios do Lineage II (textures, systextures, maps, staticmeshes)
e fornece cache sob demanda de instâncias de UnrealPackageReader.
"""

import os
from pathlib import Path
from typing import Dict, List, Optional, Union

from .package_reader import UnrealPackageReader


class L2Environment:
    """Gerenciador de ambiente e resolução de pacotes de assets do Lineage II."""

    DEFAULT_L2_PATHS = [
        Path("C:/Users/LEONARDO/Documents/Lineage II"),
        Path("C:/Lineage II"),
        Path("D:/Lineage II"),
    ]

    def __init__(self, target_file: Optional[Union[str, Path]] = None, l2_root: Optional[Union[str, Path]] = None):
        self.target_file = Path(target_file).resolve() if target_file else None
        self.l2_root = self._resolve_l2_root(Path(l2_root) if l2_root else None)

        self.textures_dir = self.l2_root / "textures" if self.l2_root else None
        self.systextures_dir = self.l2_root / "systextures" if self.l2_root else None
        self.maps_dir = self.l2_root / "maps" if self.l2_root else None
        self.staticmeshes_dir = self.l2_root / "staticmeshes" if self.l2_root else None

        self.available_utx: Dict[str, Path] = {}
        self.available_usx: Dict[str, Path] = {}
        self.available_unr: Dict[str, Path] = {}
        self.package_cache: Dict[str, UnrealPackageReader] = {}

        self._index_all_packages()

    def _resolve_l2_root(self, explicit_root: Optional[Path]) -> Optional[Path]:
        if explicit_root and explicit_root.is_dir():
            return explicit_root.resolve()

        if self.target_file:
            cand = self.target_file.parent
            if cand.name.lower() in ("maps", "textures", "staticmeshes", "systextures") and cand.parent.is_dir():
                return cand.parent.resolve()
            if (self.target_file.parent / "textures").is_dir():
                return self.target_file.parent.resolve()

        for def_path in self.DEFAULT_L2_PATHS:
            if def_path.is_dir() and (def_path / "maps").is_dir():
                return def_path.resolve()

        return None

    def _index_all_packages(self) -> None:
        search_dirs = [
            self.textures_dir,
            self.systextures_dir,
            self.maps_dir,
            self.staticmeshes_dir,
        ]
        if self.target_file and self.target_file.parent.is_dir():
            search_dirs.append(self.target_file.parent)

        for d in search_dirs:
            if not d or not d.is_dir():
                continue
            try:
                for f in d.iterdir():
                    if not f.is_file():
                        continue
                    ext = f.suffix.lower()
                    stem = f.stem.lower()
                    if ext == ".utx":
                        self.available_utx[stem] = f
                    elif ext == ".usx":
                        self.available_usx[stem] = f
                    elif ext == ".unr":
                        self.available_unr[stem] = f
            except Exception:
                pass

    def get_package(self, pkg_name: str) -> Optional[UnrealPackageReader]:
        """Obtém ou carrega do cache um pacote UTX, USX ou UNR pelo nome."""
        if not pkg_name:
            return None
        clean_name = (
            pkg_name.lower()
            .replace(".utx", "")
            .replace(".usx", "")
            .replace(".unr", "")
            .replace(".u", "")
        )

        if clean_name in self.package_cache:
            return self.package_cache[clean_name]

        candidate_path = (
            self.available_utx.get(clean_name)
            or self.available_usx.get(clean_name)
            or self.available_unr.get(clean_name)
        )

        if candidate_path and candidate_path.is_file():
            try:
                reader = UnrealPackageReader(candidate_path)
                self.package_cache[clean_name] = reader
                return reader
            except Exception:
                pass

        return None
