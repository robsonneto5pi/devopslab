# SOLUTION.md — Financial App Deploy no Kubernetes

> Solução de referência 100% funcional. Todo código é copy-pasteable.
> Sincronizado com os manifests reais após correção dos bugs identificados na auditoria.

---

## 📂 Estrutura de Arquivos

```
src/desafios/desafio-11/
├── SOLUTION.md              (este arquivo)
├── nginx/
│   └── nginx.conf           (config copiada para o ConfigMap 02)
├── k8s/
│   ├── 00-namespace.yaml
│   ├── 01-serviceaccount.yaml
│   ├── 01b-deployer-sa.yaml
│   ├── 02-configmap.yaml    (nginx.conf + proxy /api/)
│   ├── 03-secret.yaml       (placeholders — configure via kubectl)
│   ├── backend-configmap.yaml   ← NOVO
│   ├── backend-deployment.yaml  ← NOVO
│   ├── backend-service.yaml     ← NOVO
│   ├── 04-deployment.yaml   (frontend — porta 80, GHCR, sem runAsNonRoot)
│   ├── 05-service.yaml      (ClusterIP + NodePort 30800)
│   ├── 06-ingress.yaml      (financial.local, /api → backend antes de /)
│   ├── 07-hpa.yaml
│   ├── 08-pdb.yaml
│   ├── 09-networkpolicy.yaml (label corrigido: app.kubernetes.io/name)
│   └── kustomization.yaml   (labels moderno, includeSelectors: false)
├── .github/
│   └── workflows/
│       └── ci-cd.yml
└── scripts/
    ├── deploy.ps1
    ├── verify.ps1
    └── cleanup.ps1
```

---

## 🐛 Bugs Corrigidos vs. Versão Original

| # | Arquivo | Bug Original | Correção |
|---|---------|-------------|----------|
| 1 | `04-deployment.yaml` | Imagem `node-app:latest` (local) | `ghcr.io/vibecodia/vibecodia-finances-frontend:latest` |
| 2 | `04-deployment.yaml` | `containerPort: 8080` | `containerPort: 80` (Dockerfile usa nginx:alpine) |
| 3 | `04-deployment.yaml` | `runAsNonRoot: true` | Removido — nginx precisa de root para `/var/cache/nginx` |
| 4 | `04-deployment.yaml` | `imagePullPolicy: Never` | `imagePullPolicy: Always` + `imagePullSecrets: ghcr-secret` |
| 5 | `05-service.yaml` | `targetPort: 8080` | `targetPort: 80` |
| 6 | `06-ingress.yaml` | `/api` depois de `/` | `/api` antes de `/` (match mais específico primeiro) |
| 7 | `09-networkpolicy.yaml` | `name: ingress-nginx` | `app.kubernetes.io/name: ingress-nginx` (label real do cluster) |
| 8 | `kustomization.yaml` | `commonLabels:` (deprecated) | `labels:` com `includeSelectors: false` |
| 9 | Inexistente | Backend sem manifests | `backend-configmap.yaml`, `backend-deployment.yaml`, `backend-service.yaml` criados |

---

## 1️⃣ Nginx Config

**File:** `nginx/nginx.conf`
_(copiada como-está para `02-configmap.yaml` data.nginx.conf)_

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # SPA routing — OBRIGATÓRIO
    # Sem isso, qualquer refresh em /relatorios, /metas, /calendario retorna 404
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy para o backend Node.js/Express
    # O Service K8s do backend chama-se "backend" e ouve na porta 3001
    location /api/ {
        proxy_pass http://backend:3001/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Manifest PWA
    location = /manifest.json {
        add_header Content-Type application/manifest+json;
    }

    # Cache 1 ano para assets estáticos (JS/CSS têm hash no nome pelo Vite build)
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|webp)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Health check para Kubernetes probes (direto no Nginx, sem depender do backend)
    location /health {
        return 200 'ok';
        add_header Content-Type text/plain;
    }
}
```

---

## 2️⃣ Kubernetes Manifests

### 00-namespace.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: financial
  labels:
    name: financial
    environment: production
    app.kubernetes.io/part-of: financial-app
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
```

### 01-serviceaccount.yaml

ServiceAccount para os pods + Role/RoleBinding com acesso mínimo a ConfigMaps e Secrets.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: financial-app-sa
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: financial-app-role
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: financial-app-rolebinding
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: financial-app-role
subjects:
- kind: ServiceAccount
  name: financial-app-sa
  namespace: financial
```

### 01b-deployer-sa.yaml

ServiceAccount de CI/CD com permissão apenas de `patch`/`update` em Deployments e `get`/`list`/`watch` em Pods.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: financial-deployer
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: financial-deployer-role
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
rules:
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "patch", "update"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: financial-deployer-rolebinding
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: financial-deployer-role
subjects:
- kind: ServiceAccount
  name: financial-deployer
  namespace: financial
```

### 02-configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: financial-nginx-config
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
data:
  nginx.conf: |
    server {
        listen 80;
        root /usr/share/nginx/html;
        index index.html;

        location / {
            try_files $uri $uri/ /index.html;
        }

        location /api/ {
            proxy_pass http://backend:3001/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location = /manifest.json {
            add_header Content-Type application/manifest+json;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|webp)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        location /health {
            return 200 'ok';
            add_header Content-Type text/plain;
        }
    }
```

### 03-secret.yaml

> ⚠️ Apenas placeholders no repositório. Configure via `kubectl` antes do deploy.

```yaml
# Para configurar o secret real no cluster:
#   kubectl create secret generic financial-app-secret \
#     -n financial \
#     --from-literal=MONGO_CONN_MAP='{"1234":"mongodb+srv://user:pass@cluster.mongodb.net/db?retryWrites=true&w=majority"}' \
#     --from-literal=VAPID_PUBLIC_KEY="B..." \
#     --from-literal=VAPID_PRIVATE_KEY="y..." \
#     --dry-run=client -o yaml | kubectl apply -f -

apiVersion: v1
kind: Secret
metadata:
  name: financial-app-secret
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
type: Opaque
stringData:
  MONGO_CONN_MAP: '{"CONFIGURE_PIN":"mongodb+srv://CONFIGURE_USER:CONFIGURE_PASS@CONFIGURE_CLUSTER.mongodb.net/CONFIGURE_DB?retryWrites=true&w=majority"}'
  VAPID_PUBLIC_KEY: "CONFIGURE_VIA_npx_web-push_generate-vapid-keys"
  VAPID_PRIVATE_KEY: "CONFIGURE_VIA_npx_web-push_generate-vapid-keys"
```

**⚠️ Atenção ao gerar VAPID keys:**
- Usar `npx web-push` no **host Windows** com Node 26 gera formato incompatível com `web-push@3.x` do container (Node 20)
- Gerar DENTRO do container do backend:
  ```powershell
  docker run --rm ghcr.io/vibecodia/vibecodia-finances-backend:latest `
    node -e "const wp=require('web-push');const k=wp.generateVAPIDKeys();console.log(JSON.stringify(k))"
  ```
- `MONGO_CONN_MAP` deve ser salvo sem BOM (PowerShell `Out-File`/`Set-Content` adicionam BOM):
  ```powershell
  $json = '{"1234":"mongodb+srv://..."}'
  [System.IO.File]::WriteAllText("mongo.json", $json, (New-Object System.Text.UTF8Encoding $False))
  ```

### backend-configmap.yaml ← NOVO

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: financial-backend-config
  namespace: financial
  labels:
    app: backend
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
data:
  PORT: "3001"
  NODE_ENV: "production"
  APP_NAME: "vibecodia-finances-backend"
  TZ: "America/Sao_Paulo"
```

### backend-deployment.yaml ← NOVO

> ⚠️ `replicas: 1` é fixo e intencional — o backend tem cron jobs às 02h e 09h que disparariam em duplicata com múltiplas réplicas.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: financial
  labels:
    app: backend
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
spec:
  replicas: 1   # FIXO — não alterar (cron jobs)
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        managed-by: kustomize
        project: devops-lab
        challenge: "11"
    spec:
      serviceAccountName: financial-app-sa
      terminationGracePeriodSeconds: 30
      imagePullSecrets:
      - name: ghcr-secret
      containers:
      - name: backend
        image: ghcr.io/vibecodia/vibecodia-finances-backend:latest
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 3001
          protocol: TCP
        envFrom:
        - configMapRef:
            name: financial-backend-config
        - secretRef:
            name: financial-app-secret
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /api/health-check
            port: http
          initialDelaySeconds: 20
          periodSeconds: 20
          timeoutSeconds: 3
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /api/health-check
            port: http
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 2
          failureThreshold: 3
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 5"]
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1000   # user node na imagem node:20-alpine
          capabilities:
            drop: [ALL]
```

### backend-service.yaml ← NOVO

> O nome `backend` é obrigatório — bate com `proxy_pass http://backend:3001/api/` no nginx.conf.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend      # NOME FIXO — não alterar (nginx proxy_pass)
  namespace: financial
  labels:
    app: backend
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - name: http
    protocol: TCP
    port: 3001
    targetPort: 3001
  sessionAffinity: None
```

### 04-deployment.yaml (frontend)

> `runAsNonRoot` removido — a imagem `nginx:alpine` com `user nginx;` precisa iniciar como root para criar `/var/cache/nginx`.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: financial-deployment
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: financial-app
  template:
    metadata:
      labels:
        app: financial-app
        managed-by: kustomize
        project: devops-lab
        challenge: "11"
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "80"
        prometheus.io/path: "/"
    spec:
      serviceAccountName: financial-app-sa
      terminationGracePeriodSeconds: 30
      imagePullSecrets:
      - name: ghcr-secret
      containers:
      - name: financial-app
        image: ghcr.io/vibecodia/vibecodia-finances-frontend:latest
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 80   # Dockerfile.frontend → nginx:alpine → porta 80
          protocol: TCP
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
        livenessProbe:
          httpGet:
            path: /health     # return 200 direto no nginx.conf — não depende do backend
            port: http
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 3
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: http
          initialDelaySeconds: 3
          periodSeconds: 5
          timeoutSeconds: 2
          failureThreshold: 2
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "sleep 5"]
        securityContext:
          allowPrivilegeEscalation: false
          # runAsNonRoot: NÃO — nginx:alpine precisa de root para /var/cache/nginx
          capabilities:
            drop: [ALL]
            add: [CHOWN, SETUID, SETGID, DAC_OVERRIDE]
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/conf.d
          readOnly: true
      volumes:
      - name: nginx-config
        configMap:
          name: financial-nginx-config
          items:
          - key: nginx.conf
            path: default.conf   # nginx:alpine lê /etc/nginx/conf.d/default.conf
```

### 05-service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: financial-service
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
spec:
  type: ClusterIP
  selector:
    app: financial-app
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80   # Dockerfile.frontend expõe porta 80

---
apiVersion: v1
kind: Service
metadata:
  name: financial-service-nodeport
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
spec:
  type: NodePort
  selector:
    app: financial-app
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30800   # sem conflito com Desafio 4 (30080)
```

### 06-ingress.yaml

> `/api` deve vir **antes** de `/` — o Ingress NGINX aplica match mais específico primeiro.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: financial-ingress
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
spec:
  ingressClassName: nginx
  rules:
  - host: financial.local
    http:
      paths:
      # API backend — ANTES do path "/" (match mais específico primeiro)
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 80
      # Frontend SPA — catch-all
      - path: /
        pathType: Prefix
        backend:
          service:
            name: financial-service
            port:
              number: 80
```

### 07-hpa.yaml

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: financial-hpa
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: financial-deployment
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 4
        periodSeconds: 30
      selectPolicy: Max
```

### 08-pdb.yaml

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: financial-pdb
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: financial-app
```

### 09-networkpolicy.yaml

> **Bug crítico corrigido:** label do namespace `ingress-nginx` é `app.kubernetes.io/name: ingress-nginx`, não `name: ingress-nginx`.
> Verificar antes do deploy: `kubectl get namespace ingress-nginx --show-labels`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: financial-network-policy
  namespace: financial
  labels:
    app: financial-app
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
spec:
  podSelector:
    matchLabels:
      app: financial-app
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    # LABEL REAL do namespace ingress-nginx neste cluster
    - namespaceSelector:
        matchLabels:
          app.kubernetes.io/name: ingress-nginx
    # Comunicação interna (frontend → backend e vice-versa)
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 3001
  egress:
  # Frontend → backend (dentro do namespace)
  - to:
    - podSelector: {}
    ports:
    - protocol: TCP
      port: 3001
  # Resolução DNS
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: UDP
      port: 53
  # Backend → MongoDB Atlas (HTTPS/TLS)
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 27017
```

### kustomization.yaml

> `commonLabels:` foi trocado por `labels:` com `includeSelectors: false` — a versão antiga sobrescrevia os seletores dos Deployments, causando falha no apply após o primeiro deploy.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: financial

resources:
- 00-namespace.yaml
- 01-serviceaccount.yaml
- 01b-deployer-sa.yaml
- 02-configmap.yaml
- 03-secret.yaml
- backend-configmap.yaml
- backend-deployment.yaml
- backend-service.yaml
- 04-deployment.yaml
- 05-service.yaml
- 06-ingress.yaml
- 07-hpa.yaml
- 08-pdb.yaml
- 09-networkpolicy.yaml

labels:
- pairs:
    managed-by: kustomize
    project: devops-lab
    challenge: "11"
  includeSelectors: false
  includeTemplates: false
```

---

## 3️⃣ CI/CD Workflow

**File:** `.github/workflows/ci-cd.yml`

Pipeline automático acionado em push para `main`:
1. Build das imagens Docker (frontend + backend) via `docker/build-push-action`
2. Push para GHCR com tags `latest` e `sha-<commit>`
3. Deploy no cluster via `kubectl set image` + `kubectl rollout status`
4. Usa o ServiceAccount `financial-deployer` com token de curta duração (`kubectl create token`)

---

## 4️⃣ Scripts PowerShell

| Script | Uso |
|--------|-----|
| `deploy.ps1` | Deploy via kustomize, verifica pré-requisitos, aguarda rollout |
| `verify.ps1` | Verifica saúde de Deployments, Pods, Services, Ingress, HPA, PDB, NetworkPolicy |
| `cleanup.ps1` | Remove o namespace `financial` com confirmação; verifica que o namespace `app` (Desafio 4) não foi afetado |

---

## 🔄 Workflow de Deployment

### Pré-deploy obrigatório

```powershell
# 1. Criar secret de pull do GHCR (PAT clássico com escopo read:packages)
kubectl create secret docker-registry ghcr-secret `
  -n financial `
  --docker-server=ghcr.io `
  --docker-username=SEU_USUARIO_GITHUB `
  --docker-password=SEU_PAT_GHCR `
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Gerar VAPID keys DENTRO do container do backend (não no host)
docker run --rm ghcr.io/vibecodia/vibecodia-finances-backend:latest `
  node -e "const wp=require('web-push');const k=wp.generateVAPIDKeys();console.log(JSON.stringify(k))"

# 3. Configurar o secret da aplicação
kubectl create secret generic financial-app-secret `
  -n financial `
  --from-literal=MONGO_CONN_MAP='{"SEU_PIN":"mongodb+srv://..."}' `
  --from-literal=VAPID_PUBLIC_KEY="B..." `
  --from-literal=VAPID_PRIVATE_KEY="y..." `
  --dry-run=client -o yaml | kubectl apply -f -
```

### Deploy

```powershell
cd src/desafios/desafio-11/scripts
.\deploy.ps1
```

### Verificação

```powershell
.\verify.ps1

# Acesso via port-forward (NodePort não é roteável no WSL2)
kubectl port-forward -n financial svc/financial-service 8080:80
# Abrir: http://localhost:8080
```

### Hosts file (acesso via Ingress)

```
# C:\Windows\System32\drivers\etc\hosts
192.168.49.2  financial.local
```

---

## ✅ Validação

Estado esperado após deploy bem-sucedido:

```
NAMESPACE   NAME                                      READY   STATUS    RESTARTS
financial   backend-<hash>                            1/1     Running   0
financial   financial-deployment-<hash>               1/1     Running   0
financial   financial-deployment-<hash>               1/1     Running   0
```

```powershell
# Health check backend
kubectl port-forward -n financial svc/backend 3001:3001
curl http://localhost:3001/api/health-check
# Esperado: 200 OK

# Health check frontend
kubectl port-forward -n financial svc/financial-service 8080:80
curl http://localhost:8080/health
# Esperado: ok
```

### HPA com metrics-server desabilitado

```
NAME            REFERENCE                        TARGETS              MINPODS   MAXPODS
financial-hpa   Deployment/financial-deployment  <unknown>/60%        2         8
```

`<unknown>` é esperado — `metrics-server` está desabilitado no cluster local.
Habilitar se necessário: `minikube addons enable metrics-server`

---

## 📌 Observações Importantes

| Tópico | Detalhe |
|--------|---------|
| **Namespace** | `financial` — nunca conflita com `app` (Desafio 4) |
| **Backend réplicas** | `replicas: 1` fixo — cron jobs às 02h e 09h disparariam em duplicata |
| **Frontend porta** | `80`, não `8080` — Dockerfile usa `nginx:alpine` |
| **nginx.conf path** | `/etc/nginx/conf.d/default.conf` — nginx:alpine lê este arquivo |
| **Service backend** | Nome obrigatório `backend` — proxy_pass `http://backend:3001/api/` |
| **Ingress ordem** | `/api` antes de `/` — match mais específico primeiro |
| **GHCR autenticação** | Token OAuth do Git Credential Manager não tem `read:packages` — usar PAT clássico |
| **NetworkPolicy label** | `app.kubernetes.io/name: ingress-nginx` — verificar com `--show-labels` antes do apply |
| **kustomization** | `labels:` + `includeSelectors: false` — `commonLabels:` deprecated sobrescreve seletores |
| **VAPID keys** | Gerar no container do backend, não no host (incompatibilidade Node 20 vs 26) |
| **MONGO_CONN_MAP** | Salvar sem BOM — usar `System.IO.File::WriteAllText` com `UTF8Encoding($False)` |
