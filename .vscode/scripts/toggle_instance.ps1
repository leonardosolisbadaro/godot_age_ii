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