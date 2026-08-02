# AGENTS.md — Regras para Agentes de IA

> Este arquivo define as regras e restrições que agentes de IA (ex: IBM Bob, GitHub Copilot, ChatGPT)
> devem seguir ao atuar neste repositório.
> Leia este arquivo **antes** de qualquer edição.

---

## 1. Sobre o Projeto

**Repositório:** `devopslab`
**Finalidade:** Guia de setup de ambiente local Kubernetes no Windows (Docker Desktop + Minikube + kubectl),
documentado em HTML estático com tema dark.

**Estrutura:**
```
devopslab/
├── docs/
│   ├── index.html              ← guia principal (7 passos + pré-requisitos)
│   ├── prereqs/
│   │   ├── so.html             ← pré-requisito: Sistema Operacional
│   │   ├── wsl2.html           ← pré-requisito: WSL 2
│   │   ├── virtualizacao.html  ← pré-requisito: Virtualização
│   │   └── dotnet.html         ← pré-requisito: .NET Framework
│   └── assets/
│       ├── css/style.css       ← tema dark, variáveis CSS, layout
│       ├── js/main.js          ← nav highlight + copy-to-clipboard
│       └── img/
│           ├── guide-icon.svg  ← ícone "livro + seta" para links de guia
│           └── home-icon.svg   ← ícone "home" para links de retorno
├── readme.md
├── BRANCHING_STRATEGY.md
└── AGENTS.md                   ← este arquivo
```

---

## 2. Branching — Resumo Operacional

Seguir integralmente o [`BRANCHING_STRATEGY.md`](BRANCHING_STRATEGY.md). Pontos críticos:

| Regra | Detalhe |
|---|---|
| **Nunca push direto em `main`** | Somente via PR de `release/*` ou `hotfix/*` |
| **Nunca push direto em `develop`** | Somente via PR de `feature/*` |
| **`staging` é isolada** | Nunca merge de `staging` → `develop` ou `main` |
| **Nova funcionalidade** | Sempre criar `feature/<desc>` a partir de `develop` |
| **Correção crítica** | Criar `hotfix/<desc>` a partir de `main` |

---

## 3. Padrão de Commits

Usar **Conventional Commits**:

```
<tipo>(<escopo>): <descrição curta em português>

tipos permitidos:
  feat     → nova funcionalidade ou página
  fix      → correção de bug ou conteúdo incorreto
  docs     → alteração apenas em documentação
  style    → formatação, CSS, sem mudança de lógica
  refactor → refatoração sem mudança de comportamento
  chore    → tarefas de manutenção (gitignore, configs)
```

**Exemplos:**
```
feat(prereqs): adicionar página de pré-requisitos WSL 2
fix(nav): corrigir truncamento do item 7. Validar na barra de navegação
docs(index): registrar observação de autostart do Docker Desktop v4.84.0
style(css): reduzir padding dos pills da nav para caber 8 itens
chore: adicionar .gitignore e AGENTS.md
```

---

## 4. Regras de Edição

### ✅ Permitido
- Editar `docs/` em branches `feature/*` ou `hotfix/*`
- Criar novas páginas em `docs/prereqs/` seguindo o layout existente
- Atualizar versões validadas e outputs reais no `index.html`
- Adicionar ícones SVG em `docs/assets/img/` (inline, sem dependências externas)

### ❌ Proibido
- Push direto em `main` ou `develop`
- Adicionar links externos dentro de tabelas de pré-requisitos (usar páginas internas)
- Adicionar scripts externos, CDN, ou dependências de rede no HTML
- Alterar o tema dark ou as variáveis CSS sem justificativa explícita
- Criar arquivos `.bak`, `.tmp` ou duplicatas de páginas

---

## 5. Padrão HTML/CSS

- **Tema:** dark, variáveis em `:root` definidas em `assets/css/style.css`
- **Fonte:** `-apple-system, "Segoe UI", system-ui, sans-serif`
- **Mono:** `"Cascadia Code", "Fira Code", "Consolas", monospace`
- **Container:** `max-width: 860px`, centrado
- **Cores principais:** `--accent: #58a6ff` · `--green: #3fb950` · `--muted: #8b949e`
- **Sem frameworks externos** — CSS puro, sem Bootstrap, Tailwind ou similares
- **SVGs:** traço fino `stroke-width: 1.8`, cor `#58a6ff`, `fill: none`

---

## 6. Versões Validadas (ambiente de referência)

| Ferramenta | Versão |
|---|---|
| OS | Windows 11 Enterprise · Build 26200 |
| WSL | 2.6.1.0 · Kernel 6.6.87.2-1 |
| Docker Desktop | 4.84.0 · Engine 29.6.2 |
| Minikube | 1.38.1 |
| kubernetes-cli (kubectl) | 1.36.3 |
| Kubernetes (cluster) | v1.35.1 |
| Chocolatey | 2.7.3 |
| .NET Framework | 4.8.09221 (Release 533509) |
| .NET Runtime | 9.0.18 · SDK 9.0.316 |

---

*Documento mantido manualmente — atualizar sempre que a estrutura ou as regras evoluírem.*
