#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Financial App to Kubernetes cluster
.DESCRIPTION
    Deploys the financial-app manifests to the Kubernetes cluster using kustomize.
    Verifica pré-requisitos (kubectl, docker, cluster) e suporta modo dry-run.
.PARAMETER DryRun
    Executa kubectl apply com --dry-run=client (sem deploy real)
.PARAMETER Namespace
    Namespace alvo (default: financial)
.EXAMPLE
    .\deploy.ps1
    .\deploy.ps1 -DryRun
    .\deploy.ps1 -Namespace financial
#>
param(
    [switch]$DryRun,
    [string]$Namespace = "financial"
)

$ErrorActionPreference = "Stop"

$InfoColor  = "Cyan"
$OkColor    = "Green"
$WarnColor  = "Yellow"
$ErrorColor = "Red"

function Write-Info  { param($msg) Write-Host "[INFO]  " -ForegroundColor $InfoColor  -NoNewline; Write-Host $msg }
function Write-Ok    { param($msg) Write-Host "[OK]    " -ForegroundColor $OkColor    -NoNewline; Write-Host $msg }
function Write-Warn  { param($msg) Write-Host "[WARN]  " -ForegroundColor $WarnColor  -NoNewline; Write-Host $msg }
function Write-Err   { param($msg) Write-Host "[ERROR] " -ForegroundColor $ErrorColor -NoNewline; Write-Host $msg }

# ── Pré-requisitos ────────────────────────────────────────────────────────────

Write-Info "Verificando pré-requisitos..."

try {
    $v = kubectl version --client 2>&1 | Select-String "Client"
    Write-Ok "kubectl: $v"
} catch {
    Write-Err "kubectl não encontrado ou não está no PATH"
    exit 1
}

try {
    $v = docker version --format "{{.Server.Version}}" 2>&1
    Write-Ok "docker: $v"
} catch {
    Write-Warn "docker não disponível — continuando (necessário apenas para builds locais)"
}

Write-Info "Verificando conectividade com o cluster..."
try {
    kubectl cluster-info 2>&1 | Out-Null
    Write-Ok "Cluster acessível"
} catch {
    Write-Err "Não foi possível conectar ao cluster Kubernetes"
    exit 1
}

# ── Namespace ─────────────────────────────────────────────────────────────────

Write-Info "Verificando namespace: $Namespace"
$nsExists = kubectl get namespace $Namespace 2>&1
if ($LASTEXITCODE -ne 0) {
    if ($DryRun) {
        Write-Info "Namespace '$Namespace' não existe — seria criado (dry-run)"
    } else {
        Write-Info "Namespace '$Namespace' não existe — criando..."
        kubectl create namespace $Namespace | Out-Null
        Write-Ok "Namespace '$Namespace' criado"
    }
} else {
    Write-Ok "Namespace '$Namespace' já existe"
}

# ── Localizar k8s/ ────────────────────────────────────────────────────────────

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$k8sDir    = Join-Path $scriptDir ".." "k8s"

if (-not (Test-Path $k8sDir)) {
    Write-Err "Diretório k8s/ não encontrado em: $k8sDir"
    exit 1
}

Write-Info "Usando manifests de: $k8sDir"

# ── Apply ─────────────────────────────────────────────────────────────────────

$applyArgs = @("apply", "-k", $k8sDir)

if ($DryRun) {
    $applyArgs += "--dry-run=client"
    Write-Info "Modo DRY-RUN ativo — nenhuma alteração será aplicada"
}

Write-Info "Aplicando manifests via kustomize..."
try {
    kubectl @applyArgs
    if ($LASTEXITCODE -ne 0) { throw "kubectl retornou exit code $LASTEXITCODE" }
    Write-Ok "Manifests aplicados com sucesso"
} catch {
    Write-Err "Falha ao aplicar manifests: $_"
    exit 1
}

# ── Rollout (somente deploy real) ─────────────────────────────────────────────

if (-not $DryRun) {
    Write-Info "Aguardando rollout do deployment..."
    try {
        kubectl rollout status deployment/financial-deployment `
            -n $Namespace `
            --timeout=120s
        if ($LASTEXITCODE -ne 0) { throw "rollout não concluído no tempo esperado" }
        Write-Ok "Deployment pronto"
    } catch {
        Write-Err "Deployment não ficou pronto: $_"
        Write-Info "Verifique com: kubectl describe deployment financial-deployment -n $Namespace"
        Write-Info "Logs:          kubectl logs -n $Namespace -l app=financial-app --tail=50"
        exit 1
    }

    Write-Info "Estado atual do namespace $Namespace`:"
    kubectl get all -n $Namespace
}

Write-Ok "Deploy concluído"
