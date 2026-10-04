# Gera o arquivo .env a partir de um dos modelos, com segredos aleatórios.
# Uso (PowerShell, na pasta do projeto):
#   .\scripts\gerar-env.ps1 -Perfil aluno      # PC de aluno 16 GB (híbrido)
#   .\scripts\gerar-env.ps1 -Perfil local      # tudo local, só demonstração
#   .\scripts\gerar-env.ps1 -Perfil servidor   # servidor central
#   .\scripts\gerar-env.ps1 -Perfil nativo     # sem Docker (pip + Ollama nativo)
param(
    [ValidateSet("servidor", "aluno", "local", "nativo")]
    [string]$Perfil = "aluno"
)

$raiz = Split-Path -Parent $PSScriptRoot
$origem = Join-Path $raiz ".env.$Perfil.example"
$destino = Join-Path $raiz ".env"

if (Test-Path $destino) {
    Write-Host ".env já existe. Apague-o se quiser gerar de novo." -ForegroundColor Yellow
    exit 1
}

$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
function Get-Hex([int]$bytes) {
    $buffer = New-Object byte[] $bytes
    $rng.GetBytes($buffer)
    return (($buffer | ForEach-Object { $_.ToString("x2") }) -join "")
}

$linhas = Get-Content $origem -Encoding UTF8 | ForEach-Object {
    $linha = $_
    if ($linha -match "__HEX64__") { $linha = $linha.Replace("__HEX64__", (Get-Hex 32)) }
    if ($linha -match "__HEX32__") { $linha = $linha.Replace("__HEX32__", (Get-Hex 16)) }
    if ($linha -match "__SENHA__") { $linha = $linha.Replace("__SENHA__", (Get-Hex 16)) }
    $linha
}

[System.IO.File]::WriteAllLines($destino, $linhas, (New-Object System.Text.UTF8Encoding $false))
Write-Host ".env gerado a partir de .env.$Perfil.example" -ForegroundColor Green
Write-Host "Revise os endereços (IP_DO_SERVIDOR / SERVIDOR) antes de subir." -ForegroundColor Green
