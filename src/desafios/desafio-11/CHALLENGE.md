# Desafio 11: Deploy da Financial App no Kubernetes

## 🎯 Objetivo

Deploy da **Controle Financeiro** (SPA React/Vite → Nginx) em um cluster Kubernetes **compartilhado** com o Desafio 4, usando namespace isolado (`financial`) e um workflow CI/CD completo com GitHub Actions.

---

## 📋 Restrições

1. **Namespace isolado:** `financial` — não usar `app` (já existe no Desafio 4)
2. **Imagem:** vem do GHCR (`ghcr.io/...`), não é local
3. **SPA routing:** Nginx com `try_files $uri /index.html` obrigatório
4. **Secrets:** apenas placeholders no repositório — zero valores reais
5. **Manifests:** seguir padrões de labels, annotations e securityContext conforme `refs/rules.md`
6. **CI/CD:** GitHub Actions com 3 jobs sequenciais (ci → docker → deploy)
7. **Scripts:** PowerShell com pré-requisitos e suporte a `--dry-run`

---

## 📦 Entregáveis

### Kubernetes Manifests (`k8s/`)

Implementar em ordem (ver `refs/checklist.md`):

1. **00-namespace.yaml** — namespace `financial` com labels obrigatórios
2. **01-serviceaccount.yaml** — SA `financial-app-sa` + Role + RoleBinding (leitura de ConfigMap/Secret)
3. **01b-deployer-sa.yaml** — SA `financial-deployer` para CI/CD (Role mínima: get/patch/update Deployment, get/list/watch Pods)
4. **02-configmap.yaml** — ConfigMap com nginx.conf embutido
5. **03-secret.yaml** — Secret com placeholders (WARNING obrigatório)
6. **04-deployment.yaml** — Deployment:
   - 2 réplicas (minAvailable: 1)
   - RollingUpdate: maxSurge=1, maxUnavailable=0
   - Image: `ghcr.io/robsonneto5pi/financial-app:sha-<commit>`
   - Probes: liveness + readiness
   - Resources: requests 50m CPU / 64Mi mem, limits 200m / 128Mi
   - securityContext completo (runAsUser: 101, capabilities)
   - preStop sleep 5s
   - ConfigMap montado em `/etc/nginx/conf.d`

7. **05-service.yaml** — ClusterIP (80 → 8080) + NodePort (30800 para dev)
8. **06-ingress.yaml** — host `financial.local` (classe `nginx`)
9. **07-hpa.yaml** — autoscaling/v2:
   - minReplicas: 2, maxReplicas: 8
   - CPU 60%, Memory 80%

10. **08-pdb.yaml** — minAvailable: 1
11. **09-networkpolicy.yaml** — allow ingress-nginx + egress DNS
12. **kustomization.yaml** — namespace `financial`, labels e namespace mutator

### Nginx Config (`nginx/nginx.conf`)

- `try_files $uri /index.html` para SPA
- Cache 1y para assets estáticos (.js, .css, .png, etc)
- Health check em `/health`

### CI/CD (`.github/workflows/ci-cd.yml`)

3 jobs sequenciais:

1. **ci:** npm ci + npm run build + upload artifact
2. **docker:** (somente main) GHCR login + build + push com tags `sha-<commit>` + `latest`
3. **deploy:** (somente main, environment: production) kubectl set image + rollout status

Secrets necessários:
- `KUBECONFIG` (base64 do SA `financial-deployer`)
- `GITHUB_TOKEN` (automático)

### Scripts PowerShell (`scripts/`)

1. **deploy.ps1** — aplica manifests com kustomize:
   - Verifica kubectl, docker, cluster
   - Cria namespace se não existir
   - Opção `--dry-run` suportada
   - Aguarda rollout

2. **verify.ps1** — verifica saúde:
   - Deployment ready replicas
   - Pods status
   - Services, Ingress, HPA, PDB

3. **cleanup.ps1** — remove namespace:
   - Confirmação (ou `-Force`)
   - Aguarda deleção completa

### Documentação

1. **CHALLENGE.md** (este arquivo) — enunciado implementável sem consultar solução
2. **SOLUTION.md** — código 100% funcional e copy-pasteable
3. **evaluation-criteria.md** — critérios mensuráveis de validação
4. **README.md** — guia de implementação com diagrama ASCII

---

## 🔍 Validação Pré-Deploy

```bash
# Sintaxe YAML
kubectl apply -k k8s/ --dry-run=client

# Namespaces isolados
kubectl get all -n financial
kubectl get all -n app    # confirmar que nada mudou
```

---

## 📚 Referência

Leia nesta ordem:
1. `refs/app-readme.md` — stack e limitações da app
2. `refs/deploy-plan.md` — decisões de arquitetura
3. `refs/rules.md` — padrões obrigatórios
4. `refs/checklist.md` — ordem de criação + validação

**CLAUDE.md:** índice do desafio (só placa de sinalização).

---

## ⚠️ Armadilhas Comuns

| Armadilha | Solução |
|---|---|
| Reutilizar namespace `app` | Usar `financial` em **todos** os resources |
| `imagePullPolicy: Never` | Usar `Always` para GHCR |
| Nginx sem `try_files` | Rotas SPA retornam 404 em reload |
| Tag `latest` no Deployment | Usar `sha-<commit>` — imutável |
| Secrets hardcoded | Apenas placeholders com WARNING |
| KUBECONFIG de admin em GitHub | Usar SA `financial-deployer` com Role mínima |
| Esquecer labels obrigatórios | `app`, `managed-by`, `project`, `challenge` em todo resource |

---

## ✅ Checklist de Entrega

- [ ] Todos os 11 manifests K8s com labels e namespace corretos
- [ ] Nginx config com `try_files` e cache headers
- [ ] CI/CD workflow com 3 jobs sequenciais
- [ ] 3 scripts PowerShell (deploy, verify, cleanup)
- [ ] SOLUTION.md com código copy-pasteable
- [ ] evaluation-criteria.md com critérios mensuráveis
- [ ] README.md com diagrama e quick start
- [ ] `kubectl apply -k k8s/ --dry-run=client` valida sem erros
- [ ] Namespace `app` não foi tocado

---

## 🚀 Próximos Passos (após implementação)

1. Criar secret no cluster: `kubectl create secret generic financial-app-secret -n financial --from-literal=PLACEHOLDER=value`
2. Configurar KUBECONFIG no GitHub: `kubectl create sa financial-deployer -n financial && kubectl get secret -n financial`
3. Push para main → CI/CD dispara automaticamente
4. Verificar: `./verify.ps1`
