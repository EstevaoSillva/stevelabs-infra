# Teste rápido depois de subir a stack. Uso: .\scripts\teste-fumaca.ps1
$raiz = Split-Path -Parent $PSScriptRoot
$env_ = @{}
Get-Content (Join-Path $raiz ".env") | Where-Object { $_ -match "^\s*[^#].*=" } | ForEach-Object {
    $k, $v = $_ -split "=", 2; $env_[$k.Trim()] = $v.Trim()
}
$base = "http://localhost:8000"
$cab = @{ Authorization = "Bearer $($env_['AGENTES_API_KEY'])" }

Write-Host "1) Saúde do serviço e do Ollama" -ForegroundColor Cyan
Invoke-RestMethod "$base/saude" | Format-List

Write-Host "2) Modelos expostos" -ForegroundColor Cyan
(Invoke-RestMethod "$base/v1/models" -Headers $cab).data | Format-Table id, owned_by

Write-Host "3) Pedido real (pode levar alguns minutos)" -ForegroundColor Cyan
$corpo = @{
    model    = "stevelab-agentes"
    stream   = $false
    messages = @(@{ role = "user"; content = "Descreva a planilha exemplo_chamados.csv e diga qual setor tem o maior tempo médio de resolução. Cite a fonte." })
} | ConvertTo-Json -Depth 5
$r = Invoke-RestMethod "$base/v1/chat/completions" -Method Post -Headers $cab -ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($corpo)) -TimeoutSec 900
$r.choices[0].message.content
