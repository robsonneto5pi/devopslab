# App Reference — Controle Financeiro

> Fonte: README.md do repositório externo (financial-app)
> Incluído aqui para que o Claude Code não precise acessar o repositório externo durante a implementação.

---

## 💰 Controle Financeiro

Aplicativo web para gerenciamento financeiro doméstico.

---

## 🚀 Funcionalidades

### ✅ Implementadas

- Registro de Gastos e Receitas com categorias personalizáveis
- Sistema de Status de Pagamento (pago/pendente) para despesas
- Calendário de Vencimentos com alertas para pagamentos pendentes
- Dashboard Financeiro com resumo mensal e comparativos
- Relatórios Interativos com gráficos de distribuição e evolução
- Sistema de Metas de Economia com acompanhamento de progresso
- Armazenamento Local com persistência de dados (localStorage)
- Design Responsivo otimizado para mobile

---

## 📱 Interface

- Design moderno com paleta Nordic (azuis e verdes suaves)
- Navegação por abas intuitiva
- Transições suaves e micro-interações
- Otimizado para uso em smartphones Android

---

## 🐳 Executando com Docker

### Desenvolvimento

```bash
# Clone o repositório
git clone <repository-url>
cd financial-app

# Execute com Docker Compose
docker-compose up --build

# Acesse em http://localhost:5173
```

### Produção

```bash
# Build e execute a versão de produção
docker-compose -f infra/docker/docker-compose.prod.yml up --build

# Acesse em http://localhost:8080
```

---

## 🏗️ Estrutura do Projeto

```
financial-app/
├── src/
│   ├── components/
│   │   ├── Dashboard.tsx
│   │   ├── TransactionList.tsx
│   │   ├── Calendar.tsx
│   │   ├── Reports.tsx
│   │   └── SavingsGoals.tsx
│   ├── hooks/
│   ├── types/
│   └── utils/
├── infra/
│   └── docker/
│       ├── Dockerfile            ← dev (Vite dev server, porta 5173)
│       ├── Dockerfile.prod       ← produção (multi-stage: node build → nginx:alpine, porta 8080)
│       ├── docker-compose.yml
│       ├── docker-compose.prod.yml
│       └── .env
└── package.json
```

---

## 🔑 Informações críticas para o deploy Kubernetes

| Informação | Valor |
|---|---|
| Stack | React + TypeScript + Vite |
| Build command | `npm run build` |
| Build output | `dist/` |
| Runtime container | `nginx:alpine` |
| Porta do container (prod) | `8080` |
| Backend / API | **Nenhum** — 100% client-side |
| Banco de dados | **Nenhum** — dados no localStorage |
| Secrets runtime | **Nenhum** necessário |
| Dockerfile prod | `infra/docker/Dockerfile.prod` |
| Docker Compose prod | `infra/docker/docker-compose.prod.yml` |

---

## ⚠️ Ponto de atenção para SPA

A aplicação usa React Router (ou similar) para navegação client-side.
O Nginx **precisa** de `try_files $uri /index.html` para que rotas como
`/relatorios`, `/metas`, `/calendario` funcionem ao recarregar a página.

Sem essa configuração, qualquer refresh em rota diferente de `/` retorna **404**.
