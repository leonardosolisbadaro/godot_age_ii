$ErrorActionPreference = "SilentlyContinue"
$godotExe = "C:\Users\LEONARDO\Documents\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
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
    Start-Process -FilePath $godotExe -ArgumentList "--path `"$projectPath`" -- --client" -WorkingDirectory $projectPath
    # Start-Process -FilePath $godotExe -ArgumentList "--path `"$projectPath`" -- --client --netem" -WorkingDirectory $projectPath
}