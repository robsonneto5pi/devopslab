# Branching Strategy — devopslab

> **Finalidade:** Documentar a estratégia de branches, o fluxo de trabalho e as convenções de commits para o repositório devopslab.
> Este documento é referência para todos os contribuidores e para agentes de IA que atuam no repositório.

---

## 1. Visão Geral

A estratégia adota **GitFlow** com uma branch **`staging` paralela e permanente** dedicada a experimentos e validações que não devem ir para produção.

```
main        ← produção, protegida, nunca recebe push direto
develop     ← integração contínua, base para features
staging     ← ambiente de teste/experimentos (paralelo ao GitFlow)
feature/*   ← novas funcionalidades, nasce de develop
release/*   ← estabilização pré-produção, nasce de develop
hotfix/*    ← correção crítica, nasce de main
```

---

## 2. Branches — Tabela de Referência

| Branch | Propósito | Nasce de | Merge para | Push direto |
|---|---|---|---|---|
| `main` | Produção — documentação validada e estável | `develop` via `release/*` | — | ❌ **Nunca. Somente via PR de `release/*` ou `hotfix/*`** |
| `develop` | Integração — latest de tudo aprovado | `main` (setup inicial) | `release/*` | ❌ **Nunca. Somente via PR de `feature/*`** |
| `staging` | Experimentos e testes visuais | `staging` próprio | ❌ Nunca vai para `develop` ou `main` | ✅ Permitido |
| `feature/<desc>` | Nova página, seção ou melhoria | `develop` | `develop` | ✅ |
| `release/<semver>` | Estabilização antes da produção | `develop` | `main` + `develop` | ✅ |
| `hotfix/<desc>` | Correção crítica em produção | `main` | `main` + `develop` | ✅ |

---

## 3. Fluxo Visual

```
main        ──────────────────────────────────────────────────────  <- PROTEGIDA
                                                       ^
                                     PR aprovado (release/1.0.0)    <- único caminho
                                                       ^
develop     ───────────────────────────────────────────+            <- PROTEGIDA
                ^                       ^
        feature/prereqs-pages   feature/step7-validacao

                    +==============================+
staging     ========| PARALELA — NUNCA MERGE ACIMA |================
                    +==============================+
```

> **Regra de ouro:** nada vai para `main` sem antes passar por `develop`.
> O caminho obrigatório é: `feature/*` → **`develop`** → `release/*` → **`main`**.
> `staging` é uma linha paralela que **nunca** converge para `develop` ou `main`.

---

## 4. Setup Inicial (primeira vez)

```bash
# 1. Criar develop a partir de main
git checkout -b develop main
git push -u origin develop

# 2. Criar staging a partir de develop
git checkout -b staging develop
git push -u origin staging

# 3. Voltar para develop
git checkout develop
```

---

## 5. Fluxo de Trabalho — Nova Feature

```bash
# Sempre partir de develop atualizado
git checkout develop
git pull origin develop
git checkout -b feature/nome-da-feature

# ... editar arquivos em docs/ ...

git add .
git commit -m "feat(docs): descrição da mudança"
git push -u origin feature/nome-da-feature

# → Abrir PR no GitHub: feature/* → develop
```

---

## 6. Convenções de Nomenclatura

| Tipo | Padrão | Exemplos |
|---|---|---|
| Feature | `feature/<descricao-curta>` | `feature/prereqs-pages`, `feature/step7-validacao` |
| Release | `release/<semver>` | `release/1.0.0`, `release/1.1.0` |
| Hotfix | `hotfix/<descricao>` | `hotfix/fix-nav-truncamento`, `hotfix/link-quebrado` |

---

## 7. Padrão de Commits — Conventional Commits

```
<tipo>(<escopo>): <descrição curta em português>
```

| Tipo | Quando usar | Exemplo |
|---|---|---|
| `feat` | Nova página ou funcionalidade | `feat(prereqs): adicionar página wsl2.html` |
| `fix` | Correção de bug ou conteúdo errado | `fix(nav): corrigir truncamento item 7` |
| `docs` | Apenas documentação / texto | `docs(index): registrar versão docker 4.84.0` |
| `style` | CSS, layout, sem mudança de lógica | `style(css): reduzir padding dos pills da nav` |
| `refactor` | Refatoração sem mudança de comportamento | `refactor(prereqs): reorganizar seções` |
| `chore` | Configurações, gitignore, AGENTS.md | `chore: adicionar .gitignore e AGENTS.md` |

---

## 8. Regra de Ouro — O Caminho para main

> **Nada vai para `main` sem antes passar por `develop`.**

```
feature/*  →  develop  →  release/*  →  main
hotfix/*                            →  main + develop
```

Qualquer código que pule `develop` e vá direto para `main` **viola a estratégia** e deve ser revertido.

| Situação | Ação correta |
|---|---|
| Nova página ou melhoria pronta | PR de `feature/*` → `develop` |
| `develop` estável para lançar | Criar `release/x.y.z` a partir de `develop` |
| `release/x.y.z` validada | PR de `release/*` → `main` (e back-merge em `develop`) |
| Bug crítico em produção | PR de `hotfix/*` → `main` (e back-merge em `develop`) |

---

## 9. O que NÃO vai para main

| ❌ Proibido | Motivo |
|---|---|
| Push direto em `main` ou `develop` | Viola a regra de ouro |
| Merge de `staging` → `develop` ou `main` | Staging é isolada para sempre |
| Arquivos `.bak`, `.tmp` ou duplicatas | Limpeza do repositório |
| Credenciais, chaves ou tokens | Segurança |
| Versões de ferramentas não validadas | Manter consistência com o ambiente de referência |

---

## 10. Checklist — Promovendo código para main

```
[ ] Feature desenvolvida em feature/* (nunca em develop diretamente)
[ ] PR de feature/* → develop aprovado e mergeado
[ ] develop estável e testado localmente
[ ] Branch release/x.y.z criada a partir de develop
[ ] Validação final feita na release branch
[ ] PR de release/* → main aprovado
[ ] Back-merge de release/* → develop realizado
[ ] Tag de versão criada em main (ex: v1.0.0)
```

---

## 11. Referências

- [`AGENTS.md`](AGENTS.md) — Regras para agentes de IA no repositório
- [`readme.md`](readme.md) — Visão geral do projeto e passos rápidos

---

*Documento mantido manualmente — atualizar sempre que a estratégia ou as convenções evoluírem.*
