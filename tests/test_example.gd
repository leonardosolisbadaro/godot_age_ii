## @file test_example.gd
## @path res://tests/test_example.gd
##
## @description
## Teste unitário modelo estruturado rigorosamente em Arrange, Act e Assert (AAA)
## utilizando o framework bitwes/Gut para Godot 4.7.
##
## @created 2026-08-18
## @updated 2026-08-18
##
## @author Leonardo S. Badaró
extends GutTest


func test_exemplo_estrutura_aaa() -> void:
	# 1. Arrange (Preparação de Dados e Dependências)
	var valor_a: int = 10
	var valor_b: int = 20

	# 2. Act (Execução do SUT / Regra de Domínio)
	var resultado: int = valor_a + valor_b

	# 3. Assert (Verificação do Contrato)
	assert_eq(resultado, 30, "A soma de 10 + 20 deve resultar exatamente em 30")


func test_exemplo_validacao_de_logica_pura() -> void:
	# 1. Arrange
	var inventario: Array[String] = ["Espada de Bronze", "Pocao de Vida"]

	# 2. Act
	inventario.append("Escudo de Madeira")

	# 3. Assert
	assert_eq(inventario.size(), 3, "O inventario deve conter 3 itens")
	assert_true(inventario.has("Escudo de Madeira"), "O item adicionado deve estar presente")