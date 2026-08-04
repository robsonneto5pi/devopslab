Preciso executar o Desafio 4 de Kubernetes no meu notebook Windows.
O objetivo é fazer o deploy de uma aplicação Node.js no Minikube e acessá-la no browser.

## Ambiente
- Windows 11
- Docker Desktop instalado e rodando
- Minikube instalado
- kubectl instalado
- Chocolatey instalado

## O que precisa ser feito, em ordem:

### 1. Subir o Minikube
minikube start --cpus=2 --memory=2048 --driver=docker

### 2. Criar a estrutura de arquivos do projeto

Preciso criar os seguintes arquivos:

**src/package.json**
{
  "name": "devops-app",
  "version": "1.0.0",
  "description": "DevOps Lab — Desafio 4 Kubernetes Deployment",
  "main": "app.js",
  "scripts": {
    "start": "node app.js"
  },
  "engines": {
    "node": ">=18"
  }
}

**src/app.js**
É um servidor HTTP Node.js puro (sem Express) com 4 rotas:
- GET /        → retorna JSON com info da app (nome, versão, uptime, hostname do Pod)
- GET /health  → retorna {"status":"ok"} — usado pelo Kubernetes como liveness probe
- GET /health/ready → retorna {"status":"ready"} após 3s de warm-up — readiness probe
- GET /metrics → retorna métricas no formato Prometheus (texto plano)
- Qualquer outra rota → 404
Também precisa ter graceful shutdown (SIGTERM e SIGINT).
Porta lida de process.env.PORT ou 3000.

**Dockerfile**
Multi-stage build:
- Stage 1 (builder): node:18-alpine, instala dependências com npm install --production
- Stage 2 (runtime): node:18-alpine, cria pastas /app/cache e /app/logs, usa USER node (uid 1000), copia o build do stage 1, EXPOSE 3000, HEALTHCHECK via wget em /health, CMD ["node", "app.js"]

**k8s/00-namespace.yaml**
Namespace chamado "app"

**k8s/01-serviceaccount.yaml**
ServiceAccount "app-sa" + Role "app-role" (permissões mínimas: get/list configmaps, get secrets, get/list pods) + RoleBinding ligando os dois. Tudo no namespace "app".

**k8s/02-configmap.yaml**
ConfigMap "app-config" com: NODE_ENV=production, LOG_LEVEL=info, PORT=3000, METRICS_ENABLED=true

**k8s/03-secret.yaml**
Secret "app-secrets" tipo Opaque com: DATABASE_URL, REDIS_URL, JWT_SECRET (valores de exemplo para dev)

**k8s/04-deployment.yaml**
Deployment "app-deployment" no namespace "app":
- 3 replicas
- image: devops-app:v1.0 com imagePullPolicy: Never (imagem local do Minikube)
- RollingUpdate: maxSurge=1, maxUnavailable=0
- Resources: requests cpu=100m/memory=128Mi, limits cpu=500m/memory=256Mi
- livenessProbe: GET /health porta 3000, initialDelaySeconds=10, periodSeconds=10
- readinessProbe: GET /health/ready porta 3000, initialDelaySeconds=5, periodSeconds=5
- startupProbe: GET /health porta 3000, periodSeconds=5, failureThreshold=12
- env vindo do ConfigMap (NODE_ENV, LOG_LEVEL, PORT) e do Secret (JWT_SECRET)
- securityContext: runAsNonRoot=true, runAsUser=1000, allowPrivilegeEscalation=false, capabilities drop ALL
- volumeMount do ConfigMap em /app/config (readOnly)
- preStop lifecycle: sleep 5
- terminationGracePeriodSeconds: 30
- serviceAccountName: app-sa

**k8s/05-service.yaml**
Dois services:
1. "app-service" ClusterIP porta 80 → targetPort 3000
2. "app-nodeport" NodePort porta 80 → targetPort 3000, nodePort 30080

**k8s/06-ingress.yaml**
Ingress "app-ingress" com ingressClassName=nginx, host=app.local, rotas / /api /health /metrics apontando para app-service:80. ssl-redirect=false.

**k8s/07-hpa.yaml**
HorizontalPodAutoscaler "app-hpa":
- scaleTargetRef: Deployment/app-deployment
- minReplicas=3, maxReplicas=10
- CPU target 70%, Memory target 80% (autoscaling/v2)
- behavior: scaleDown conservador (300s), scaleUp agressivo (0s)

**k8s/08-pdb.yaml**
PodDisruptionBudget "app-pdb": minAvailable=2, selector app=app-deployment

**k8s/09-networkpolicy.yaml**
NetworkPolicy "app-network-policy":
- Ingress: permite tráfego do namespace ingress-nginx e do próprio namespace app na porta 3000
- Egress: permite DNS (UDP/TCP 53 para kube-system), HTTPS externo (443), tráfego interno

### 3. Buildar a imagem dentro do Minikube
minikube image build -t devops-app:v1.0 .

### 4. Aplicar os manifests
kubectl apply -f k8s/

### 5. Aguardar os pods ficarem prontos
kubectl rollout status deployment/app-deployment -n app --timeout=120s

### 6. Habilitar o Ingress
minikube addons enable ingress

### 7. Criar o tunnel (terminal Admin, deixar aberto)
minikube tunnel

### 8. Adicionar app.local no arquivo hosts
Adicionar a linha abaixo em C:\Windows\System32\drivers\etc\hosts:
127.0.0.1  app.local

### 9. Verificar no browser
http://app.local/
http://app.local/health
http://app.local/health/ready
http://app.local/metrics

## O que espero ver no browser em cada rota:

GET / →
{"app":"DevOps Lab — Desafio 4","version":"v1.0","env":"production","uptime":142,"requests":37,"hostname":"app-deployment-xxxxx"}

GET /health →
{"status":"ok","uptime":142,"timestamp":"...","env":"production"}

GET /health/ready →
{"status":"ready"}

GET /metrics →
texto plano com app_requests_total, app_uptime_seconds, nodejs_heap_used_bytes

## Observações importantes:
- imagePullPolicy: Never porque a imagem é buildada localmente dentro do Minikube
- O terminal do minikube tunnel precisa ficar aberto enquanto usar o Ingress
- O campo "hostname" na resposta do GET / muda a cada request — prova que o load balancing entre os 3 Pods está funcionando
- Se aparecer a página de boas-vindas do NGINX, significa que o Ingress está ativo mas os Pods ainda não subiram
- Se aparecer ERR_NAME_NOT_RESOLVED, o arquivo hosts não foi configurado corretamente
- O aviso "terminal needs to be open" do minikube tunnel/service é normal, não é erro