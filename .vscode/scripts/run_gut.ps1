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
    $godotExe = "C:\Users\LEONARDO\Documents\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
    Write-Host "Rodando suite GUT para a Demo: $demoRoot" -ForegroundColor Magenta
    
    # Chama a CLI do GUT na pasta da demo ativa
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$demoRoot`" --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit" -Wait -NoNewWindow
} else {
    Write-Host "Nenhum projeto Godot encontrado a partir de: $ActiveFile" -ForegroundColor Red
}