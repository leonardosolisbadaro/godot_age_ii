# GEMINI.md - A Constituição Arquitetural (godot_age_ii)

## Preâmbulo

Este documento é a **constituição absoluta e soberana** deste projeto. As regras, diretrizes, padrões e fluxos aqui descritos orientam de forma estrita o comportamento da Inteligência Artificial (IA) e de qualquer desenvolvedor humano que interaja com esta base de código.

## 1. O PROTOCOLO GEMINI (Fluxo de Trabalho Obrigatório)

A IA deve operar **estritamente** no seguinte ciclo de 3 passos:

1. **Passo 1: Análise e Plano de Ação:** Ao receber uma demanda, mapear o contexto completo (`TODO.md`, dependências). Responder apenas com um Plano de Ação detalhado.
2. **Passo 2: Refinamento:** Se houver ambiguidades técnicas, questionar antes de gerar código.
3. **Passo 3: Execução Bloqueada:** Gerar código final **APENAS** após aprovação explícita ("Aprovado" ou "Pode avançar").

## 2. RESTRIÇÕES FUNDAMENTAIS

- **Vazar Lógica para o Plugin:** O submódulo `addons/quantic_net` é uma **caixa preta** agnóstica de rede.
- **Acoplamento Visual (UI-Bound Logic):** Camada de apresentação (.tscn) atua estritamente como *visualizadora*.
- **Sem AutoLoads de Estado:** Toda injeção no domínio deve ser explícita via construtor.
- **Uso de preload:** Utilize `preload` com caminhos absolutos (`res://`) para carregar dependências.

## 3. ARQUITETURA (Clean Architecture)

1. **Core Domain (`src/domain/`):** Regras de negócio puras, agnóstico à Engine e à Rede.
2. **Use Cases (`src/use_cases/`):** Orquestram o fluxo de ações dos jogadores.
3. **Interface Adapters (`src/adapters/`):** Tradutores de limites entre Domínio e nós da Engine/Rede.
4. **Framework & Infrastructure (`src/infrastructure/` e `addons/`):** Nós da Godot e consumo do QuanticNet.

## 4. O MANDATO DE TESTES (TDD Obrigatório)

Nenhuma mecânica nova pode ser implementada sem um teste unitário a justificá-la.

- **Metodologia AAA:** Cada teste deve ser estruturado em **Arrange**, **Act** e **Assert**.
- **Framework Obrigatório:** **bitwes/Gut**.

## 5. CABEÇALHO PADRÃO DE ARQUIVOS (GDScript)

```gdscript
## @file [nome_do_arquivo.gd]
## @path [caminho/relativo/nome_do_arquivo.gd]
##
## @description
## Descrição clara da responsabilidade arquitetural.
##
## @created 2026-08-18
## @updated 2026-08-18
##
## @author Leonardo S. Badaró
```
