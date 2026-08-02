# DevOps Lab — Setup Local Kubernetes

Guia completo para configurar um ambiente local de Kubernetes no Windows com
**Docker Desktop**, **Minikube** e **kubectl** — do zero em ~20 minutos.

---

## Documentação

Abra [`docs/index.html`](docs/index.html) no navegador para o guia interativo completo.

### Estrutura do guia

| Página | Conteúdo |
|---|---|
| `docs/index.html` | Guia principal — 7 passos + seção de pré-requisitos |
| `docs/prereqs/so.html` | Pré-requisito: Sistema Operacional |
| `docs/prereqs/wsl2.html` | Pré-requisito: WSL 2 |
| `docs/prereqs/virtualizacao.html` | Pré-requisito: Virtualização (BIOS + VirtualMachinePlatform) |
| `docs/prereqs/dotnet.html` | Pré-requisito: .NET Framework |

---

## Passos Rápidos (linha de comando)

```powershell
# 1 — PowerShell como Administrador (Win+X → Terminal Admin)

# 2 — Instalar Chocolatey
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# 3 — Instalar as ferramentas (~15-20 min)
choco install docker-desktop     -y --no-progress
choco install minikube           -y --no-progress
choco install kubernetes-cli     -y --no-progress

# 4 — Reiniciar o computador

# 5 — Abrir Docker Desktop manualmente (não faz autostart via Chocolatey)
#     Aguardar 1-2 min até estabilizar

# 6 — Novo PowerShell comum (sem admin)
minikube start --cpus=2 --memory=2048 --driver=docker

# 7 — Verificar
kubectl cluster-info
kubectl get nodes
kubectl get pods -n kube-system
```

---

## Versões Validadas

| Ferramenta | Versão |
|---|---|
| OS | Windows 11 Enterprise · Build 26200 |
| WSL | 2.6.1.0 · Kernel 6.6.87.2-1 |
| Docker Desktop | 4.84.0 · Engine 29.6.2 |
| Minikube | 1.38.1 |
| kubernetes-cli | 1.36.3 |
| Kubernetes (cluster) | v1.35.1 |
| Chocolatey | 2.7.3 |

---

## Repositório

| Arquivo | Descrição |
|---|---|
| `BRANCHING_STRATEGY.md` | Estratégia de branches (GitFlow + staging paralelo) |
| `AGENTS.md` | Regras para agentes de IA no repositório |
| `readme.md` | Este arquivo |

---

## Observações do Lab

- **Docker Desktop não faz autostart** após instalação via Chocolatey neste ambiente —
  abrir manualmente pelo Menu Iniciar antes de executar `minikube start`.
  Para habilitar: _Docker Desktop → Settings → General → Start Docker Desktop when you sign in_.

- O nó Minikube roda sobre **WSL 2 via Docker Desktop** — kernel `6.6.87.2-microsoft-standard-WSL2`,
  OS interno Debian GNU/Linux 12 (bookworm).
