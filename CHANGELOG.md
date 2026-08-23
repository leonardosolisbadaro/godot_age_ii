# Changelog

Todas as alterações relevantes para o projeto **godot_age_ii** a partir da reescrita arquitetural com foco nativo no **QuanticNet** são documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

---

## [Unreleased]

### Planejado (Subfase 7.3+)

- **Core Domain Compartilhado: Stats Dinâmicos de Lineage II & Conversão de Escala**:
  - Entidades de domínio em memória mutáveis (`PlayerStats`, `MovementIntent`, `ScaleConverter`).
  - Amostragem em $O(1)$ de altitude via binário `heightfield.bin` (`SampleTerrainAltitudeUseCase`).

---

## [0.7.0] - 2026-08-23

### Adicionado

- **Arquitetura Oficial Desacoplada (Clean Architecture)**:
  - Isolamento de todo o código exploratório legado das Fases 1 a 6 em `draft/v1/` com `.gdignore` para consulta histórica.
  - Estruturação estrita de diretórios modulares: `src/core/`, `src/server/`, `src/client/`, `src/debug/` e `tests/`.
  - Fonte única da verdade para parâmetros e topologia de rede em [`NetworkConstants`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/core/domain/network_constants.gd) (`src/core/domain/`), eliminando números e strings mágicas.

- **Fundação QuanticNet Bare-Metal (Server & Client)**:
  - [`QuanticNetServerAdapter`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/server/adapters/quantic_net_server_adapter.gd): Host UDP bare-metal (`enable_dtls = false` para compatibilidade com WAN/redes distintas), gerenciamento de ciclo de vida, registro e saída atômica de peers.
  - [`QuanticNetClientAdapter`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/client/adapters/quantic_net_client_adapter.gd): Conexão UDP direta ao servidor, máquina de estados (`ConnectionState`), reconciliação de telemetria RTT/Pong e submissão explícita com `delta` dinâmico do loop de física (`submit_state`).
  - [`ServerOrchestrator`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/server/infrastructure/server_orchestrator.gd): Orquestrador do servidor dedicado headless sem nós visuais pesados.
  - [`ClientOrchestrator`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/client/infrastructure/client_orchestrator.gd): Orquestrador do cliente de jogo com injeção desacoplada de adaptadores e interface.
  - Despachante principal [`main.gd`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/main.gd) com suporte a argumentos CLI (`--server`, `--dedicated`, `--client`, `--ip=`, `--port=`, `--enable-editor`, `--enable-dtls`).

- **Mini-IDE DevTool & Telemetria Técnica Plugável (Orientação a Objetos Limpa)**:
  - Classe base reutilizável [`DebugWindow`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/debug_window.gd) com suporte nativo a arrasto in-game (Drag & Drop), botão `[ X ]` para fechar, foco ao clicar (`move_to_front`), fundo escuro estilizado e auto-ajuste de altura ao conteúdo.
  - Hospedeiro [`DebugIdeHost`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/debug_ide_host.gd) em overlay `CanvasLayer` (layer 100) com barra de menu superior fixa no topo (`Arquivo` $\rightarrow$ `Toggle IDE (F2)`, `Ferramentas`) e atalho global `F2` para alternar a visibilidade de toda a interface.
  - Painel [`TelemetryPanel`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/panels/telemetry_panel.gd) ("Telemetria de Rede"): Herda de `DebugWindow` com exibição em tempo real de RTT (Ping em ms), Jitter instantâneo, Server Offset, status da conexão e estatísticas de Pongs (mínimo, máximo e média).
  - Painel [`GraphicsTelemetryPanel`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/panels/graphics_telemetry_panel.gd) ("Telemetria de Gráficos"): Herda de `DebugWindow` com monitoramento de FPS (com cores funcionais de performance), Frame Time (CPU), Physics Time, Draw Calls, Primitivas 3D, VRAM Usada (MB) e RAM Estática (MB).
  - Painel [`ConnectionLogsPanel`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/panels/connection_logs_panel.gd) ("Logs de Rede"): Herda de `DebugWindow` com console de eventos de rede, timestamps de sistema `[HH:MM:SS]` e botão "Limpar Logs".

- **Suíte de Testes Unitários Automatizados (TDD GUT AAA)**:
  - Bateria com 25 testes unitários e 90 verificações atômicas (asserts) passando com 100% de sucesso em modo headless (`run_tests.ps1`) em ~0.5s.
  - Testes isolados cobrindo adaptadores de rede, orquestradores, janelas flutuantes base e painéis especializados de telemetria.
