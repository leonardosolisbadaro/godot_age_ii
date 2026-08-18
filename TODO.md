# TODO - godot_age_ii

Roadmap e tarefas de implementação governadas por TDD e Clean Architecture.

## Fase 1: Fundação & Core Domain
- [ ] Definir entidades de domínio e regras de negócio puras em `src/domain/`
- [ ] Implementar testes unitários GUT (Arrange, Act, Assert) em `tests/`
- [ ] Implementar Casos de Uso em `src/use_cases/`

## Fase 2: Adaptação & Rede QuanticNet
- [ ] Criar adaptadores de rede cliente/servidor em `src/adapters/`
- [ ] Configurar sincronização de entidades via QuanticNet

## Fase 3: Apresentação & Validação
- [ ] Instanciar nós visuais em `src/infrastructure/`
- [ ] Validar sessões multiplayer com `toggle_instance.ps1`