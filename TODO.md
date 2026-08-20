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

- [ ] **5.2 Script de Build em Lote e Automação de Chunks (`build_maps.ps1`)**
  - [ ] Atualizar script PowerShell para compilar em lote o cluster completo de Talking Island (`16_24`, `16_25`, `17_24`, `17_25`).
  - [ ] Unificar a cadeia de execução CLI: `build_terrain.py` $\to$ `build_objects.py` $\to$ `build_environment.py`.
  - [ ] Adicionar suporte a flags `--force`, logs de progresso e resumo estatístico de extração.

- [ ] **5.3 Validação Interativa e Testes Manuais no Godot 4.7**
  - [ ] Teste de navegação e colisão do avatar pelo relevo (caminhada, corrida com Shift, rampas e colinas).
  - [ ] Teste de colisão e oclusão de atores estáticos (árvores `speaking_tree_s`, cercas `woodfence`, pedras e casas).
  - [ ] Teste de visualização de Shaders (blending multi-camada de splatmaps, transparência *Alpha Scissor* e *Two-Sided* em folhagens).
  - [ ] Teste de transição aquática no plano de oceano ($Z = 0.00\text{m}$) e profundidade.
  - [ ] Teste de telemetria do `DebugHUD` e alternador de Wireframe (`F2`).
  - [ ] Teste de conectividade e sincronização de rede QuanticNet (Host / Join local).

