# TODO - godot_age_ii

Roadmap e tarefas de implementação governadas por TDD, Clean Architecture e Fidelidade Visual 1:1 (Lineage II / UE2 -> Godot 4.7).

---

## Fase 1: Pipeline de Extração e Engenharia Reversa (Python CLI Tools)

- [x] **1.1 Parser Avançado de Pacotes UE2 (`tools/l2_extractor/`)**
  - [x] Consolidar desencriptador universal L2 (Blowfish / XOR / Headers limpos).
  - [x] Expandir o parser de propriedades para suportar arrays aninhados, referências de classes e matrizes de transformação.
  - [x] Implementar decodificador completo de formatos de textura: DXT1, DXT3, DXT5 (com interpolação alfa de 8 bits), P8 (paletas 256 cores com alfa) e G8.
  - [x] Implementar testes automatizados de decodificação e integridade de pacotes.

- [x] **1.2 Pipeline de Terreno de Alta Fidelidade**
  - [x] Extrair `TerrainInfo` com resolução, escalas (`TerrainScale`), offsets mundiais e setores (`TerrainSectorSize`).
  - [x] Extrair e empacotar `TerrainMap` (G16), `AlphaMaps` e mapas de visibilidade de quads (`QuadVisibilityBitmap` / buracos no terreno).
  - [x] Extrair matrizes de coordenadas UV de camadas (`UScale`, `VScale`, `UPan`, `VPan`, `RotDegrees`).
  - [x] Extrair texturas de detalhe (`DetailMap`, `DetailScale`, `DetailWeight`) das camadas de terreno.
  - [x] Manter o algoritmo de soldagem contínua de vértices (2-Pass Seamless Alignment) entre chunks vizinhos.

- [x] **1.3 Pipeline de Extração de StaticMeshes (`.usx` e `.unr`)**
  - [x] Implementar parser do formato `StaticMesh` dos pacotes `.usx` (Streams de vértices, normais, tangentes, UV0 difuso, UV1 lightmap, index buffers/triângulos e seções de materiais).
  - [x] Extrair dados de colisão simplificada (KDOP, cascas convexas e esferas de colisão originais).
  - [x] Escanear e extrair instâncias de `StaticMeshActor` dentro dos mapas `.unr` (Localização, Rotação em Rotator UE2, Escala uniforme e 3D, propriedades de iluminação).
  - [x] Pipeline de compilação glTF -> GLB com remapeamento de primitivas e descarte de accessors vazios para compatibilidade com o Godot 4.
  - [ ] **[Dívida Técnica]** Refatorar o leitor binário nativo de `.usx` em Python para cobrir 100% das variantes de índices e seções de malhas complexas sem depender de export prévio do UModel.

- [x] **1.4 Pipeline de Materiais, Efeitos e Atmosfera**
  - [x] Parser da árvore de materiais UE2 (`Shader`, `Combiner`, `FinalBlend`, `TexPanner`, `TexRotator`, `ColorModifier`).
  - [x] Extrair parâmetros ambientais de `ZoneInfo` (Cores de luz ambiente, `DistanceFogColor`, `DistanceFogStart`, `DistanceFogEnd`).
  - [x] Extrair atores de luz pontual e direcional (`Sunlight`, `Light`, tochas e fontes de iluminação).
  - [x] Extrair definições de superfícies de água locais (`FluidSurfaceInfo`, `WaterVolume` e malhas de rios).

---

## Fase 2: Core Domain & Regras de Negócio Puras com TDD (GUT)

- [x] **2.1 Entidades de Domínio Espacial & Terreno (`src/domain/`)**
  - [x] `TerrainChunkData`: Representação imutável de metadados, dimensões, escala e cotas de elevação.
  - [x] `HeightfieldSampler`: Amostrador O(1) de interpolação bilinear contínua em coordenadas mundiais com cobertura total do grid.
  - [x] `TerrainHoleMask`: Validador de quads perfurados/invisíveis para colisão e travessia em cavernas.
  - [x] `StaticMeshInstanceData`: Entidade para posicionamento, rotação e caixas delimitadoras (AABB) de objetos estáticos.
  - [x] `EnvironmentZoneData`: Definições puras de atmosfera, névoa e nível dos oceanos/águas.
  - [x] `ServerMovementValidator`: Validação autoritativa de movimentação com restrição de declive e velocidade.

- [x] **2.2 Mandato de Testes Unitários GUT (`tests/unit/domain/`)**
  - [x] Testes AAA de interpolação e amostragem de altura no terreno (`test_heightfield_sampler.gd`).
  - [x] Testes de conversão de coordenadas, caixas AABB e transformações espaciais (`test_static_mesh_instance_data.gd`).
  - [x] Testes de colisão e detecção de buracos no terreno (`test_terrain_hole_mask.gd`).
  - [x] Testes de validação autoritativa de movimento do servidor com restrição de declive e altura (`test_server_movement_validator.gd`).
  - [x] Testes de atmosfera, iluminação solar e profundidade de águas (`test_environment_zone_data.gd`).

---

## Fase 3: Casos de Uso & Adaptadores (Clean Architecture)

- [x] **3.1 Casos de Uso (`src/use_cases/`)**
  - [x] `LoadChunkMetadataUseCase`: Carregar e validar integridade dos metadados de chunk.
  - [x] `LoadServerHeightfieldUseCase`: Construir instância do HeightfieldSampler para física autoritativa.
  - [x] `SampleWorldAltitudeUseCase`: Consulta centralizada de altitude para física, spawns e entidades.
  - [x] `EvaluateChunkWaterPresenceUseCase`: Determinar presença e nível de água para cada chunk.
  - [x] `StreamWorldChunksUseCase`: Orquestrar carregamento e descarregamento dinâmico de chunks com base no raio de visão (LOD).
  - [x] `ValidatePlayerMovementUseCase`: Validação autoritativa de inputs de movimentação no servidor.

- [x] **3.2 Adaptadores de Recursos, Visualização e Rede (`src/adapters/`)**
  - [x] `ChunkResourceAdapter`: Leitura e cache otimizado de arquivos binários, receitas JSON, GLBs e texturas.
  - [x] `StaticMeshInstanceAdapter`: Gerenciamento e instanciamento em lote de malhas estáticas via MultiMeshInstance3D.
  - [x] `EnvironmentZoneAdapter`: Tradutor de atmosfera para nós DirectionalLight3D e WorldEnvironment.
  - [x] `TerrainChunkAdapter`: Tradutor de nós visuais MeshInstance3D para malhas de terreno compiladas.
  - [x] `QuanticNetServerAdapter`: Conectar a lógica de validação espacial ao pipeline de rede autoritativo do QuanticNet.

---

## Fase 4: Infraestrutura Gráfica & Shaders 1:1 Godot 4.7 (`src/infrastructure/`)

- [x] **4.1 Shader Avançado de Terreno Lineage II (`l2_terrain.gdshader`)**
  - [x] Blending multi-camada via Splatmaps RGBA (suporte a até 12 camadas por chunk).
  - [x] Suporte a micro-texturas de detalhe (*Detail Map*) com repetição em alta frequência.
  - [x] Suporte a matrizes de UV individuais por camada (`scale`, `rotation`, `pan`).
  - [x] Suporte a descarte de quads (*alpha clip / holes*) em cavernas e túneis.

- [x] **4.2 Renderização e Streaming de StaticMeshes**
  - [x] Nó `StaticMeshChunkNode`: Instanciamento de malhas com `MultiMeshInstance3D` para alta performance.
  - [x] Suporte a materiais com *Alpha Scissor* / *Alpha Hash* para folhagens e transparências.
  - [x] Configuração de materiais *Two-Sided* e propriedades PBR calibradas com a iluminação clássica.

- [x] **4.3 Sistema de Água, Rios e Fluidos**
  - [x] Shader de Oceano 1:1 com gradiente Fresnel, reflexo solar clássico e normais animadas (`ocean_water.gdshader`).
  - [x] Nó `OceanPlaneNode` de superfícies fluidas nas cotas mundiais de oceano e corpos d'água.

- [x] **4.4 Iluminação, Céu e Atmosfera**
  - [x] Configuração de `WorldEnvironment` dinâmica derivada do `ZoneInfo` do chunk ativo (Distance Fog, cores ambientes).
  - [x] Sistema de Sol direcional e iluminação estática por chunk.

- [x] **4.5 Streaming Contínuo, Avatar e Câmera de Exploração**
  - [x] `WorldChunkManager`: Streaming dinâmico de chunks de terreno e StaticMeshes baseado na posição do jogador.
  - [x] `PlayerAvatar`: Câmera orbital clássica estilo MMORPG com zoom no scroll do mouse, rotação com botão direito e colisão física.
  - [x] `DebugHUD`: Telemetria em tempo real com modo wireframe (`F2`).
  - [x] `ServerWorldManager`: Servidor dedicado autoritativo para física e rede.

---

## Fase 5: Integração, Automação e Validação Interativa

- [x] **5.1 Orquestração da Cena Principal (`main.gd` / `main.tscn`)**
  - [x] Integrar `WorldChunkManager` com registro e streaming de chunks (`16_24` inicial e cluster de Talking Island).
  - [x] Integrar `EnvironmentZoneAdapter` para carregar `environment_recipe.json` (Sol `DirectionalLight3D`, céu e `WorldEnvironment`).
  - [x] Integrar `OceanPlaneNode` nas cotas de água reais ($Z = 0.00\text{m}$).
  - [x] Instanciar `PlayerAvatar` no ponto de spawn seguro de Talking Island com câmera orbital em 3ª pessoa.
  - [x] Instanciar `DebugHUD` e conectar atualização de telemetria em tempo real no `_process()`.
  - [x] Implementar atalhos de teclado: `F2` (Wireframe / Overdraw / Desativado), `F3` (Toggle HUD) e encerramento limpo via `_notification()`.
  - [x] Suporte à execução dual: Cliente Gráfico (padrão) vs Servidor Headless (`--server`).

- [x] **5.2 Script de Build em Lote e Automação de Chunks (`tools/build_map.py`)**
  - [x] Unificar a cadeia de execução CLI de ponta a ponta: `build_terrain.py` $\to$ `build_objects.py` $\to$ `build_environment.py`.
  - [x] Compilação em lote do cluster completo de Talking Island (`16_24`, `16_25`, `17_24`, `17_25`) com costura de bordas (*Auto-Neighbor Stitcher*).
  - [x] Suporte a flags `--force`, `--skip-textures`, `--cluster`, logs de progresso e resumo estatístico de extração.

- [x] **5.3 Validação Interativa e Testes Manuais no Godot 4.7**
  - [x] Teste de navegação e colisão do avatar pelo relevo (caminhada, corrida com Shift, rampas e colinas).
  - [x] Teste de colisão e oclusão de atores estáticos (árvores `speaking_tree_s`, cercas `woodfence`, pedras e casas) via `_setup_static_mesh_collisions()`.
  - [x] Teste de visualização de Shaders (blending multi-camada de splatmaps, transparência *Alpha Scissor* e *Two-Sided* em folhagens).
  - [x] Teste de transição aquática nos volumes locais de água (`water_volumes.json` / `water_volumes_fix.json`).
  - [x] Teste de telemetria do `DebugHUD` e alternador de Wireframe (`F2`).
  - [x] Teste do atalho de debug `F4` para gravação de `water_volumes_fix.json`.

---

## Fase 6: Revisão Completa, Refinamento Arquitetural & Limpeza

- [x] **6.1 Limpeza de Código Morto e Refinamento de Estrutura**
  - [x] Excluir diretório de código legado/monolítico `draft/` e arquivos temporários `test_output_*/`, `scratch/`.
  - [x] Eliminar scripts de automação redundantes (`tools/clear_terrain_cache.ps1`).
  - [x] Consolidar ferramentas de inspeção (`inspect_terrain.py`, `inspect_objects.py`, `inspect_environment.py`) no utilitário unificado `tools/inspect_map.py`.

- [x] **6.2 Definição Estrita de Localização e Pre-flight Health Check**
  - [x] Definir localização estrita de UModel em `umodel_win32/umodel_64.exe` (ou `umodel.exe`) na raiz do projeto, sem fallbacks externos.
  - [x] Definir localização estrita de dados raw em `Lineage II/` na raiz do projeto, sem fallbacks externos.
  - [x] Implementar módulo de *Pre-flight Health Check* (`tools/l2_extractor/validator.py`) para abortar imediatamente com relatório rico caso falte qualquer componente ou dependência.

- [x] **6.3 Eliminação Absoluta de Números Mágicos & Injeção de Dependências (DI)**
  - [x] Criar módulo de configuração centralizada `tools/l2_extractor/config.py` com dataclass `PipelineConfig` e constantes semânticas tipadas.
  - [x] Organizar constantes no topo de cada módulo Python com documentação de "O que" e "Porque".
  - [x] Aplicar Injeção de Dependências (DI) em todos os construtores de extratores, decodificadores e compiladores.

- [x] **6.4 Padronização de Interface CLI e Resiliência a Falhas**
  - [x] Implementar argumentos `-h` / `--help` detalhados com exemplos de uso em todos os scripts (`build_map.py`, `build_terrain.py`, `build_objects.py`, `build_environment.py`, `inspect_map.py`, `clear_terrain_cache.py`).
  - [x] Implementar controle e recuperação de falha com mensagens detalhadas de causa/diagnóstico.
  - [x] Atualizar suíte de testes TDD (AAA) em `tools/l2_extractor/test_extractor.py` validando ambiente, configuração e compiladores.

- [x] **6.5 Preservação de Dados RAW e Overrides em Runtime**
  - [x] Garantir preservação estrita de dados *raw* na build (`build_objects.py` e `terrain_builder.py` não aplicam arquivos `*_fix.json`).
  - [x] Sobrescrita dinâmica em tempo de execução via `ChunkResourceAdapter` para `chunk_static_actors_fix.json`, `terrain_recipe_fix.json` e `water_volumes_fix.json`.
  - [x] Remoção completa do oceano genérico global em favor dos volumes locais de cada chunk.
  - [x] Implementação de ponto de spawn dinâmico por chunk (`SPAWN_ON_MAP`) e atalho de debug `F4`.

- [x] **6.6 Otimização de Colisões e Spawn Autônomo no Cliente**
  - [x] Colisão híbrida de terreno no cliente com `HeightMapShape3D` ultraleve a partir de `heightfield.bin` e fallback para `ConcavePolygonShape3D` (`create_trimesh_shape()`) em cavernas/túneis.
  - [x] Geração automática de colisores primitivos (`BoxShape3D`) para objetos estáticos obstrutivos (árvores, muralhas, construções, rochas, pontes) no `StaticMeshChunkNode`.
  - [x] Cálculo de altitude de spawn 100% autônomo no cliente usando `HeightfieldSampler` de domínio puro (zero dependência de servidor ativo).

---

## Fase 7: Rede e Sincronização Autoritativa QuanticNet (Multiplayer & Netcode)

- [ ] **7.1 Ciclo de Vida de Conexão, Handshake e Autenticação (`QuanticNet`)**
  - [ ] Implementar orquestração de conexão do cliente (`join`) com estados `CONNECTING`, `AUTHENTICATING`, `CONNECTED`, `FAILED`.
  - [ ] Configuração de porta (`PORT 4242`), senha de handshake (`secret`) e suporte a fallback de modo offline/standalone (`--offline` / `--solo`).
  - [ ] Tratamento de encerramento gracioso via `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` liberando sockets UDP.

- [ ] **7.2 Replicação de Estado de Entidades & Avatares Remotos (State-Based Replication)**
  - [ ] Conectar sinal `peer_joined(id)` para instanciar nós de avatares remotos (`_remote_players: Dictionary`).
  - [ ] Conectar sinal `peer_left(id)` e `peer_sleep(id)` para descarte ou desativação de avatares remotos.
  - [ ] Processar sinal `state_received(owner, pos, rot, custom)` com interpolação de buffers temporais (LERP/SLERP) para suavizar movimentação de outros jogadores.
  - [ ] Transmissão periódica de inputs/estados do jogador local via `submit_state(pos, rot, custom_id)` no canal `CH_STATE`.

- [ ] **7.3 Predição no Cliente, Snapback e Reconciliação Autoritativa (Client-Side Prediction & Reconciliation)**
  - [ ] Implementar fila de inputs pendentes com números de sequência (`sequence_id`) no `PlayerAvatar`.
  - [ ] Conectar sinal `snapback_received(seq, pos, rot, reason, replay_inputs)` para correção de posição quando o servidor rejeitar um movimento.
  - [ ] Replay instantâneo de inputs locais a partir do snapshot autoritativo do servidor após correção de divergência.

- [ ] **7.4 Validação Espacial, Física Analítica e Autoridade no Servidor Headless**
  - [ ] Integrar `QuanticNetServerAdapter` com `ServerWorldManager` para validação de passos contra o `HeightfieldSampler`.
  - [ ] Implementar grade de particionamento espacial 2D em domínio puro (`SpatialHashGrid2D` com células de $32\text{m} \times 32\text{m}$) para consulta de obstáculos estáticos em $O(1)$.
  - [ ] Implementar testes analíticos de colisão em microssegundos (sem nós de física/SceneTree):
    - Círculo/Cilindro 2D para troncos de árvores, postes e colunas (distância euclidiana ao quadrado no plano $XZ$).
    - Caixa Orientada 3D (*Oriented Bounding Box - OBB*) para casas, muralhas, cercas, pontes e rochas (*Closest Point on Box* via matriz transposta).
  - [ ] Integrar validação de colisão de obstáculos estáticos no `ServerMovementValidator` em conjunto com limites de declive e velocidade máxima.
  - [ ] Sistema de strikes (`DEFAULT_MAX_STRIKES`) e rejeição de peers com anomalias de posição.

- [ ] **7.5 Telemetria de Rede, NetEm e Validação Multiplayer**
  - [ ] Exibir métricas de RTT (Ping), jitter, packet loss e offsets de relógio no `DebugHUD` a partir do sinal `pong_received(rtt, offset)`.
  - [ ] Teste de resiliência sob condições adversas de rede via emulador `--netem` (injeção de 10% packet loss, 150ms latência e 50ms jitter).
  - [ ] Teste de validação multi-instância (Servidor Headless + 2 ou mais Clientes conectados simultaneamente).

