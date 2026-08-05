# Deploy Plan — Controle Financeiro no Kubernetes

> Decisões de arquitetura tomadas antes da implementação.
> O Claude Code deve **implementar** estas decisões, não questioná-las.

---

## 1. Contexto e Análise da Aplicação

| Aspecto | Detalhe |
|---|---|
| Tipo | SPA (Single-Page App) — React + TypeScript + Vite |
| Build output | `dist/` — arquivos estáticos HTML/JS/CSS |
| Serve em produção | Nginx (imagem `nginx:alpine`) |
| Porta do container | `8080` |
| Persistência | Nenhuma (dados no `localStorage` do browser) |
| Backend / API | Nenhum — app 100% client-side |
| Segredos | Nenhum necessário em runtime |
| Docker infra path | `infra/docker/Dockerfile.prod` |

**Implicação prática:** por ser uma SPA estática sem backend, não há banco de dados,
filas nem serviços externos para provisionar. A complexidade está na pipeline CI/CD
(build, push da imagem) e nos manifests K8s.

---

## 2. Estratégia de Isolamento no Cluster

A aplicação existente usa o namespace `app`. A financial-app usa namespace separado
para evitar colisões de nome, RBAC cruzado e permitir observabilidade independente.

| | Namespace `app` (Desafio 4) | Namespace `financial` (Desafio 11) |
|---|---|---|
| App | devops-lab Node.js API | Controle Financeiro SPA |
| Porta container | 3000 | 8080 |
| Ingress host | `app.local` | `financial.local` |
| Réplicas mínimas | 3 | 2 |

---

## 3. Estrutura de Arquivos

```
CHALLENGES/11_FINANCIAL_APP_DEPLOY/
├── k8s/
│   ├── 00-namespace.yaml
│   ├── 01-serviceaccount.yaml     ← SA da app (financial-app-sa)
│   ├── 01b-deployer-sa.yaml       ← SA do CI/CD (financial-deployer)
│   ├── 02-configmap.yaml
│   ├── 03-secret.yaml
│   ├── 04-deployment.yaml
│   ├── 05-service.yaml
│   ├── 06-ingress.yaml
│   ├── 07-hpa.yaml
│   ├── 08-pdb.yaml
│   ├── 09-networkpolicy.yaml
│   └── kustomization.yaml
├── .github/workflows/ci-cd.yml
├── nginx/nginx.conf
└── scripts/ (deploy.ps1, verify.ps1, cleanup.ps1)
```

---

## 4. Manifests Kubernetes — Decisões Detalhadas

### Namespace (00-namespace.yaml)

```yaml
metadata:
  name: financial
  labels:
    name: financial
    environment: production
    app.kubernetes.io/part-of: financial-app
```

### Deployment (04-deployment.yaml) — pontos-chave

```yaml
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0              # zero-downtime obrigatório

  template:
    spec:
      containers:
      - name: financial-app
        image: ghcr.io/<owner>/financial-app:<sha>
        imagePullPolicy: Always      # NUNCA Never — imagem vem do GHCR
        ports:
        - containerPort: 8080

        resources:
          requests:
            cpu: 50m
            memory: 64Mi             # SPA estática é muito leve
          limits:
            cpu: 200m
            memory: 128Mi

        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10

        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 3
          periodSeconds: 5

        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 101             # nginx user
          capabilities:
            drop: [ALL]
            add: [NET_BIND_SERVICE]
```

### Ingress (06-ingress.yaml)

```yaml
spec:
  ingressClassName: nginx
  rules:
  - host: financial.local            # separado de app.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: financial-service
            port:
              number: 80
```

### HPA (07-hpa.yaml)

- `minReplicas: 2`
- `maxReplicas: 8`
- CPU target: `60%` (mais conservador que os 70% do Desafio 4)
- Memory target: `80%`

### PDB (08-pdb.yaml)

- `minAvailable: 1` (uma réplica sempre disponível durante manutenção)

---

## 5. Pipeline CI/CD — GitHub Actions

Estrutura dos 3 jobs:

```
on: push to main / pull_request to main

jobs:
  ci:          → npm ci + npm run build + upload artifact
  docker:      → login GHCR + build + push (somente main)
  deploy:      → kubectl set image + rollout status (somente main)
```

### Secrets necessários no GitHub

| Secret | Valor | Como obter |
|---|---|---|
| `KUBECONFIG` | kubeconfig em base64 do SA `financial-deployer` | ver seção 7 |
| `GITHUB_TOKEN` | automático | nenhuma configuração |

### Tags de imagem

- `ghcr.io/<owner>/financial-app:sha-<commit-sha>` — tag imutável
- `ghcr.io/<owner>/financial-app:latest` — alias, nunca usar em Deployment

---

## 6. Nginx Config — try_files para SPA

```nginx
server {
    listen 8080;
    root /usr/share/nginx/html;
    index index.html;

    # SPA routing — OBRIGATÓRIO
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache para assets estáticos
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Health check para Kubernetes probes
    location /health {
        return 200 'ok';
        add_header Content-Type text/plain;
    }
}
```

---

## 7. Service Account Restrito para CI/CD

```yaml
# Role mínima — apenas o necessário para o deploy
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "patch", "update"]   # set image + rollout
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]     # rollout status
```

---

## 8. Armadilhas Identificadas

| Armadilha | Solução |
|---|---|
| `imagePullPolicy: Never` para imagem do GHCR | Usar `Always` + `imagePullSecrets` se repo privado |
| Nginx sem `try_files` | Rotas SPA retornam 404 em reload |
| Reutilizar namespace `app` | Namespace `financial` obrigatório |
| Tag `latest` no Deployment | Usar `sha-<commit>` — imutável e rastreável |
| KUBECONFIG de admin no CI | Usar SA `financial-deployer` com Role mínima |
| Secrets hardcoded no YAML | Apenas placeholders + instruções de configuração |

---

## 9. Comparativo com Desafio 4

| Característica | Desafio 4 (`app`) | Desafio 11 (`financial`) |
|---|---|---|
| Namespace | `app` | `financial` |
| App | Node.js API | SPA estática (Nginx) |
| Porta container | 3000 | 8080 |
| Imagem | Local Minikube | GHCR (registry externo) |
| Réplicas mínimas | 3 | 2 |
| CPU request | 100m | 50m |
| Mem request | 128Mi | 64Mi |
| Ingress host | `app.local` | `financial.local` |
| Secrets runtime | JWT, DB, Redis | Nenhum |
| CI/CD | Scripts manuais | GitHub Actions completo |
| HPA CPU target | 70% | 60% |

---

## 10. Diagrama de Arquitetura

```
Cluster Kubernetes (Minikube / Produção)
│
├── namespace: app          ← DESAFIO 4 — NÃO TOCAR
│   ├── app-deployment      (Node.js API, porta 3000)
│   └── app-service → Ingress: app.local
│
└── namespace: financial    ← DESAFIO 11 — IMPLEMENTAR AQUI
    ├── financial-deployment (Nginx SPA, porta 8080)
    ├── financial-service    (ClusterIP 80 → 8080)
    ├── financial-hpa        (min:2 / max:8 / CPU 60%)
    ├── financial-pdb        (minAvailable: 1)
    └── financial-ingress  → host: financial.local
```

---

## 11. Estrutura de Arquivos Esperada ao Final

```
CHALLENGES/11_FINANCIAL_APP_DEPLOY/
├── CLAUDE.md                    ← índice (placa de sinalização)
├── CHALLENGE.md
├── SOLUTION.md
├── evaluation-criteria.md
├── README.md
├── refs/
│   ├── app-readme.md            ← README da aplicação externa
│   ├── deploy-plan.md           ← este arquivo
│   ├── rules.md                 ← padrões obrigatórios
│   └── checklist.md             ← ordem de criação + validação
├── nginx/
│   └── nginx.conf               ← try_files para SPA routing
├── k8s/
│   ├── 00-namespace.yaml
│   ├── 01-serviceaccount.yaml
│   ├── 01b-deployer-sa.yaml     ← SA restrito para CI/CD
│   ├── 02-configmap.yaml
│   ├── 03-secret.yaml
│   ├── 04-deployment.yaml
│   ├── 05-service.yaml
│   ├── 06-ingress.yaml
│   ├── 07-hpa.yaml
│   ├── 08-pdb.yaml
│   ├── 09-networkpolicy.yaml
│   └── kustomization.yaml
├── .github/
│   └── workflows/
│       └── ci-cd.yml
└── scripts/
    ├── deploy.ps1
    ├── verify.ps1
    └── cleanup.ps1
```
