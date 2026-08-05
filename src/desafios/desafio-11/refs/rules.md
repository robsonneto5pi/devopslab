# refs/rules.md — Padrões Obrigatórios de Implementação

> Lido sob demanda. Consulte ao criar cada tipo de artefato.

---

## YAML / Kubernetes

Labels obrigatórios em **todos** os recursos:
```yaml
labels:
  app: financial-app
  managed-by: kustomize
  project: devops-lab
  challenge: "11"
```

Annotations em **todos os Pod templates** (observabilidade):
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/"
```

Regras adicionais:
- `namespace: financial` em todo recurso
- Tag de imagem: `sha-<commit>` — nunca `latest` em Deployment
- `imagePullPolicy: Always`
- `terminationGracePeriodSeconds: 30`
- `preStop: exec: command: ["/bin/sh", "-c", "sleep 5"]`

---

## Segurança — securityContext obrigatório

```yaml
securityContext:
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  runAsUser: 101        # nginx user
  capabilities:
    drop: [ALL]
    add: [NET_BIND_SERVICE]
```

---

## GitHub Actions

- Jobs em sequência: `ci` → `docker` → `deploy`
- `deploy` somente em `refs/heads/main` com `environment: production`
- Tag da imagem: `sha-${{ github.sha }}` (imutável) + `latest` (alias)
- Gate de saída: `kubectl rollout status --timeout=120s`
- Cache: Docker `type=gha` + npm via `setup-node cache:`

---

## Secrets — regra de ouro

```yaml
# 03-secret.yaml: APENAS placeholders, nunca valores reais
stringData:
  PLACEHOLDER: "CONFIGURE_VIA_kubectl_create_secret"
```
Sempre incluir WARNING no topo do arquivo com instruções de configuração.

---

## Scripts PowerShell

- Modelo: `CHALLENGES/04_KUBERNETES_DEPLOYMENT/scripts/deploy.ps1`
- Iniciar verificando pré-requisitos (`kubectl`, `docker`)
- Saída: `Write-Host` com prefixos `[INFO]`, `[OK]`, `[ERROR]`
- Opção `--dry-run=client` disponível nos scripts de deploy

---

## Documentação

- Idioma: português para títulos/descrições, inglês para código/comandos
- Modelo de estrutura: `CHALLENGES/04_KUBERNETES_DEPLOYMENT/README.md`
- `CHALLENGE.md`: implementável sem consultar a solução
- `SOLUTION.md`: código 100% funcional e copy-pasteable
- `README.md`: incluir diagrama ASCII da arquitetura
