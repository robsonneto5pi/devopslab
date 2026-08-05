#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Remove a Financial App do cluster Kubernetes
.DESCRIPTION
    Apaga o namespace financial e todos os recursos dentro dele.
    Solicita confirmação antes de deletar (use -Force para pular).
.PARAMETER Namespace
    Namespace alvo (default: financial)
.PARAMETER Force
    Pula a confirmação interativa
.EXAMPLE
    .\cleanup.ps1
    .\cleanup.ps1 -Force
    .\cleanup.ps1 -Namespace financial -Force
#>
param(
    [string]$Namespace = "financial",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$InfoColor  = "Cyan"
$OkColor    = "Green"
$WarnColor  = "Yellow"
$ErrorColor = "Red"

function Write-Info { param($msg) Write-Host "[INFO]  " -ForegroundColor $InfoColor  -NoNewline; Write-Host $msg }
function Write-Ok   { param($msg) Write-Host "[OK]    " -ForegroundColor $OkColor    -NoNewline; Write-Host $msg }
function Write-Warn { param($msg) Write-Host "[WARN]  " -ForegroundColor $WarnColor  -NoNewline; Write-Host $msg }
function Write-Err  { param($msg) Write-Host "[ERROR] " -ForegroundColor $ErrorColor -NoNewline; Write-Host $msg }

# ── Verificar se namespace existe ─────────────────────────────────────────────

Write-Info "Verificando namespace: $Namespace"
kubectl get namespace $Namespace 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warn "Namespace '$Namespace' não encontrado — nada a remover"
    exit 0
}
Write-Ok "Namespace '$Namespace' encontrado"

# ── Confirmação ───────────────────────────────────────────────────────────────

if (-not $Force) {
    Write-Warn "Esta operação vai deletar o namespace '$Namespace' e TODOS os recursos dentro dele."
    Write-Warn "O namespace 'app' (Desafio 4) NÃO será afetado."
    $confirm = Read-Host "Digite 'yes' para confirmar"
    if ($confirm -ne "yes") {
        Write-Info "Operação cancelada"
        exit 0
    }
}

# ── Deletar namespace ─────────────────────────────────────────────────────────

Write-Info "Deletando namespace '$Namespace'..."
try {
    kubectl delete namespace $Namespace --wait=true --timeout=120s
    if ($LASTEXITCODE -ne 0) { throw "kubectl delete retornou exit code $LASTEXITCODE" }
    Write-Ok "Namespace '$Namespace' deletado com sucesso"
} catch {
    Write-Err "Falha ao deletar namespace: $_"
    exit 1
}

# ── Verificar remoção ─────────────────────────────────────────────────────────

Write-Info "Confirmando remoção..."
kubectl get namespace $Namespace 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Ok "Namespace '$Namespace' removido ✓"
} else {
    Write-Warn "Namespace ainda existe — pode levar alguns segundos para finalizar"
    Write-Info "Verifique com: kubectl get namespace $Namespace"
}

# ── Confirmar que o Desafio 4 não foi afetado ─────────────────────────────────

Write-Info "Verificando que namespace 'app' (Desafio 4) continua intacto..."
kubectl get all -n app 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Ok "Namespace 'app' intacto ✓"
} else {
    Write-Warn "Namespace 'app' não encontrado — verifique o estado do Desafio 4"
}

Write-Ok "Cleanup concluído"
