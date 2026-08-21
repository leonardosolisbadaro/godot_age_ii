# Changelog

Todas as alterações relevantes para o projeto **godot_age_ii** são documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Adicionado

- **Gerenciamento Dinâmico de Corpos d'Água e Overrides em Runtime**:
  - Sobrescrita dinâmica em tempo de execução para `water_volumes_fix.json`, permitindo ajuste de cotas de superfície, dimensões e novos corpos d'água em memória via `ChunkResourceAdapter`.
  - Atalho de depuração `F4` no `main.gd` para serialização imediata do estado atual dos corpos d'água em memória do chunk ativo diretamente para `water_volumes_fix.json`.
  - Configuração de ponto de spawn dinâmico por chunk (`SPAWN_ON_MAP`), calculando a cota inicial com base nos metadados do mapa.
  - Testes unitários GUT para mesclagem em memória e gravação em disco de `water_volumes_fix.json`.
- **Revisão e Refinamento Arquitetural do Pipeline**:
  - Preservação estrita de dados *raw* originais na compilação (`build_objects.py` e `terrain_builder.py`), eliminando o acoplamento de arquivos `*_fix.json` durante a build.
  - Centralização de configurações globais e constantes semânticas em `tools/l2_extractor/config.py` com injeção de dependências (`PipelineConfig`).
  - Módulo de *Pre-flight Health Check* (`tools/l2_extractor/validator.py`) com verificação rigorosa de integridade antes da execução do pipeline.
  - Sistema de **Costura Automática de Vizinhos (*Auto-Neighbor Stitcher*)**: descobre e costura incrementalmente chunks adjacentes preexistentes no disco sem necessidade de informar dependências manualmente.
  - Ferramenta unificada de diagnóstico e validação de continuidade métrica `tools/inspect_map.py`.
  - Argumentos CLI `--help` / `-h` detalhados com documentação, exemplos práticos de uso e tratamento resiliente de erros em todos os scripts.
  - Bateria de testes automatizados TDD (AAA) para validação de ambiente e configuração em `tools/l2_extractor/test_extractor.py`.
- **Padronização de Qualidade de Código GDScript (Engine Godot 4.7)**:
  - Aplicação estrita do formato de cabeçalho padrão de `GEMINI.md` (`@file`, `@path`, `@description`, `@created`, `@updated`, `@author`) em 100% dos scripts GDScript.
  - Mapeamento e extração de constantes semânticas tipadas com documentação de "O que" e "Porque" em todas as camadas de Domain, Use Cases, Adapters, Infrastructure e Composition Root (`main.gd`).
  - Autodescoberta dinâmica de chunks em `assets/maps` via `ChunkResourceAdapter.get_available_chunks()`, eliminando listas hardcoded (`KNOWN_CHUNKS`).
  - Renderização automática e sob demanda de corpos d'água locais e rios/fossos em cotas personalizadas via `L2TerrainChunkNode` com posicionamento global exato (`top_level`).
  - Suporte semântico a renderização Two-Sided (`cull_mode = CULL_DISABLED`) em bandeiras, tecidos, tendas, cercas e folhagens, com fallback neutro para malhas pendentes de texturização.
  - Limpeza de linhas comentadas, código morto e referências obsoletas em todo o projeto.

### Alterado

- **Eliminação Absoluta de Números Mágicos**:
  - Organização semântica de constantes com tipagem estrita e comentários de "O que" e "Porque" em todos os módulos Python (`decryptor.py`, `texture_decoder.py`, `package_reader.py`, `terrain_builder.py`, `static_mesh_builder.py`, `material_builder.py`, `environment_builder.py`) e scripts GDScript (`main.gd`, `heightfield_sampler.gd`, `server_movement_validator.gd`, `terrain_chunk_data.gd`, `terrain_hole_mask.gd`, `static_mesh_instance_data.gd`, `environment_zone_data.gd`, `player_avatar.gd`, `world_chunk_manager.gd`, `l2_terrain_chunk_node.gd`, `static_mesh_chunk_node.gd`, `debug_hud.gd`, `mesh_selection_highlighter.gd`, `ocean_plane_node.gd`).
- **Definição Estrita de Localização de Ferramentas e Dados**:
  - `umodel`: Restrito estritamente a `umodel_win32/umodel_64.exe` (ou `umodel.exe`) na raiz do projeto, removendo todas as buscas por fallbacks externos no sistema operacional.
  - `Lineage II`: Restrito estritamente a `Lineage II/` na raiz do projeto (`maps`, `textures`, `systextures`, `staticmeshes`), sem buscas em caminhos legados.
- **Consolidação de Utilitários de Inspeção**:
  - Fusão de `inspect_terrain.py`, `inspect_objects.py` e `inspect_environment.py` em `inspect_map.py` com alta coesão e baixo acoplamento.

### Removido

- Plano de oceano genérico global (`OceanPlaneNode` / `setup_ocean`) e dependências associadas em favor dos volumes de água definidos por chunk (`water_volumes.json`).
- Aplicação prévia de arquivos `*_fix.json` nas ferramentas de build (`build_objects.py` e `terrain_builder.py`).
- Recurso descontinuado de depuração de materiais por seção (`_debug_materials_active`, `set_debug_materials_mode`, `UMODEL_PALETTE`, `_original_materials`).
- Diretório de código legado/monolítico `draft/` (`draft/tools/l2_build_chunk.py`, `draft/build_maps.ps1`, etc.).
- Pastas temporárias de testes manuais `test_output_meshes/`, `test_output_textures/` e `scratch/`.
- Script redundante `tools/clear_terrain_cache.ps1`.

---

## [0.5.0] - 2026-08-20

### Adicionado

- **Fase 5: Integração, Automação e Validação Interativa**:
  - Orquestração da cena principal (`main.gd` / `main.tscn`) com suporte a modo Cliente Gráfico e Servidor Headless (`--server`).
  - Instanciação dinâmica de `PlayerAvatar` com câmera orbital em 3ª pessoa e controle por mouse/teclado.
  - Painel de telemetria `DebugHUD` em tempo real com alternância de Wireframe (`F2`) e visibilidade (`F3`).
  - Conexão do `OceanPlaneNode` e `EnvironmentZoneAdapter` com receitas de iluminação e atmosfera.

---

## [0.4.0] - 2026-08-19

### Adicionado

- **Fase 4: Infraestrutura Gráfica & Shaders 1:1 Godot 4.7**:
  - Shader de terreno multi-camada `l2_terrain.gdshader` com suporte a até 12 camadas via Splatmaps RGBA e Detail Maps.
  - Shader de oceano clássico `ocean_water.gdshader` com gradiente Fresnel e ondas animadas.
  - Nó `StaticMeshChunkNode` com renderização em lote via `MultiMeshInstance3D` e suporte a materiais *Alpha Scissor* e *Two-Sided*.
  - Gerenciador de streaming contínuo de terreno e objetos `WorldChunkManager`.
  - Servidor autoritativo de física e validação de movimento `ServerWorldManager`.

---

## [0.3.0] - 2026-08-19

### Adicionado

- **Fase 3: Casos de Uso & Adaptadores (Clean Architecture)**:
  - Casos de uso de carregamento de metadados, amostragem de altitude, detecção de água e streaming de chunks (`src/use_cases/`).
  - Adaptadores de recursos (`ChunkResourceAdapter`), instâncias de malhas (`StaticMeshInstanceAdapter`), atmosfera (`EnvironmentZoneAdapter`) e terreno (`TerrainChunkAdapter`).
  - Adaptador de servidor autoritativo QuanticNet (`QuanticNetServerAdapter`).

---

## [0.2.0] - 2026-08-18

### Adicionado

- **Fase 2: Core Domain & Regras de Negócio Puras com TDD (GUT)**:
  - Entidades de domínio espacial imutáveis: `TerrainChunkData`, `HeightfieldSampler`, `TerrainHoleMask`, `StaticMeshInstanceData`, `EnvironmentZoneData`, `ServerMovementValidator`.
  - Suíte completa de testes unitários GUT cobrindo 100% das regras de negócio em `tests/unit/domain/`.

---

## [0.1.0] - 2026-08-18

### Adicionado

- **Fase 1: Pipeline de Extração e Engenharia Reversa (Python CLI)**:
  - Desencriptador universal Lineage II (`tools/l2_extractor/decryptor.py`) para XOR, Blowfish e pacotes limpos.
  - Parser de pacotes UE2 (`package_reader.py`) com tabelas de nomes, imports, exports e serializador de propriedades.
  - Decodificadores vetorizados em NumPy para texturas DXT1, DXT3, DXT5, P8 e G8 (`texture_decoder.py`).
  - Compilador de terreno com algoritmo de soldagem de bordas contínuas *2-Pass Seamless Alignment* (`terrain_builder.py`).
  - Extrator de StaticMeshes e atores de mapas `.unr` com compilação glTF -> GLB 8x (`static_mesh_builder.py`).
  - Extrator de parâmetros ambientais, luz solar, névoa e volumes de água (`environment_builder.py`).
  - Resolvedor de árvores de materiais e shaders (`material_builder.py`).
