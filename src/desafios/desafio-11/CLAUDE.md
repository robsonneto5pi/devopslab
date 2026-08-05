# CLAUDE.md — Desafio 11: Financial App Deploy

> Escopo deste arquivo: só o índice. Todo conteúdo denso está em `refs/`.
> Regras globais do projeto: `../../CLAUDE.md`.

---

## Quem você é

Engenheiro DevOps sênior fazendo o deploy da **Controle Financeiro** (SPA React/Vite → Nginx)
no mesmo cluster Kubernetes do Desafio 4, sem tocar no namespace `app`.

---

## Leia antes de implementar qualquer coisa

| Arquivo | Conteúdo |
|---|---|
| `refs/app-readme.md` | Stack, porta, Dockerfile, limitações da app |
| `refs/deploy-plan.md` | Decisões de arquitetura (namespace, registry, replicas, ingress…) |
| `refs/rules.md` | Padrões obrigatórios de YAML, segurança, CI/CD, scripts, docs |
| `refs/checklist.md` | Ordem de criação dos arquivos + critérios de validação |
| `CHALLENGES/04_KUBERNETES_DEPLOYMENT/k8s/` | Padrão de style dos manifests (só leitura) |

---

## Permissões

**PODE:** criar/editar qualquer arquivo em `CHALLENGES/11_FINANCIAL_APP_DEPLOY/`  
**NÃO PODE:** tocar em nada fora desta pasta

---

## Restrições críticas (não negociáveis)

- Namespace: `financial` — nunca `app`
- Prefixo de todos os recursos: `financial-` — nunca reutilizar nomes do Desafio 4
- `imagePullPolicy: Always` — imagem vem do GHCR, não é local
- Secrets: apenas placeholders — zero valores reais no repositório
