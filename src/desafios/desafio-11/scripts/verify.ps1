#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifica a saúde do deploy da Financial App no Kubernetes
.DESCRIPTION
    Valida Deployment, Pods, Services, Ingress, HPA e PDB no namespace financial.
    Retorna exit code 0 se tudo estiver OK, 1 se alguma verificação falhar.
.PARAMETER Namespace
    Namespace alvo (default: financial)
.EXAMPLE
    .\verify.ps1
    .\verify.ps1 -Namespace financial
#>
param(
    [string]$Namespace = "financial"
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

$allHealthy = $true

# ── Namespace ─────────────────────────────────────────────────────────────────

Write-Info "Verificando namespace: $Namespace"
kubectl get namespace $Namespace 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Err "Namespace '$Namespace' não encontrado — execute deploy.ps1 primeiro"
    exit 1
}
Write-Ok "Namespace '$Namespace' existe"

# ── Deployment ────────────────────────────────────────────────────────────────

Write-Info "Verificando Deployment..."
$deploy = kubectl get deployment -n $Namespace -o json 2>&1 | ConvertFrom-Json
if ($deploy.items.Count -eq 0) {
    Write-Warn "Nenhum Deployment encontrado"
    $allHealthy = $false
} else {
    foreach ($d in $deploy.items) {
        $ready   = $d.status.readyReplicas
        $desired = $d.spec.replicas
        if ($null -eq $ready) { $ready = 0 }
        if ($ready -eq $desired) {
            Write-Ok "Deployment '$($d.metadata.name)': $ready/$desired pronto"
        } else {
            Write-Warn "Deployment '$($d.metadata.name)': $ready/$desired pronto — aguardando pods"
            $allHealthy = $false
        }
    }
}

# ── Pods ──────────────────────────────────────────────────────────────────────

Write-Info "Verificando Pods..."
$pods = kubectl get pods -n $Namespace -o json 2>&1 | ConvertFrom-Json
if ($pods.items.Count -eq 0) {
    Write-Warn "Nenhum Pod encontrado"
    $allHealthy = $false
} else {
    foreach ($pod in $pods.items) {
        $phase = $pod.status.phase
        if ($phase -eq "Running") {
            Write-Ok "Pod '$($pod.metadata.name)': $phase"
        } else {
            Write-Warn "Pod '$($pod.metadata.name)': $phase"
            $allHealthy = $false
        }
    }
}

# ── Services ──────────────────────────────────────────────────────────────────

Write-Info "Verificando Services..."
$svcs = kubectl get svc -n $Namespace -o json 2>&1 | ConvertFrom-Json
if ($svcs.items.Count -eq 0) {
    Write-Warn "Nenhum Service encontrado"
    $allHealthy = $false
} else {
    foreach ($svc in $svcs.items) {
        switch ($svc.spec.type) {
            "ClusterIP"  { Write-Ok "Service '$($svc.metadata.name)': ClusterIP=$($svc.spec.clusterIP)" }
            "NodePort"   {
                $np = $svc.spec.ports[0].nodePort
                Write-Ok "Service '$($svc.metadata.name)': NodePort=$np → http://192.168.49.2:$np"
            }
            default      { Write-Ok "Service '$($svc.metadata.name)': tipo=$($svc.spec.type)" }
        }
    }
}

# ── Ingress ───────────────────────────────────────────────────────────────────

Write-Info "Verificando Ingress..."
$ingresses = kubectl get ingress -n $Namespace -o json 2>&1 | ConvertFrom-Json
if ($ingresses.items.Count -eq 0) {
    Write-Warn "Nenhum Ingress encontrado"
    $allHealthy = $false
} else {
    foreach ($ing in $ingresses.items) {
        $hosts = ($ing.spec.rules | ForEach-Object { $_.host }) -join ", "
        Write-Ok "Ingress '$($ing.metadata.name)': hosts=$hosts → adicione ao hosts: 192.168.49.2 $hosts"
    }
}

# ── HPA ───────────────────────────────────────────────────────────────────────

Write-Info "Verificando HPA..."
$hpas = kubectl get hpa -n $Namespace -o json 2>&1 | ConvertFrom-Json
if ($hpas.items.Count -eq 0) {
    Write-Warn "Nenhum HPA encontrado"
    $allHealthy = $false
} else {
    foreach ($h in $hpas.items) {
        $cur = $h.status.currentReplicas
        $des = $h.status.desiredReplicas
        $min = $h.spec.minReplicas
        $max = $h.spec.maxReplicas
        Write-Ok "HPA '$($h.metadata.name)': current=$cur desired=$des (min=$min max=$max)"
    }
}

# ── PDB ───────────────────────────────────────────────────────────────────────

Write-Info "Verificando PDB..."
$pdbs = kubectl get pdb -n $Namespace -o json 2>&1 | ConvertFrom-Json
if ($pdbs.items.Count -eq 0) {
    Write-Warn "Nenhum PDB encontrado"
    $allHealthy = $false
} else {
    foreach ($p in $pdbs.items) {
        $minAvail    = $p.spec.minAvailable
        $disruptions = $p.status.disruptionsAllowed
        Write-Ok "PDB '$($p.metadata.name)': minAvailable=$minAvail disruptionsAllowed=$disruptions"
    }
}

# ── NetworkPolicy ─────────────────────────────────────────────────────────────

Write-Info "Verificando NetworkPolicy..."
$nps = kubectl get networkpolicy -n $Namespace -o json 2>&1 | ConvertFrom-Json
if ($nps.items.Count -eq 0) {
    Write-Warn "Nenhuma NetworkPolicy encontrada"
} else {
    foreach ($np in $nps.items) {
        Write-Ok "NetworkPolicy '$($np.metadata.name)': presente"
    }
}

# ── Resumo ────────────────────────────────────────────────────────────────────

Write-Host ""
if ($allHealthy) {
    Write-Ok "Todas as verificações passaram ✓"
    exit 0
} else {
    Write-Warn "Algumas verificações falharam — revise o output acima"
    Write-Info "Dica: kubectl get events -n $Namespace --sort-by='.lastTimestamp'"
    exit 1
}
