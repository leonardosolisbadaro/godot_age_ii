# godot_age_ii

Projeto desenvolvido em **Godot Engine 4.7** com arquitetura limpa (**Clean Architecture**), desenvolvimento orientado a testes (**TDD Rigoroso**) e motor de rede distribuído **QuanticNet**.

---

## 🏛️ Estrutura Arquitetural

```text
godot_age_ii/
├── addons/
│   ├── quantic_net/       # Junction para o plugin de rede QuanticNet
│   └── gut/               # Framework de Testes Unitários GUT
├── src/
│   ├── domain/            # Regras de Negócio Puras (Agnóstico à Engine)
│   ├── use_cases/         # Casos de Uso da Aplicação
│   ├── adapters/          # Adaptadores de Limites (Rede, Serialização)
│   └── infrastructure/    # Nós Godot, Shaders e Apresentação
├── tests/                 # Suíte de Testes Unitários (AAA / GUT)
├── assets/                # Modelos, Texturas e Áudio
├── project.godot          # Configuração da Engine Godot 4.7
├── toggle_instance.ps1    # Script de Execução (1 Server + 2 Clients)
└── run_tests.ps1          # Executor Headless de Testes GUT
```

---

## 🧪 Como Executar os Testes Unitários

```powershell
.\run_tests.ps1
```

---

## 🎮 Como Iniciar o Projeto (Multiplayer Local)

```powershell
.\toggle_instance.ps1
```
