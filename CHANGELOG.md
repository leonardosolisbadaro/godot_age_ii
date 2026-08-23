# Changelog

Todas as alterações relevantes para o projeto **godot_age_ii** a partir da reescrita arquitetural com foco nativo no **QuanticNet** são documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

---

## [Unreleased]

### Planejado (Subfase 7.4+)

- **Core Domain de Gameplay: Stats Dinâmicos, Avatar & Client-Side Prediction**:
  - Entidades de domínio de gameplay (`PlayerStats`, `MovementIntent`, `KinematicState`).
  - Previsão local de movimento no cliente (`LocalMovementPredictorUseCase`) a 60Hz.
  - Submissão autoritativa de estados de movimento via `QuanticNet.submit_state()` no canal `CH_STATE`.

---

## [0.7.0] - 2026-08-23

### Adicionado

- **Core Domain Espacial & Casos de Uso Puros (TDD GUT AAA)**:
  - [`ScaleConverter`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/core/domain/scale_converter.gd): Conversor métrico determinístico entre Unreal Units ($UU$) e Metros da Godot ($100 UU = 1.0\text{ m}$) e mapeador de coordenadas para nomes de chunks (`16_24`).
  - [`TerrainChunkData`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/core/domain/terrain_chunk_data.gd): Metadados espaciais, limites AABB e resolução de grade de terreno.
  - [`TerrainHoleMask`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/core/domain/terrain_hole_mask.gd): Máscara de buracos no terreno para entradas de cavernas e dungeons.
  - [`StaticMeshInstanceData`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/core/domain/static_mesh_instance_data.gd): Representação pura de instâncias 3D com `Transform3D` e escala.
  - [`WaterVolumeData`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/core/domain/water_volume_data.gd): Corpos d'água com cotas de superfície e verificação de submersão.
  - [`EnvironmentZoneData`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/core/domain/environment_zone_data.gd): Parâmetros puros de iluminação solar e neblina.
  - [`SampleTerrainAltitudeUseCase`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/core/use_cases/sample_terrain_altitude_use_case.gd): Amostragem em $O(1)$ de altitude com interpolação bilinear sobre a matriz binária `heightfield.bin`.
  - [`CalculateActiveChunksUseCase`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/core/use_cases/calculate_active_chunks_use_case.gd): Cálculo da grade $3 \times 3$ de chunks ativos ao redor do observador.

- **Streaming de Terreno, Shaders e Apresentação 3D (Code-First)**:
  - [`ChunkResourceAdapter`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/client/adapters/chunk_resource_adapter.gd): Adaptador de leitura desacoplada de dados em `assets/maps/`, `material_recipes.json` e resolvedor de texturas com indexação de *casing* em $O(1)$.
  - `l2_terrain.gdshader`: Shader multi-camada com Splatmaps RGBA e Detail Maps (suporte a até 12 camadas + base).
  - `ocean_water.gdshader`: Shader de água com refração, ondas animadas e gradiente Fresnel.
  - [`L2TerrainChunkNode`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/client/infrastructure/l2_terrain_chunk_node.gd): Construção de malha visual, material multi-camada e colisão física.
  - [`StaticMeshChunkNode`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/client/infrastructure/static_mesh_chunk_node.gd): Renderização em lote de objetos 3D via `MultiMeshInstance3D` com mapeamento fiel de materiais PBR, transparência *Alpha Scissor*, superfícies *Two-Sided* e filtragem anisotrópica.
  - [`WaterChunkNode`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/client/infrastructure/water_chunk_node.gd): Instanciação de planos de água nas cotas de superfície de cada volume.
  - [`WorldChunkManager`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/client/infrastructure/world_chunk_manager.gd): Gerenciador central de streaming contínuo de mundo no cliente.
  - [`FlyCamera`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/client/infrastructure/fly_camera.gd): Câmera livre 3D de desenvolvedor para navegação fluida pelos cenários.

- **Fundação QuanticNet Bare-Metal (Server & Client)**:
  - [`QuanticNetServerAdapter`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/server/adapters/quantic_net_server_adapter.gd): Host UDP bare-metal (`enable_dtls = false` para compatibilidade com WAN/redes distintas), gerenciamento de ciclo de vida, registro e saída atômica de peers.
  - [`QuanticNetClientAdapter`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/client/adapters/quantic_net_client_adapter.gd): Conexão UDP direta ao servidor, máquina de estados (`ConnectionState`), reconciliação de telemetria RTT/Pong e submissão explícita com `delta` dinâmico do loop de física (`submit_state`).
  - [`ServerOrchestrator`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/server/infrastructure/server_orchestrator.gd): Orquestrador do servidor dedicado headless sem nós visuais pesados.
  - [`ClientOrchestrator`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/client/infrastructure/client_orchestrator.gd): Orquestrador do cliente de jogo com injeção desacoplada de adaptadores, streaming de mundo e interface.
  - Despachante principal [`main.gd`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/main.gd) com suporte a argumentos CLI (`--server`, `--dedicated`, `--client`, `--ip=`, `--port=`, `--enable-editor`, `--enable-dtls`).

- **Mini-IDE DevTool & Telemetria Técnica Plugável (Orientação a Objetos Limpa)**:
  - Classe base reutilizável [`DebugWindow`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/debug_window.gd) com suporte nativo a arrasto in-game (Drag & Drop), botão `[ X ]` para fechar, foco ao clicar (`move_to_front`), fundo escuro estilizado e auto-ajuste de altura ao conteúdo.
  - Hospedeiro [`DebugIdeHost`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/debug_ide_host.gd) em overlay `CanvasLayer` (layer 100) com barra de menu superior fixa no topo (`Arquivo` $\rightarrow$ `Toggle IDE (F2)`, `Ferramentas`) e atalho global `F2` para alternar a visibilidade de toda a interface.
  - Painel [`TelemetryPanel`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/panels/telemetry_panel.gd) ("Telemetria de Rede"): Herda de `DebugWindow` com exibição em tempo real de RTT (Ping em ms), Jitter instantâneo, Server Offset, status da conexão e estatísticas de Pongs (mínimo, máximo e média).
  - Painel [`GraphicsTelemetryPanel`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/panels/graphics_telemetry_panel.gd) ("Telemetria de Gráficos"): Herda de `DebugWindow` com monitoramento de FPS (com cores funcionais de performance), Frame Time (CPU), Physics Time, Draw Calls, Primitivas 3D, VRAM Usada (MB) e RAM Estática (MB).
  - Painel [`ConnectionLogsPanel`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/panels/connection_logs_panel.gd) ("Logs de Rede"): Herda de `DebugWindow` com console de eventos de rede, timestamps de sistema `[HH:MM:SS]` e botão "Limpar Logs".

- **Suíte de Testes Unitários Automatizados (TDD GUT AAA)**:
  - Bateria com **43 testes unitários** e **156 verificações atômicas (asserts)** passando com 100% de sucesso em modo headless (`run_tests.ps1`) em ~0.9s.
