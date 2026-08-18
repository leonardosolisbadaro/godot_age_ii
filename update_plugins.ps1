Write-Host "`n[*] Atualizando Submodulos Git para a ultima versao oficial..." -ForegroundColor Cyan
cmd /c "git submodule update --remote --merge"
Write-Host "[OK] Plugins atualizados com sucesso!" -ForegroundColor Green