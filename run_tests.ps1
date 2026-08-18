$godotExe = "C:\Users\LEONARDO\Documents\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
$projectPath = $PSScriptRoot

Write-Host "`n[*] Executando Suite de Testes Unitarios GUT (TDD)..." -ForegroundColor Cyan
& $godotExe --path $projectPath --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit