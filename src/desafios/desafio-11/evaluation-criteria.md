# Evaluation Criteria — Desafio 11: Financial App Deploy

> Critérios mensuráveis para validar a implementação.

---

## Categoria 1: Kubernetes Manifests

### 1.1 Namespace Isolado

**Critério:** Namespace `financial` existe e é isolado do Desafio 4.

**Validação:**
```bash
kubectl get namespace financial
kubectl get all -n financial      # Só recursos da financial-app
kubectl get all -n app            # Não há cruzamento de recursos
```

**Resultado esperado:** ✓ Namespace existe, labels presentes, app/financial isoladas.

---

### 1.2 Labels Obrigatórios em Todos os Resources

**Critério:** Todo resource tem os 4 labels:
- `app: financial-app`
- `managed-by: kustomize`
- `project: devops-lab`
- `challenge: "11"`

**Validação:**
```bash
kubectl get all -n financial -o json | \
  jq '.items[] | .metadata.labels'
```

**Resultado esperado:** ✓ Todos os resources mostram os 4 labels.

---

### 1.3 Service Accounts com RBAC Restrito

**Critério:** Existem 2 SAs:
- `financial-app-sa`: lê ConfigMap e Secret
- `financial-deployer`: get/patch/update Deployment, get/list/watch Pods (mínimo necessário para CI/CD)

**Validação:**
```bash
kubectl get sa -n financial
kubectl describe role financial-app-role -n financial
kubectl describe role financial-deployer-role -n financial
```

**Resultado esperado:** ✓ Ambas as SAs e Roles presentes com permissões corretas.

---

### 1.4 ConfigMap com Nginx Config

**Critério:** ConfigMap `financial-nginx-config` contém nginx.conf com `try_files`.

**Validação:**
```bash
kubectl get cm financial-nginx-config -n financial -o jsonpath='{.data.nginx\.conf}'
```

**Resultado esperado:** ✓ nginx.conf contém `try_files $uri /index.html`.

---

### 1.5 Secret com Placeholders

**Critério:** Secret `financial-app-secret` tem apenas placeholders, nenhum valor real.

**Validação:**
```bash
kubectl get secret financial-app-secret -n financial -o jsonpath='{.data}'
```

**Resultado esperado:** ✓ Secret tem `PLACEHOLDER: CONFIGURE_VIA_kubectl_create_secret` (base64).

---

### 1.6 Deployment com Configuração Correta

**Critério:** Deployment `financial-deployment`:
- 2 réplicas
- Image: `ghcr.io/robsonneto5pi/financial-app:sha-*` (nunca `latest`)
- imagePullPolicy: `Always`
- Resources: requests 50m/64Mi, limits 200m/128Mi
- Probes: liveness + readiness
- securityContext: runAsNonRoot, runAsUser: 101, capabilities drop [ALL]
- preStop sleep 5s

**Validação:**
```bash
kubectl get deployment financial-deployment -n financial -o yaml
kubectl describe deployment financial-deployment -n financial
```

**Resultado esperado:** ✓ Deployment tem todos os atributos listados.

---

### 1.7 Services ClusterIP + NodePort

**Critério:** Existem 2 services:
- `financial-service`: ClusterIP 80 → 8080
- `financial-service-nodeport`: NodePort 30800 → 8080

**Validação:**
```bash
kubectl get svc -n financial
kubectl get svc financial-service -n financial -o yaml
```

**Resultado esperado:** ✓ Ambos os services presentes e com portas corretas.

---

### 1.8 Ingress com Host `financial.local`

**Critério:** Ingress `financial-ingress` aponta para `financial.local`.

**Validação:**
```bash
kubectl get ingress -n financial
kubectl describe ingress financial-ingress -n financial
```

**Resultado esperado:** ✓ Ingress com host `financial.local`, ingressClassName `nginx`.

---

### 1.9 HPA com Configuração Correta

**Critério:** HPA `financial-hpa`:
- minReplicas: 2, maxReplicas: 8
- CPU target: 60%
- Memory target: 80%

**Validação:**
```bash
kubectl get hpa -n financial
kubectl describe hpa financial-hpa -n financial
```

**Resultado esperado:** ✓ HPA presente com targets corretos.

---

### 1.10 PDB com minAvailable: 1

**Critério:** PodDisruptionBudget `financial-pdb` garante minAvailable 1.

**Validação:**
```bash
kubectl get pdb -n financial
kubectl describe pdb financial-pdb -n financial
```

**Resultado esperado:** ✓ PDB presente com minAvailable: 1.

---

### 1.11 NetworkPolicy com Isolamento Correto

**Critério:** NetworkPolicy permite:
- Ingress: `ingress-nginx` namespace
- Egress: DNS (UDP 53)

**Validação:**
```bash
kubectl get networkpolicy -n financial
kubectl describe networkpolicy financial-network-policy -n financial
```

**Resultado esperado:** ✓ NetworkPolicy presente com rules corretos.

---

### 1.12 Kustomization com Namespace e Labels Corretos

**Critério:** `kustomization.yaml` define namespace `financial` e commonLabels.

**Validação:**
```bash
kubectl kustomize k8s/ | grep -E "namespace|labels"
```

**Resultado esperado:** ✓ Kustomization apply adiciona namespace a todos os resources.

---

## Categoria 2: Nginx Config

### 2.1 SPA Routing com try_files

**Critério:** nginx.conf contém `try_files $uri /index.html`.

**Validação:**
```bash
kubectl get cm financial-nginx-config -n financial -o jsonpath='{.data.nginx\.conf}' | grep "try_files"
```

**Resultado esperado:** ✓ `try_files $uri /index.html` presente.

---

### 2.2 Cache Headers para Assets

**Critério:** Nginx adiciona `Cache-Control: public, immutable` e `expires 1y` para assets.

**Validação:**
```bash
kubectl get cm financial-nginx-config -n financial -o jsonpath='{.data.nginx\.conf}' | grep -A2 "\.js\|\.css"
```

**Resultado esperado:** ✓ Cache headers presentes para .js, .css, .png, etc.

---

### 2.3 Health Check Endpoint

**Critério:** Nginx serve `/health` que retorna 200.

**Validação:**
```bash
kubectl exec -it <pod-name> -n financial -- curl localhost:8080/health
```

**Resultado esperado:** ✓ `ok` retornado com 200.

---

## Categoria 3: CI/CD Workflow

### 3.1 Jobs em Sequência

**Critério:** `.github/workflows/ci-cd.yml` define 3 jobs: `ci` → `docker` → `deploy`.

**Validação:**
```bash
cat .github/workflows/ci-cd.yml | grep -E "^  [a-z]+:" | head -5
```

**Resultado esperado:** ✓ Jobs: ci, docker, deploy em ordem.

---

### 3.2 CI Job

**Critério:** `ci` job faz npm ci, npm run build, upload artifact.

**Validação:**
```bash
grep -A 10 "jobs:" .github/workflows/ci-cd.yml | grep -E "npm ci|npm run build|upload-artifact"
```

**Resultado esperado:** ✓ Todos os steps presentes.

---

### 3.3 Docker Job (somente main)

**Critério:** `docker` job:
- Somente em `if: github.ref == 'refs/heads/main'`
- Build + push GHCR
- Tags: `sha-<commit>` + `latest`

**Validação:**
```bash
grep -B 5 "docker/build-push-action" .github/workflows/ci-cd.yml | grep -E "if:|main"
```

**Resultado esperado:** ✓ Job condicional para main, tags sha- e latest.

---

### 3.4 Deploy Job (somente main, environment: production)

**Critério:** `deploy` job:
- Somente em `if: github.ref == 'refs/heads/main'`
- `environment: production`
- `kubectl set image` + `rollout status --timeout=120s`

**Validação:**
```bash
grep -A 20 "jobs:" .github/workflows/ci-cd.yml | grep -E "deploy:|environment:|kubectl set image|rollout status"
```

**Resultado esperado:** ✓ Deploy job condicional com environment e kubectl commands.

---

### 3.5 Cache Configurado

**Critério:** CI faz cache de dependências npm. Docker faz cache GHA.

**Validação:**
```bash
grep -E "cache: npm|type: gha" .github/workflows/ci-cd.yml
```

**Resultado esperado:** ✓ Cache npm e GHA presentes.

---

## Categoria 4: Scripts PowerShell

### 4.1 deploy.ps1 — Pré-requisitos

**Critério:** Script valida kubectl, docker, cluster antes de deploy.

**Validação:**
```bash
.\scripts\deploy.ps1 -DryRun
# Saída deve mostrar [INFO] kubectl, [INFO] docker, [INFO] cluster
```

**Resultado esperado:** ✓ Todos os pré-requisitos validados, `--dry-run` executa sem erro.

---

### 4.2 deploy.ps1 — Suporte a --dry-run

**Critério:** Flag `--dry-run` executa com `kubectl apply --dry-run=client`.

**Validação:**
```bash
.\scripts\deploy.ps1 -DryRun 2>&1 | grep "DRY-RUN"
```

**Resultado esperado:** ✓ Output menciona DRY-RUN, nenhuma aplicação real.

---

### 4.3 deploy.ps1 — Rollout Status

**Critério:** Script aguarda `kubectl rollout status --timeout=120s`.

**Validação:**
```bash
.\scripts\deploy.ps1 2>&1 | grep "rollout status"
```

**Resultado esperado:** ✓ Script aguarda rollout (ou falha se timeout).

---

### 4.4 verify.ps1 — Checks Completos

**Critério:** Script valida:
- Namespace exists
- Deployment ready replicas
- Pods status
- Services, Ingress, HPA, PDB

**Validação:**
```bash
.\scripts\verify.ps1 2>&1 | grep -E "Checking|Pod|Deployment|Service"
```

**Resultado esperado:** ✓ Todos os checks exibidos com status.

---

### 4.5 cleanup.ps1 — Confirmação e Deleção

**Critério:** Script pede confirmação antes de deletar namespace (exceto `-Force`).

**Validação:**
```bash
echo "no" | .\scripts\cleanup.ps1 2>&1 | grep "cancelled"
.\scripts\cleanup.ps1 -Force 2>&1 | grep "Namespace deleted"
```

**Resultado esperado:** ✓ Confirmação respeitada, `-Force` força deleção.

---

## Categoria 5: Documentação

### 5.1 CHALLENGE.md — Implementável sem Solução

**Critério:** CHALLENGE.md descreve:
- Objetivo, restrições, armadilhas
- Entregáveis (manifests, nginx, CI/CD, scripts)
- Validação pré-deploy
- Checklist de entrega

**Validação:**
```bash
cat CHALLENGE.md | grep -E "^##|Namespace|imagePullPolicy|try_files"
```

**Resultado esperado:** ✓ Enunciado claro e copiável sem consultar SOLUTION.md.

---

### 5.2 SOLUTION.md — Código Copy-Pasteable

**Critério:** SOLUTION.md contém 100% do código YAML, scripts, workflow.

**Validação:**
```bash
grep -c "^apiVersion:" SOLUTION.md  # deve ser > 10
grep -c "^#!/usr/bin/env pwsh" SOLUTION.md  # deve ser >= 3
```

**Resultado esperado:** ✓ Múltiplos manifestos e scripts inline.

---

### 5.3 evaluation-criteria.md — Critérios Mensuráveis

**Critério:** Este arquivo (evaluation-criteria.md) lista critérios para cada categoria.

**Validação:**
```bash
cat evaluation-criteria.md | grep -E "^###|Validação|Resultado esperado" | wc -l
```

**Resultado esperado:** ✓ 20+ critérios definidos com validações.

---

### 5.4 README.md — Guia com Diagrama

**Critério:** README.md contém:
- Quick start (como deploy)
- Diagrama ASCII da arquitetura
- Troubleshooting
- Links para refs

**Validação:**
```bash
cat README.md | grep -E "^#|Cluster|namespace|Quick Start"
```

**Resultado esperado:** ✓ Guia navegável com diagrama e instruções.

---

## Categoria 6: Validação Final

### 6.1 Sintaxe YAML Válida

**Critério:** `kubectl apply -k k8s/ --dry-run=client` não retorna erro.

**Validação:**
```bash
kubectl apply -k k8s/ --dry-run=client 2>&1 | grep -i error
```

**Resultado esperado:** ✓ Sem erros (exit code 0).

---

### 6.2 Namespace `app` Não Tocado

**Critério:** Nenhum arquivo modificou `app` namespace ou seus resources.

**Validação:**
```bash
git diff HEAD -- "k8s/*" | grep "namespace: app"
```

**Resultado esperado:** ✓ Sem modificações em namespace `app`.

---

### 6.3 Nenhum Secret Real no Repositório

**Critério:** Nenhum arquivo contém valores reais (senhas, tokens, etc).

**Validação:**
```bash
grep -r "token\|password\|secret" . --include="*.yaml" --include="*.yml" | grep -v "PLACEHOLDER\|CONFIGURE"
```

**Resultado esperado:** ✓ Sem valores reais (apenas placeholders).

---

## Sumário de Checklist

| Categoria | Critérios | Validação |
|---|---|---|
| K8s Manifests | 12 | Labels, RBAC, ConfigMap, Secret, Deployment, Services, Ingress, HPA, PDB, NetworkPolicy |
| Nginx Config | 3 | try_files, cache, health check |
| CI/CD Workflow | 5 | Jobs sequência, CI, Docker, Deploy, Cache |
| Scripts PS1 | 5 | Pré-requisitos, dry-run, rollout, verify, cleanup |
| Documentação | 4 | CHALLENGE, SOLUTION, evaluation-criteria, README |
| Validação Final | 3 | Sintaxe YAML, namespace `app` intacto, sem secrets reais |
| **Total** | **32 critérios** | Todos devem passar ✓ |

---

## Passando na Avaliação

1. ✓ Executar `./scripts/deploy.ps1 -DryRun` sem erros
2. ✓ Executar `./scripts/verify.ps1` e ver todos os componentes saudáveis
3. ✓ Verificar `kubectl get all -n financial` mostra todos os resources
4. ✓ Verificar `kubectl get all -n app` não foi alterado
5. ✓ Revisar `SOLUTION.md` é copy-pasteable e completo
6. ✓ Revisar `CHALLENGE.md` é implementável sem consultar solução
7. ✓ Revisar `README.md` tem guia e diagrama

**Resultado final:** Deploy funcional, documentação completa, sem segredos no repo. ✅
