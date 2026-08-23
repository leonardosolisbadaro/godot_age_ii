# TODO - godot_age_ii

Roadmap e tarefas de implementação governadas por TDD, Clean Architecture e Fidelidade 1:1 (Lineage II / UE2 -> Godot 4.7).

---

## Fases Anteriores (Concluídas e Arquivadas)

- [x] **Fase 1: Pipeline de Extração e Engenharia Reversa:** Decodificador de pacotes UE2, compilação de texturas (DXT/P8/G8), malhas estáticas e shaders de terreno 1:1.
- [x] **Fase 2: Core Domain & Regras de Negócio Puras:** Entidades de domínio imutáveis, amostradores matemáticos HeightfieldSampler O(1) e testes GUT AAA.
- [x] **Fase 3: Casos de Uso & Adaptadores:** Arquitetura limpa desacoplada, streaming sob demanda de chunks e gerenciamento de recursos.
- [x] **Fase 4: Infraestrutura Gráfica & Shaders:** Renderização MultiMeshInstance3D de alta performance, shaders splatmap multi-camada e volumes locais de água.
- [x] **Fase 5: Integração e Validação Interativa:** Orquestração da cena principal, câmera orbital MMORPG em 3ª pessoa e Mini-IDE DebugHUD in-game.
- [x] **Fase 6: Refinamento Arquitetural & Qualidade:** Eliminação de redundâncias, bake binário de colisões, precisão milimétrica e deltas puros em arquivos `*_fix.json`.

---

## Fase 7: NavMesh, Netcode Autoritativo com Mínimo Custo de CPU & Test Harness de Hacks

### 7.1 Geração e Integração da NavMesh Definitiva do Servidor (Passo 1)
- [x] Criar ferramenta CLI de compilação offline `tools/bake_navmesh.py` e script de motor `src/infrastructure/bake_navmesh.gd` que combina a geometria do terreno (`heightfield.bin` sem quads de caverna) e os colisores simplificados de todas as StaticMeshes de cada chunk em `assets/maps/<chunk>/server/navmesh.res`.
- [x] Carregar a `navmesh.res` de cada chunk ativo no servidor dedicado (`ServerWorldManager`) para consultas instantâneas $O(1)$ de navegabilidade e rotas $A^*$.
- [x] Suporte a validação de pontos navegáveis em rampas, pontes e desvio automático de construções, muralhas e árvores sem custo de CPU em tempo real.

### 7.2 Conexão Bare-Metal UDP & Handshake sem DTLS (Passo 2)
- [ ] Implementar flag `enable_dtls: bool = false` no QuanticNet e nos orquestradores para permitir conexões UDP bare-metal diretas entre diferentes máquinas e provedores de internet sem restrição de certificados.
- [ ] Conectar o `ClientOrchestrator` ao `ServerOrchestrator` configurando limite de strikes para testes (`max_strikes = 9999` warnings).
- [ ] Atualizar métricas de RTT (Ping), Jitter e Packet Loss na janela de Telemetria Técnica (`F2`) via `QuanticNet.pong_received`.

### 7.3 Janela de Injeção de Hacks no DebugHUD (Passo 3 - Test Harness)
- [ ] Criar janela/menu `Ferramentas > Injetor de Hacks (Debug)` no `DebugHUD`:
  - Botão `[Speedhack x5]`: força envio de movimentação com velocidade 5x superior.
  - Botão `[Teleporte Forçado +30m]`: força deslocamento brusco ilegal.
  - Botão `[No-Clip / Entrar na Parede]`: desativa colisão local e tenta mover para dentro de um obstáculo sólido.
  - Botão `[Flyhack +15m]`: tenta andar no ar sem sustentação de terreno.
- [ ] Exibir notificação visual/contador de Snapbacks no HUD confirmando a interceptação e correção pelo servidor em tempo real.

### 7.4 Simulação State-Based Autoritativa com Baixíssimo Custo de CPU (Passo 4)
- [ ] Transmissão de estados locais via `submit_state()` no canal `CH_STATE` nativo do QuanticNet.
- [ ] Validação autoritativa em microssegundos no servidor (sem nós pesados de física na SceneTree):
  - Validação de coordenadas contra a NavMesh pré-compilada do chunk (rejeição de posições fora da malha navegável ou dentro de obstáculos).
  - Validação de velocidade linear com **tolerância elástica** calibrada (considerando velocidade máxima do avatar, $\Delta t$ e compensação de jitter/RTT).
  - Validação de altitude vertical ($Y$) contra o `HeightfieldSampler` do terreno.
- [ ] Disparo de Snapback autoritativo pelo servidor quando qualquer limite for violado.
- [ ] Conectar e processar o sinal `snapback_received` no `PlayerAvatar`: reconciliação instantânea da posição do avatar com descarte de predições inválidas após correção do servidor.

### 7.5 Validação e Testes de Resiliência do Servidor Sob Ataque (Passo 5)
- [ ] Testes unitários GUT AAA do validador de movimento autoritativo.
- [ ] Teste interativo in-game: disparar hacks pela janela do HUD e comprovar que o servidor intercepta 100% das tentativas aplicando Snapbacks suaves e precisos sem desconectar o peer (`max_strikes = 9999`).
