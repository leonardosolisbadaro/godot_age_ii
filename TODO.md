# TODO - godot_age_ii

Roadmap e tarefas de implementação governadas por TDD, Clean Architecture, QuanticNet Core e Fidelidade 1:1 (Lineage II / UE2 -> Godot 4.7).

---

## Fases Anteriores (Concluídas e Arquivadas)

- [x] **Fase 1: Pipeline de Extração e Engenharia Reversa:** Decodificador de pacotes UE2, compilação de texturas (DXT/P8/G8), malhas estáticas e shaders de terreno 1:1.
- [x] **Fase 2: Core Domain & Regras de Negócio Puras:** Entidades de domínio imutáveis, amostradores matemáticos HeightfieldSampler O(1) e testes GUT AAA.
- [x] **Fase 3: Casos de Uso & Adaptadores:** Arquitetura limpa desacoplada, streaming sob demanda de chunks e gerenciamento de recursos.
- [x] **Fase 4: Infraestrutura Gráfica & Shaders:** Renderização MultiMeshInstance3D de alta performance, shaders splatmap multi-camada e volumes locais de água.
- [x] **Fase 5: Integração e Validação Interativa:** Orquestração da cena principal, câmera orbital MMORPG em 3ª pessoa e Mini-IDE DebugHUD in-game.
- [x] **Fase 6: Refinamento Arquitetural & Qualidade:** Eliminação de redundâncias, bake binário de colisões, precisão milimétrica e deltas puros em arquivos `*_fix.json`.

---

## Estrutura Arquitetural Alvo (Clean Architecture & QuanticNet-Native)

```txt
res://src/
├── core/                  # Regras de Negócio e Matemática Puras (Compartilhadas)
│   ├── domain/            # Stats L2 Dinâmicos, Fórmulas de Velocidade, Tipos Puros
│   └── use_cases/         # Casos de Uso comuns (Amostragem de Terreno, Conversões de Escala)
├── server/                # Servidor Dedicado Autoritativo (Headless, Zero Gráficos)
│   ├── domain/            # Validações de Segurança, Anti-Cheat, Limites Elásticos
│   ├── use_cases/         # Validação de Pacotes, Gerenciamento de Chunks Server (NavMesh)
│   ├── adapters/          # QuanticNetServerAdapter, ServerNavMeshAdapter
│   └── infrastructure/    # ServerOrchestrator, Carregador Binário de NavMesh/Heightfield
├── client/                # Cliente do Jogo (Predição Local e Apresentação)
│   ├── domain/            # Estado de Predição Local, Entidades Remotas
│   ├── use_cases/         # Client-Side Prediction, Reconciliação (Snapback), Interpolação
│   ├── adapters/          # QuanticNetClientAdapter, InputAdapter, TerrainStreamerAdapter
│   └── infrastructure/    # ClientOrchestrator, Nós Visuais (Avatares, Terrenos, Câmera)
└── debug/                 # Mini-IDE & Ferramentas de Diagnóstico (Observador Plugável)
    ├── panels/            # Painéis Modulares (Telemetria, Hack Injector, World Inspector)
    └── debug_ide_host.gd  # Hospedeiro do DebugHUD (ativo apenas em builds de desenvolvimento)
```

---

## Fase 7: Fundação QuanticNet & Movimentação Autoritativa

### 7.1 Configuração Mínima do QuanticNet (Server & Client Bare-Metal)

- [x] Mover o código exploratório legado do cliente e servidor para `draft/v1/` como fonte de consulta histórica.
- [x] Criar a árvore de diretórios oficial desacoplada (`src/core/`, `src/server/`, `src/client/`, `src/debug/`).
- [x] Implementar `QuanticNetServerAdapter` inicializando o servidor dedicado em porta pública configurável (sem DTLS para conexões diretas entre provedores distintos / WAN).
- [x] Implementar `QuanticNetClientAdapter` com conexão UDP direta, reconexão automática e gerenciamento do ciclo de vida da conexão.
- [x] Estabelecer handshake cliente-servidor e disparo dos sinais de ciclo de vida (`connection_state_changed`, `peer_joined`, `peer_left`).

### 7.2 Mini-IDE & Telemetria Técnica Plugável (Desde o Início)

- [x] Criar componente base de janelas flutuantes reutilizável [`DebugWindow`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/debug_window.gd) com arrasto in-game (Drag & Drop), foco em primeiro plano (`move_to_front`) e botão `[ X ]` de fechar.
- [x] Criar hospedeiro [`DebugIdeHost`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/debug_ide_host.gd) com barra de menu superior fixa no topo (`Arquivo` -> `Toggle IDE (F2)`, `Ferramentas`) e atalho global `F2` para alternar visibilidade.
- [x] Implementar [`TelemetryPanel`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/panels/telemetry_panel.gd) ("Telemetria de Rede"): exibição em tempo real de RTT (Ping em ms), Jitter instantâneo, Server Offset e estatísticas de Pongs (min, max, média).
- [x] Implementar [`GraphicsTelemetryPanel`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/panels/graphics_telemetry_panel.gd) ("Telemetria de Gráficos"): monitoramento de FPS com cores funcionais, Frame Time (CPU), Physics Time, Draw Calls, Primitivas 3D, VRAM e RAM Estática.
- [x] Implementar [`ConnectionLogsPanel`](file:///c:/Users/LEONARDO/Documents/godot_age_ii/src/debug/panels/connection_logs_panel.gd) ("Logs de Rede"): feed cronológico de eventos com timestamps `[HH:MM:SS]` e botão "Limpar Logs".
- [x] Cobertura de 100% em testes unitários TDD GUT AAA para `DebugWindow`, `TelemetryPanel`, `GraphicsTelemetryPanel`, `ConnectionLogsPanel` e `DebugIdeHost`.

### 7.3 Core Domain Compartilhado: Stats Dinâmicos de Lineage II & Conversão de Escala (TDD AAA)

- [ ] Entidades de domínio puras e dinâmicas em `src/core/domain/`:
  - `PlayerStats`: Estrutura de dados em memória mutável (flexível para futura leitura de JSON/DB), suportando atributos base (DEX, STR, etc.) e cálculos de velocidade de movimento (`run_speed`, `walk_speed`, penalidade de peso e buffs).
  - `MovementIntent`: Intenção de deslocamento e orientação angular.
  - `ScaleConverter`: Conversor bidirecional preciso entre Unreal Units ($UU$) e Metros da Godot.
- [ ] Casos de uso de amostragem matemática em `src/core/use_cases/`:
  - `SampleTerrainAltitudeUseCase`: Leitura em $O(1)$ de altitude via `heightfield.bin`.
- [ ] Cobertura de 100% em testes unitários GUT AAA para mutação dinâmica de stats, fórmulas de velocidade e conversões.

### 7.4 Client-Side Prediction, Chão & Envio Autoritativo (`submit_state`)

- [ ] Carregamento visual do terreno sob os pés do avatar local (chão ativo).
- [ ] Instanciação do nó visual do avatar (`PlayerAvatarView`) sobre o terreno.
- [ ] Implementar `LocalMovementPredictorUseCase` no cliente:
  - Processamento de inputs locais (WASD / direção) a 60Hz.
  - Avanço otimista da posição local (`_client_predicted_position`) baseado nos stats dinâmicos de velocidade (`PlayerStats`).
- [ ] Envio periódico de pacotes de estado via `QuanticNet.submit_state()` no canal `CH_STATE`.

### 7.5 Servidor Autoritativo Headless: Validação & Snapbacks Determinísticos

- [ ] Implementar `ServerChunkManager` em `src/server/infrastructure/`:
  - Carregamento assíncrono em memória de `navmesh.res` e `heightfield.bin` para os chunks ativos sem criar instâncias visuais.
- [ ] Implementar `ValidatePlayerMovementUseCase` em `src/server/use_cases/`:
  - Validação de taxa de velocidade linear com **tolerância elástica calibrada** ($\Delta s \le v_{max} \cdot \Delta t + \epsilon_{jitter}$).
  - Validação de altitude vertical contra o terreno e conformidade contra a `navmesh.res`.
- [ ] Emissão de `Snapback` autoritativo pelo servidor quando os limites forem violados.
- [ ] Reconciliação no cliente via `ReconcileServerSnapbackUseCase`: interceptação de `snapback_received`, reancoragem da predição e descarte de estados inválidos.
- [ ] Testes unitários GUT AAA validando todas as condições de contorno de movimento autoritativo e rejeição de anomalias.

### 7.6 Snapshot Interpolation & Visualização de Peers Remotos

- [ ] Implementar `RemotePeerEntity` no domínio do cliente para rastreamento de jogadores remotos.
- [ ] Consumo de `QuanticNet.get_remote_state()` no `_process` destravado do cliente.
- [ ] Renderização e interpolação visual suave de avatares remotos conectados no mesmo servidor via buffer nativo C++ do QuanticNet (zero jitter / zero stuttering).

---

## Fase 8: Test Harness de Hacks & Core Gameplay de Lineage II

### 8.1 Test Harness de Hacks (Injeção e Resiliência WAN)

- [ ] *(Esta subfase será detalhada e iterada quando concluída a Fase 7)*:
  - Painel `HackInjectorPanel` no DebugHUD: Injeção de Speedhack, Teleporte, No-Clip e Flyhack.
  - Validação de 100% de interceptação e tolerância elástica do servidor sob ataque em rede pública.

### 8.2 Core Gameplay de Lineage II sobre QuanticNet

- [ ] *(Esta subfase será detalhada e iterada quando concluída a Fase 7)*:
  - Sistema de Targeting clássico de L2 e modos de movimento Click-to-Move + WASD.
  - Sincronização de estados de ação (Walk/Run, Sit/Stand, Auto-Attack, Cast) via canais QuanticNet.
  - Testes de estresse com múltiplos peers concorrentes.
