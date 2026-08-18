<#
.SYNOPSIS
    Script Standalone para Inicialização de Novo Projeto Godot 4.7 (Clean Architecture + TDD + Git Submodules)

.DESCRIPTION
    Este script pode ser copiado para qualquer pasta vazia no sistema e executado.
    Ele cria todos os arquivos base necessários para iniciar um projeto profissional no Godot 4.7:
      - Arquitetura Clean (src/domain, src/use_cases, src/adapters, src/infrastructure)
      - Suíte TDD com exemplo GUT (AAA) em tests/
      - Arquivos de Governança (GEMINI.md, TODO.md, CHANGELOG.md, README.md)
      - Configurações de Lint e VS Code (.editorconfig, .markdownlint.json, .gitignore, .vscode/)
      - Submódulo Git Oficial do QuanticNet (https://github.com/leonardosolisbadaro/godot_quantic_net.git)
      - Submódulo Git Oficial do GUT (https://github.com/bitwes/Gut.git)
      - Junction Symlinks automáticos para addons\quantic_net e addons\gut
      - Arquivos de Engine (project.godot, main.tscn, main.gd)
      - Scripts de Automação (toggle_instance.ps1, run_tests.ps1, update_plugins.ps1)
      - Geração automática de Cache e registro de GDExtension do Godot 4.7

.EXAMPLE
    .\setup_new_project.ps1
    .\setup_new_project.ps1 -ProjectName "MeuMMO"
    .\setup_new_project.ps1 -n "MeuMMO"
#>

param (
    [Parameter(Mandatory = $false)]
    [Alias("n")]
    [string]$ProjectName = "",

    [Parameter(Mandatory = $false)]
    [string]$GodotExe = "C:\Users\LEONARDO\Documents\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe",

    [Parameter(Mandatory = $false)]
    [string]$QuanticNetRepoUrl = "https://github.com/leonardosolisbadaro/godot_quantic_net.git",

    [Parameter(Mandatory = $false)]
    [string]$GutRepoUrl = "https://github.com/bitwes/Gut.git",

    [Parameter(Mandatory = $false)]
    [string]$GutBranch = "godot_4_7"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

# 1. Determina o Diretorio Raiz e Nome do Projeto
$ProjectRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = Split-Path $ProjectRoot -Leaf
}

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host " [*] INICIALIZADOR DE NOVO PROJETO GODOT 4.7 (STANDALONE)" -ForegroundColor Cyan
Write-Host " [*] Projeto: $ProjectName" -ForegroundColor Yellow
Write-Host " [*] Pasta  : $ProjectRoot" -ForegroundColor DarkGray
Write-Host "=======================================================`n" -ForegroundColor Cyan

# Helper para gravar UTF-8 sem BOM com tratamento de permissões e atributos
function Write-Utf8NoBom {
    param([string]$FilePath, [string]$Content)
    $dir = Split-Path $FilePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (Test-Path $FilePath) {
        if (Test-Path $FilePath -PathType Container) {
            Remove-Item -LiteralPath $FilePath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
        } else {
            try {
                $item = Get-Item -LiteralPath $FilePath -Force
                if ($item.IsReadOnly) { $item.IsReadOnly = $false }
                $item.Attributes = [System.IO.FileAttributes]::Normal
            } catch {}
        }
    }
    $utf8NoBom = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllText($FilePath, $Content, $utf8NoBom)
}

$CurrentDate = Get-Date -Format "yyyy-MM-dd"

$GodotGuiExe = $GodotExe
if ($GodotGuiExe -match "_console\.exe$") {
    $GodotGuiExe = $GodotGuiExe -replace "_console\.exe$", ".exe"
}
$GodotExeEscaped = $GodotExe.Replace("\", "\\")
$GodotGuiExeEscaped = $GodotGuiExe.Replace("\", "\\")

# [1/5] Criação da Estrutura de Diretórios (Clean Architecture & TDD)
Write-Host "[1/5] Criando topologia de pastas Clean Architecture..." -ForegroundColor White

$Directories = @(
    ".vscode",
    ".vscode\scripts",
    "src\domain",
    "src\use_cases",
    "src\adapters",
    "src\infrastructure",
    "tests",
    "assets",
    "addons"
)

foreach ($dir in $Directories) {
    $targetPath = Join-Path $ProjectRoot $dir
    if (-not (Test-Path $targetPath)) {
        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
    }
}

# [2/5] Criação dos Arquivos de Governança e Configuração
Write-Host "[2/5] Gerando arquivos de governanca e documentacao..." -ForegroundColor White

# --- .editorconfig ---
$editorConfigContent = @'
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = tab
indent_size = 4

[*.md]
indent_style = space
indent_size = 2

[*.json]
indent_style = space
indent_size = 4
'@
Write-Utf8NoBom (Join-Path $ProjectRoot ".editorconfig") $editorConfigContent

# --- .markdownlint.json ---
$markdownLintContent = @'
{
  "default": true,
  "MD013": false,
  "MD024": false,
  "MD033": false,
  "MD041": false
}
'@
Write-Utf8NoBom (Join-Path $ProjectRoot ".markdownlint.json") $markdownLintContent

# --- .gitignore ---
$gitIgnoreContent = @'
# Godot 4+ specific ignores
.godot/
.nomedia

# Godot-specific ignores
.import/
export.cfg
export_credentials.cfg

# Imported translations (automatically generated from CSV files)
*.translation

# Mono-specific ignores
.mono/
data_*/
mono_crash.*.json

# QuanticNet & External Plugin Junctions
/addons/quantic_net
/addons/gut

# OS and Editor files
.DS_Store
Thumbs.db
*.log
'@
Write-Utf8NoBom (Join-Path $ProjectRoot ".gitignore") $gitIgnoreContent

# --- Configurações do VS Code (.vscode) ---

# --- .vscode/settings.json ---
$vscodeSettingsContent = @'
{
  "files.exclude": {
    // "**/addons": true,
    "**/*.uid": true
  },
  "editor.formatOnSave": false,
  "godotTools.editorPath.godot4": "{{GODOT_GUI_EXE_ESCAPED}}",
  "godot_tools.gdscript_lsp_server_port": 6005,
  "[gdscript]": {
    "editor.insertSpaces": false,
    "editor.tabSize": 4,
    "editor.defaultFormatter": "DoHe.godot-format"
  },
  "[json]": {
    "editor.insertSpaces": true,
    "editor.tabSize": 2,
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[jsonc]": {
    "editor.insertSpaces": true,
    "editor.tabSize": 2,
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  }
}
'@
$vscodeSettingsContent = $vscodeSettingsContent.Replace("{{GODOT_GUI_EXE_ESCAPED}}", $GodotGuiExeEscaped)
Write-Utf8NoBom (Join-Path $ProjectRoot ".vscode\settings.json") $vscodeSettingsContent

# --- .vscode/tasks.json ---
$vscodeTasksContent = @'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Godot LSP: Run Headless",
      "type": "shell",
      "command": "{{GODOT_GUI_EXE_ESCAPED}}",
      "args": ["-e", "--headless"],
      "isBackground": true,
      "problemMatcher": {
        "pattern": {
          "regexp": "^$"
        },
        "background": {
          "activeOnStart": true,
          "beginsPattern": ".*",
          "endsPattern": ".*"
        }
      },
      "presentation": {
        "reveal": "never",
        "panel": "dedicated"
      },
      "runOptions": {
        "runOn": "folderOpen"
      }
    },
    {
      "label": "GUT: Run Tests",
      "type": "shell",
      "command": "powershell.exe",
      "args": [
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "${workspaceFolder}\\.vscode\\scripts\\run_gut.ps1",
        "${file}"
      ],
      "group": "test",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": true,
        "panel": "shared",
        "clear": true
      }
    },
    {
      "label": "Godot: Run Default Scene",
      "type": "shell",
      "command": "{{GODOT_GUI_EXE_ESCAPED}}",
      "args": [
        "--path",
        "${fileDirname}"
      ],
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": true,
        "panel": "shared",
        "clear": true
      }
    },
    {
      "label": "Godot: Kill Processes",
      "type": "shell",
      "command": "Get-CimInstance Win32_Process | Where-Object { $_.Name -like 'Godot*' -and $_.CommandLine -notmatch '--headless' } | Invoke-CimMethod -MethodName Terminate",
      "presentation": {
        "reveal": "silent"
      }
    },
    {
      "label": "Project: Toggle Instance",
      "type": "shell",
      "command": "powershell.exe",
      "args": [
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "${workspaceFolder}\\.vscode\\scripts\\toggle_instance.ps1",
        "${file}"
      ],
      "presentation": {
        "reveal": "silent",
        "panel": "shared"
      }
    }
  ]
}
'@
$vscodeTasksContent = $vscodeTasksContent.Replace("{{GODOT_GUI_EXE_ESCAPED}}", $GodotGuiExeEscaped)
Write-Utf8NoBom (Join-Path $ProjectRoot ".vscode\tasks.json") $vscodeTasksContent

# --- .vscode/scripts/run_gut.ps1 ---
$vscodeRunGutContent = @'
param (
    [string]$ActiveFile
)

$currentDir = Split-Path $ActiveFile -Parent
$demoRoot = $null

# Varre a árvore para encontrar a raiz do projeto (demo atual)
while ($currentDir -ne $null -and $currentDir -ne "") {
    if (Test-Path (Join-Path $currentDir "project.godot")) {
        $demoRoot = $currentDir
        break
    }
    $currentDir = Split-Path $currentDir -Parent
}

if ($demoRoot) {
    $godotExe = "{{GODOT_EXE}}"
    Write-Host "Rodando suite GUT para a Demo: $demoRoot" -ForegroundColor Magenta
    
    # Chama a CLI do GUT na pasta da demo ativa
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$demoRoot`" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit" -Wait -NoNewWindow
} else {
    Write-Host "Nenhum projeto Godot encontrado a partir de: $ActiveFile" -ForegroundColor Red
}
'@
$vscodeRunGutContent = $vscodeRunGutContent.Replace("{{GODOT_EXE}}", $GodotExe)
Write-Utf8NoBom (Join-Path $ProjectRoot ".vscode\scripts\run_gut.ps1") $vscodeRunGutContent

# --- .vscode/scripts/toggle_instance.ps1 ---
$vscodeToggleInstanceContent = @'
param (
    [string]$ActiveFile
)

$currentDir = Split-Path $ActiveFile -Parent
$projectRoot = $null

# Varre a árvore de diretórios para cima buscando o project.godot
while ($currentDir -ne $null -and $currentDir -ne "") {
    if (Test-Path (Join-Path $currentDir "project.godot")) {
        $projectRoot = $currentDir
        break
    }
    $currentDir = Split-Path $currentDir -Parent
}

if ($projectRoot) {
    $toggleScript = Join-Path $projectRoot "toggle_instance.ps1"
    if (Test-Path $toggleScript) {
        Write-Host "Contexto Ativo Encontrado: $projectRoot" -ForegroundColor Magenta
        Write-Host "Executando toggle_instance.ps1..." -ForegroundColor Cyan
        & $toggleScript
    } else {
        Write-Host "Arquivo toggle_instance.ps1 não encontrado na raiz deste projeto ($projectRoot)." -ForegroundColor Red
    }
} else {
    Write-Host "Nenhum projeto Godot (project.godot) encontrado no caminho: $ActiveFile" -ForegroundColor Yellow
}
'@
Write-Utf8NoBom (Join-Path $ProjectRoot ".vscode\scripts\toggle_instance.ps1") $vscodeToggleInstanceContent

# --- GEMINI.md ---
$geminiContent = @'
# GEMINI.md - A Constituição Arquitetural ({{PROJECT_NAME}})

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
## @created {{CURRENT_DATE}}
## @updated {{CURRENT_DATE}}
##
## @author Leonardo S. Badaró (with Gemini 3.7 Flash - High)
```
'@
$geminiContent = $geminiContent.Replace("{{PROJECT_NAME}}", $ProjectName).Replace("{{CURRENT_DATE}}", $CurrentDate)
Write-Utf8NoBom (Join-Path $ProjectRoot "GEMINI.md") $geminiContent

# --- TODO.md ---
$todoContent = @'
# TODO - {{PROJECT_NAME}}

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
'@
$todoContent = $todoContent.Replace("{{PROJECT_NAME}}", $ProjectName)
Write-Utf8NoBom (Join-Path $ProjectRoot "TODO.md") $todoContent

# --- CHANGELOG.md ---
$changelogContent = @'
# Changelog

Todas as alterações relevantes para o projeto **{{PROJECT_NAME}}** serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]
### Adicionado
- Inicialização da estrutura base do projeto com Clean Architecture e TDD.
- Configuração do plugin QuanticNet e ambiente Godot 4.7.
'@
$changelogContent = $changelogContent.Replace("{{PROJECT_NAME}}", $ProjectName)
Write-Utf8NoBom (Join-Path $ProjectRoot "CHANGELOG.md") $changelogContent

# --- README.md ---
$readmeContent = @'
# {{PROJECT_NAME}}

Projeto desenvolvido em **Godot Engine 4.7** com arquitetura limpa (**Clean Architecture**), desenvolvimento orientado a testes (**TDD Rigoroso**) e motor de rede distribuído **QuanticNet**.

---

## 🏛️ Estrutura Arquitetural

```
{{PROJECT_NAME}}/
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
'@
$readmeContent = $readmeContent.Replace("{{PROJECT_NAME}}", $ProjectName)
Write-Utf8NoBom (Join-Path $ProjectRoot "README.md") $readmeContent

# [3/5] Configuração de Submódulos Git e Junctions
Write-Host "[3/5] Configurando Submodulos Git e Junction Links para os plugins..." -ForegroundColor White

$hasGit = (Get-Command git -ErrorAction SilentlyContinue) -ne $null
if (-not $hasGit) {
    throw "Git nao foi encontrado no PATH do sistema. O Git e obrigatorio para clonar os submodulos oficiais."
}

# Garante que o projeto é um repositório Git
if (-not (Test-Path (Join-Path $ProjectRoot ".git"))) {
    Write-Host "  -> Inicializando repositorio Git local..." -ForegroundColor DarkGray
    cmd /c "git init -q" | Out-Null
}

$submodulesDir = Join-Path $ProjectRoot "submodules"
$quanticNetSubmoduleDir = Join-Path $submodulesDir "godot_quantic_net"
$gutSubmoduleDir = Join-Path $submodulesDir "gut"

# Adiciona submódulo oficial do QuanticNet se ainda não existir
if (-not (Test-Path $quanticNetSubmoduleDir)) {
    Write-Host "  -> Clonando submodulo oficial QuanticNet ($QuanticNetRepoUrl)..." -ForegroundColor Cyan
    cmd /c "git submodule add --force `"$QuanticNetRepoUrl`" `"submodules/godot_quantic_net`""
}

# Adiciona submódulo oficial do GUT se ainda não existir
if (-not (Test-Path $gutSubmoduleDir)) {
    Write-Host "  -> Clonando submodulo oficial GUT ($GutRepoUrl - Branch: $GutBranch)..." -ForegroundColor Cyan
    cmd /c "git submodule add -b $GutBranch --force `"$GutRepoUrl`" `"submodules/gut`""
}

# Inicializa/atualiza os submódulos recursivamente
cmd /c "git submodule update --init --recursive"

$quanticNetSourceFinal = Join-Path $quanticNetSubmoduleDir "addons\quantic_net"
$gutSourceFinal = Join-Path $gutSubmoduleDir "addons\gut"

$AddonsDir = Join-Path $ProjectRoot "addons"
$QuanticNetTarget = Join-Path $AddonsDir "quantic_net"
$GutTarget = Join-Path $AddonsDir "gut"

# Cria Junction para addons\quantic_net
if (Test-Path $quanticNetSourceFinal) {
    if (Test-Path $QuanticNetTarget) {
        Remove-Item -Path $QuanticNetTarget -Force -Recurse -ErrorAction SilentlyContinue
    }
    Write-Host "  -> Criando Junction: addons\quantic_net -> $quanticNetSourceFinal" -ForegroundColor Green
    cmd /c mklink /J "$QuanticNetTarget" "$quanticNetSourceFinal" | Out-Null
} else {
    throw "Falha ao localizar o diretorio 'addons/quantic_net' no submodulo clonado em $quanticNetSubmoduleDir"
}

# Cria Junction para addons\gut
if (Test-Path $gutSourceFinal) {
    if (Test-Path $GutTarget) {
        Remove-Item -Path $GutTarget -Force -Recurse -ErrorAction SilentlyContinue
    }
    Write-Host "  -> Criando Junction: addons\gut -> $gutSourceFinal" -ForegroundColor Green
    cmd /c mklink /J "$GutTarget" "$gutSourceFinal" | Out-Null
} else {
    throw "Falha ao localizar o diretorio 'addons/gut' no submodulo clonado em $gutSubmoduleDir"
}

# [4/5] Criação dos Arquivos da Engine Godot 4.7
Write-Host "[4/5] Gerando arquivos da engine (project.godot, main.tscn, main.gd, testes e scripts)..." -ForegroundColor White

# --- project.godot ---
$projectGodotContent = @'
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="{{PROJECT_NAME}}"
run/main_scene="res://main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"

[autoload]

QuanticNet="*res://addons/quantic_net/src/infrastructure/quantic_net_autoload.gd"

[display]

window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[editor_plugins]

enabled=PackedStringArray("res://addons/quantic_net/plugin.cfg", "res://addons/gut/plugin.cfg")

[physics]

3d/physics_engine="Jolt Physics"

[rendering]

rendering_device/driver.windows="d3d12"
renderer/rendering_method="forward_plus"
'@
$projectGodotContent = $projectGodotContent.Replace("{{PROJECT_NAME}}", $ProjectName)
Write-Utf8NoBom (Join-Path $ProjectRoot "project.godot") $projectGodotContent

# --- main.tscn ---
$mainTscnContent = @'
[gd_scene load_steps=2 format=3 uid="uid://b410e8s210e31"]

[ext_resource type="Script" path="res://main.gd" id="1_main"]

[node name="Main" type="Node3D"]
script = ExtResource("1_main")
'@
Write-Utf8NoBom (Join-Path $ProjectRoot "main.tscn") $mainTscnContent

# --- main.gd ---
$mainGdContent = @'
## @file main.gd
## @path res://main.gd
##
## @description
## Ponto de entrada do projeto {{PROJECT_NAME}}.
## Orquestra a inicialização do Servidor Autoritativo (--server) ou Cliente (--client).
##
## @created {{CURRENT_DATE}}
## @updated {{CURRENT_DATE}}
##
## @author Leonardo S. Badaró (with Gemini 3.7 Flash - High)
extends Node3D

const PORT := 4242
const SECRET := "secret"

var _is_server: bool = false


func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	_is_server = "--server" in args

	if _is_server:
		_start_server()
	else:
		_start_client()


func _start_server() -> void:
	DisplayServer.window_set_title("{{PROJECT_NAME}} [SERVER]")
	print("\n=======================================================")
	print("[SERVER] Servidor Autoritativo Inicializado na Porta %d" % PORT)
	print("=======================================================\n")
	
	var qn = get_node_or_null("/root/QuanticNet")
	if qn and qn.has_method("host"):
		qn.host(PORT, SECRET)
	else:
		push_warning("QuanticNet Autoload nao carregado.")


func _start_client() -> void:
	DisplayServer.window_set_title("{{PROJECT_NAME}} [CLIENT]")
	print("\n=======================================================")
	print("[CLIENT] Cliente Inicializado — Conectando ao Servidor...")
	print("=======================================================")
	
	var qn = get_node_or_null("/root/QuanticNet")
	if qn and qn.has_method("join"):
		var args = OS.get_cmdline_user_args()
		var use_netem = "--netem" in args
		qn.join("127.0.0.1", PORT, SECRET, use_netem)
		get_tree().set_multiplayer(qn.get_tree().get_multiplayer(qn.get_path()), self.get_path())
'@
$mainGdContent = $mainGdContent.Replace("{{PROJECT_NAME}}", $ProjectName).Replace("{{CURRENT_DATE}}", $CurrentDate)
Write-Utf8NoBom (Join-Path $ProjectRoot "main.gd") $mainGdContent

# --- tests/test_example.gd (TDD AAA Template) ---
$testExampleContent = @'
## @file test_example.gd
## @path res://tests/test_example.gd
##
## @description
## Teste unitário modelo estruturado rigorosamente em Arrange, Act e Assert (AAA)
## utilizando o framework bitwes/Gut para Godot 4.7.
##
## @created {{CURRENT_DATE}}
## @updated {{CURRENT_DATE}}
##
## @author Leonardo S. Badaró (with Gemini 3.7 Flash - High)
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
'@
$testExampleContent = $testExampleContent.Replace("{{CURRENT_DATE}}", $CurrentDate)
Write-Utf8NoBom (Join-Path $ProjectRoot "tests\test_example.gd") $testExampleContent

# --- toggle_instance.ps1 ---
$toggleInstanceContent = @'
$ErrorActionPreference = "SilentlyContinue"
$godotExe = "{{GODOT_EXE}}"
$projectPath = $PSScriptRoot

$projectName = Split-Path $projectPath -Leaf
$godotExeBase = [System.IO.Path]::GetFileNameWithoutExtension($godotExe)
$runningInstances = Get-CimInstance Win32_Process -Filter "Name LIKE '$godotExeBase%'" | Where-Object { 
    $_.CommandLine -match $projectName -and 
    ($_.CommandLine -match "--client" -or $_.CommandLine -match "--server")
}

if ($runningInstances) {
    Write-Host "Encerrando instancias ativas do $projectName..." -ForegroundColor Yellow
    foreach ($proc in $runningInstances) { Stop-Process -Id $proc.ProcessId -Force }
} else {
    Write-Host "Iniciando $projectName (1 Server + 2 Clients)..." -ForegroundColor Cyan
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$projectPath`" --headless -- --server" -WorkingDirectory $projectPath
    
    Write-Host "Aguardando inicializacao do Server..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
    
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$projectPath`" -- --client" -WorkingDirectory $projectPath
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$projectPath`" -- --client --netem" -WorkingDirectory $projectPath
}
'@
$toggleInstanceContent = $toggleInstanceContent.Replace("{{GODOT_EXE}}", $GodotExe)
Write-Utf8NoBom (Join-Path $ProjectRoot "toggle_instance.ps1") $toggleInstanceContent

# --- run_tests.ps1 ---
$runTestsContent = @'
$godotExe = "{{GODOT_EXE}}"
$projectPath = $PSScriptRoot

Write-Host "`n[*] Executando Suite de Testes Unitarios GUT (TDD)..." -ForegroundColor Cyan
& $godotExe --path $projectPath --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
'@
$runTestsContent = $runTestsContent.Replace("{{GODOT_EXE}}", $GodotExe)
Write-Utf8NoBom (Join-Path $ProjectRoot "run_tests.ps1") $runTestsContent

# --- update_plugins.ps1 ---
$updatePluginsContent = @'
Write-Host "`n[*] Atualizando Submodulos Git para a ultima versao oficial..." -ForegroundColor Cyan
cmd /c "git submodule update --remote --merge"
Write-Host "[OK] Plugins atualizados com sucesso!" -ForegroundColor Green
'@
Write-Utf8NoBom (Join-Path $ProjectRoot "update_plugins.ps1") $updatePluginsContent

# [5/5] Geração do Cache Nativo do Godot 4.7 e Registro de GDExtension
Write-Host "[5/5] Gerando Cache da Engine Godot 4.7 e registrando GDExtensions..." -ForegroundColor White

if (Test-Path $GodotExe) {
    $logOut = Join-Path $ProjectRoot ".godot_setup_out.log"
    $logErr = Join-Path $ProjectRoot ".godot_setup_err.log"
    
    Start-Process -FilePath $GodotExe -ArgumentList "--path `"$ProjectRoot`" --headless --editor --quit" -Wait -NoNewWindow -RedirectStandardOutput $logOut -RedirectStandardError $logErr
    
    # Garante que project.godot permaneceu com a configuracao completa
    $projectGodotPath = Join-Path $ProjectRoot "project.godot"
    if ((Get-Item $projectGodotPath).Length -eq 0) {
        Write-Utf8NoBom $projectGodotPath $projectGodotContent
    }

    $extensionList = Join-Path $ProjectRoot ".godot\extension_list.cfg"
    if (Test-Path $extensionList) {
        Write-Host "  [OK] Cache e GDExtension registrados com sucesso!" -ForegroundColor Green
        Remove-Item $logOut -Force -ErrorAction SilentlyContinue
        Remove-Item $logErr -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "  [OK] Inicializacao concluida." -ForegroundColor DarkGray
    }
} else {
    Write-Host "  [!] Executavel do Godot nao encontrado em: $GodotExe." -ForegroundColor Yellow
}

Write-Host "`n=======================================================" -ForegroundColor Green
Write-Host " [V] PROJETO '$ProjectName' PRONTO PARA USO!" -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Green
Write-Host " -> Para rodar os testes     : .\\run_tests.ps1" -ForegroundColor Cyan
Write-Host " -> Para atualizar plugins   : .\\update_plugins.ps1" -ForegroundColor Cyan
Write-Host " -> Para iniciar o jogo      : .\\toggle_instance.ps1" -ForegroundColor Cyan
Write-Host "=======================================================`n" -ForegroundColor Green
