# refs/checklist.md — Ordem de Implementação e Validação

> Implemente **nesta ordem exata**. Valide cada item antes de avançar.

---

## Checklist de criação

- [ ] `nginx/nginx.conf` — config Nginx com `try_files` para SPA routing
- [ ] `k8s/00-namespace.yaml` — namespace `financial`
- [ ] `k8s/01-serviceaccount.yaml` — SA `financial-app-sa` + Role + RoleBinding
- [ ] `k8s/01b-deployer-sa.yaml` — SA `financial-deployer` para CI/CD (Role mínima)
- [ ] `k8s/02-configmap.yaml` — ConfigMap com nginx.conf embutido
- [ ] `k8s/03-secret.yaml` — Secret com WARNING e placeholders
- [ ] `k8s/04-deployment.yaml` — Deployment completo com probes, resources, securityContext
- [ ] `k8s/05-service.yaml` — ClusterIP (80 → 8080) + NodePort para dev
- [ ] `k8s/06-ingress.yaml` — Ingress host `financial.local`
- [ ] `k8s/07-hpa.yaml` — HPA autoscaling/v2, CPU 60%, min:2 max:8
- [ ] `k8s/08-pdb.yaml` — PodDisruptionBudget `minAvailable: 1`
- [ ] `k8s/09-networkpolicy.yaml` — ingress-nginx + egress DNS
- [ ] `k8s/kustomization.yaml` — namespace `financial`, label `challenge: "11"`
- [ ] `.github/workflows/ci-cd.yml` — pipeline ci → docker → deploy
- [ ] `scripts/deploy.ps1` — deploy local com pré-requisitos e dry-run
- [ ] `scripts/verify.ps1` — verificação pós-deploy
- [ ] `scripts/cleanup.ps1` — limpeza do namespace
- [ ] `CHALLENGE.md` — enunciado do desafio
- [ ] `SOLUTION.md` — solução de referência
- [ ] `evaluation-criteria.md` — critérios mensuráveis
- [ ] `README.md` — guia de implementação com quick start

---

## Validação por manifest

Antes de criar cada recurso K8s, confirme mentalmente:

1. `namespace: financial` presente? ✓
2. Labels obrigatórios (`app`, `managed-by`, `project`, `challenge`)? ✓
3. Nome com prefixo `financial-`? Sem conflito com namespace `app`? ✓
4. Secrets têm apenas placeholders? ✓
5. `securityContext` completo no container? ✓

---

## Validação final — dry-run obrigatório

```bash
# Validar todos os manifests sem aplicar
kubectl apply -k k8s/ --dry-run=client

# Verificar namespace isolado
kubectl get all -n financial
kubectl get all -n app   # confirmar que nada mudou aqui
```
