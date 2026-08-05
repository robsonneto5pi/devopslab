# Desafio 11: Financial App Deploy no Kubernetes

> Deploy da **Controle Financeiro** (SPA React/Vite → Nginx) em cluster Kubernetes compartilhado com namespace isolado.

---

## 🎯 Objetivo

Provisionar a financial-app (SPA estática) no mesmo cluster do Desafio 4 usando:
- **Namespace isolado:** `financial` (sem tocar em `app`)
- **Registry externo:** GHCR (`ghcr.io/robsonneto5pi/financial-app`)
- **SPA routing:** Nginx com `try_files` para React Router
- **CI/CD automático:** GitHub Actions (npm build → Docker push → kubectl deploy)
- **Escalabilidade:** HPA 2-8 réplicas, PDB minAvailable 1

---

## 📋 Quick Start

### Local (Minikube/Docker Desktop)

```bash
# 1. Validar manifests (dry-run)
.\scripts\deploy.ps1 -DryRun

# 2. Deploy real
.\scripts\deploy.ps1

# 3. Verificar saúde
.\scripts\verify.ps1

# 4. Acessar
# Via NodePort: http://localhost:30800
# Via Ingress: http://financial.local (requer /etc/hosts entry)

# 5. Ver logs
kubectl logs -f -n financial -l app=financial-app
```

### GitHub Actions (Main Branch)

```
Push to main
  ↓ [CI] npm ci + npm run build
  ↓ [Docker] Build + Push GHCR (tag: sha-<commit>)
  ↓ [Deploy] kubectl set image + rollout status
  ↓ Done
```

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                 Kubernetes Cluster (Minikube)               │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────────────┐   ┌─────────────────────────┐  │
│  │  Namespace: app         │   │ Namespace: financial    │  │
│  │ (Desafio 4 — NOT HERE)  │   │  (Desafio 11 — YOU)    │  │
│  │                         │   │                         │  │
│  │ ┌─ app-deployment       │   │ ┌─ financial-deploy    │  │
│  │ │  Node.js API          │   │ │  Nginx SPA            │  │
│  │ │  Port: 3000           │   │ │  Port: 8080           │  │
│  │ │  Replicas: 3          │   │ │  Replicas: 2-8 (HPA)  │  │
│  │ │                       │   │ │                       │  │
│  │ └─ service:80→3000      │   │ └─ service:80→8080      │  │
│  │    (ClusterIP)          │   │    (ClusterIP)          │  │
│  │                         │   │ ┌─ service-nodeport     │  │
│  └─────────────────────────┘   │ │  NodePort: 30800      │  │
│         │                       │ └────────────────────   │  │
│         │                       │ ┌─ HPA (60% CPU)        │  │
│         │                       │ └─ PDB (minAvail: 1)    │  │
│         │                       │ ┌─ NetworkPolicy        │  │
│         │                       │ └─ ConfigMap (nginx)    │  │
│         │                       └─────────────────────────┘  │
│         │                                                     │
│  ┌──────┴──────────────────────────────────────────────────┐ │
│  │         Ingress (ingress-nginx)                        │ │
│  │  ┌─ app.local → app-service:80                        │ │
│  │  └─ financial.local → financial-service:80            │ │
│  └───────────────────────────────────────────────────────┘ │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 📂 Estrutura de Arquivos

```
src/desafios/desafio-11/
├── README.md                        ← este arquivo
├── CHALLENGE.md                     ← enunciado implementável
├── SOLUTION.md                      ← referência copy-pasteable
├── evaluation-criteria.md           ← critérios mensuráveis
├── CLAUDE.md                        ← índice do desafio
│
├── refs/
│   ├── app-readme.md                ← stack: React, Vite, Nginx, porta 8080
│   ├── deploy-plan.md               ← decisões de arquitetura
│   ├── rules.md                     ← padrões obrigatórios (labels, RBAC, etc)
│   └── checklist.md                 ← ordem de criação + validação
│
├── nginx/
│   └── nginx.conf                   ← config com try_files para SPA routing
│
├── k8s/
│   ├── 00-namespace.yaml            ← namespace financial
│   ├── 01-serviceaccount.yaml       ← SA financial-app-sa + Role
│   ├── 01b-deployer-sa.yaml         ← SA financial-deployer para CI/CD
│   ├── 02-configmap.yaml            ← nginx config como ConfigMap
│   ├── 03-secret.yaml               ← Secret com placeholders (WARNING)
│   ├── 04-deployment.yaml           ← Deployment (2 replicas, probes, resources)
│   ├── 05-service.yaml              ← ClusterIP + NodePort
│   ├── 06-ingress.yaml              ← host financial.local
│   ├── 07-hpa.yaml                  ← autoscaling 2-8 replicas, 60% CPU
│   ├── 08-pdb.yaml                  ← PodDisruptionBudget minAvailable: 1
│   ├── 09-networkpolicy.yaml        ← isolamento de rede
│   └── kustomization.yaml           ← manifests index
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml                ← GitHub Actions: ci → docker → deploy
│
└── scripts/
    ├── deploy.ps1                   ← deploy com validação e dry-run
    ├── verify.ps1                   ← health checks pós-deploy
    └── cleanup.ps1                  ← remove namespace (com confirmação)
```

---

## 🔧 Pré-requisitos

- **kubectl** com acesso ao cluster (local ou produção)
- **docker** ou **containerd** para validar imagens
- **PowerShell Core 7+** (ou Windows PowerShell 5.1)
- **Cluster:** Kubernetes 1.24+ com nginx-ingress controller

**Verificar:**
```bash
kubectl version --client
docker version
pwsh --version
kubectl get nodes
```

---

## 📦 Deploy Local (Step-by-Step)

### 1. Validar Manifests (Dry-Run)

```bash
cd src/desafios/desafio-11

# Validação sem aplicar
.\scripts\deploy.ps1 -DryRun
```

**Esperado:** Output mostrando kubectl, docker, cluster OK e manifests válidos.

### 2. Deploy Real

```bash
.\scripts\deploy.ps1
```

**Esperado:**
- Namespace `financial` criado
- Todos os resources aplicados
- Rollout status aguardando replicas prontas

### 3. Verificar Saúde

```bash
.\scripts\verify.ps1
```

**Esperado:**
```
[OK] Deployment 'financial-deployment': 2/2 ready
[OK] Pod 'financial-deployment-xxx': Running
[OK] Service 'financial-service': ClusterIP=10.0.0.X
[OK] Ingress 'financial-ingress': hosts=financial.local
[OK] HPA 'financial-hpa': current=2, desired=2
[OK] PDB 'financial-pdb': minAvailable=1
```

### 4. Acessar a Aplicação

**Via NodePort:**
```bash
kubectl port-forward -n financial svc/financial-service 8080:80
# Acesse http://localhost:8080
```

**Via Ingress (requer /etc/hosts entry):**
```
# Adicione ao /etc/hosts (Windows) ou ~/.hosts (Linux/Mac):
127.0.0.1 financial.local

# Acesse http://financial.local
```

### 5. Limpar

```bash
.\scripts\cleanup.ps1

# Ou forçar sem confirmação:
.\scripts\cleanup.ps1 -Force
```

---

## 🔄 CI/CD Workflow (GitHub Actions)

### Trigger

- Qualquer push para `main`
- Qualquer PR para `main`
- Filtro: mudanças em `src/desafios/desafio-11/**`

### Jobs

| Job | Trigger | Descrição |
|---|---|---|
| **ci** | Sempre | npm ci + npm run build + upload dist/ |
| **docker** | main somente | Build Docker + push GHCR (tag: sha-<commit>) |
| **deploy** | main somente | kubectl set image + rollout status |

### Secrets Necessários

Configure no GitHub > Settings > Secrets > Actions:

1. **KUBECONFIG** — base64 do kubeconfig da SA `financial-deployer`

   ```bash
   kubectl get secret -n financial -o yaml \
     $(kubectl get secret -n financial -o name | grep financial-deployer) | \
     kubectl extract -f - --to=- | base64 -w0
   ```

2. **GITHUB_TOKEN** — automático (não precisa configurar)

### Verificar Pipeline

```bash
# Log do último run
gh run list --limit 1 --repo <owner/repo>

# Detalhes
gh run view <run-id> -w
```

---

## 🐛 Troubleshooting

### Pods não ficam Ready

```bash
# Ver logs
kubectl logs -n financial -l app=financial-app --tail=50

# Descrever pod
kubectl describe pod -n financial -l app=financial-app

# Probes failing?
kubectl get events -n financial --sort-by='.lastTimestamp'
```

### Deployment bloqueado no status pendente

```bash
# Ver replicas desejadas vs prontas
kubectl get deployment -n financial

# Verificar recursos disponíveis no cluster
kubectl describe nodes

# Ver eventos
kubectl describe deployment financial-deployment -n financial
```

### Ingress não resolve

```bash
# Adicione ao /etc/hosts:
# 127.0.0.1 financial.local

# Teste DNS
curl -H "Host: financial.local" http://localhost

# Ver Ingress status
kubectl describe ingress -n financial
```

### Imagem não puxa (GHCR)

```bash
# Verificar pull policy
kubectl get deployment -n financial -o jsonpath='{.items[0].spec.template.spec.containers[0].imagePullPolicy}'

# Deve ser: Always

# Se repo privado, adicionar imagePullSecrets:
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<token> \
  -n financial
```

### Secret vazio

```bash
# Criar secret via kubectl (não do YAML):
kubectl create secret generic financial-app-secret \
  -n financial \
  --from-literal=PLACEHOLDER=value \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

## 📊 Monitoramento

### Métricas HPA

```bash
kubectl get hpa -n financial -w

# Ver metricas atuais
kubectl top deployment -n financial
kubectl top pods -n financial
```

### Logs em Tempo Real

```bash
kubectl logs -f -n financial -l app=financial-app
```

### Eventos do Cluster

```bash
kubectl get events -n financial --sort-by='.lastTimestamp' -w
```

---

## 📚 Referência

Leia em ordem:

1. **refs/app-readme.md** — Stack, porta, Dockerfile, estrutura
2. **refs/deploy-plan.md** — Decisões de arquitetura, namespace, registry
3. **refs/rules.md** — Labels obrigatórios, securityContext, CI/CD patterns
4. **refs/checklist.md** — Ordem de criação, validação por manifest
5. **CHALLENGE.md** — Enunciado detalhado (implementável sem SOLUTION.md)
6. **SOLUTION.md** — Código 100% pronto (copy-paste)
7. **evaluation-criteria.md** — 32 critérios mensuráveis

---

## ✅ Checklist de Validação Final

- [ ] `.\scripts\deploy.ps1 -DryRun` sem erros
- [ ] `.\scripts\verify.ps1` mostra todos os componentes OK
- [ ] `kubectl get all -n financial` lista 15+ resources
- [ ] `kubectl get all -n app` não foi alterado
- [ ] `kubectl apply -k k8s/ --dry-run=client` valida sem erros
- [ ] Nenhum secret real no repositório (apenas placeholders)
- [ ] SOLUTION.md é copy-pasteable (contém 100% do código)
- [ ] CHALLENGE.md é implementável sem consultar SOLUTION.md
- [ ] README.md tem diagrama e quick start
- [ ] evaluation-criteria.md lista 32 critérios mensuráveis

---

## 🤝 Suporte

**Dúvidas?** Consulte:
- CHALLENGE.md para enunciado
- SOLUTION.md para código de referência
- evaluation-criteria.md para critérios mensuráveis
- refs/ para decisões de arquitetura

**Bugs no deploy?** Veja Troubleshooting acima.

---

## 📝 Notas

- **Namespace:** Sempre `financial`, nunca `app`
- **Imagem:** Vem de `ghcr.io/...`, requer `imagePullPolicy: Always`
- **SPA routing:** Nginx `try_files` é crítico para rotas React funcionar
- **Secrets:** Configure via kubectl, nunca commit valores reais
- **KUBECONFIG:** Use SA `financial-deployer` (Role mínima) no GitHub

---

**Boa sorte! 🚀**
