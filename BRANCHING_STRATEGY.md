# Branching Strategy — 101OnTheRoad

> **Finalidade:** Documentar a estratégia de branches, o fluxo de trabalho e o padrão de dados fictícios para validação em staging.
> Este documento é referência para todos os contribuidores e para agentes de IA que atuam no repositório.

---

## 1. Visão Geral

A estratégia adota **GitFlow** com uma branch **`staging` paralela e permanente** dedicada exclusivamente a dados fictícios. Dados reais de produção e dados de teste nunca coexistem na mesma branch.

```
main        ← produção, protegida, nunca recebe push direto
develop     ← integração contínua, base para features
staging     ← ambiente de teste, dados fictícios apenas (paralelo ao GitFlow)
feature/*   ← novas funcionalidades, nasce de develop
mock/*      ← conjuntos de dados fictícios, nasce de staging
release/*   ← estabilização pré-produção, nasce de develop
hotfix/*    ← correção crítica, nasce de main
```

---

## 2. Branches — Tabela de Referência

| Branch | Propósito | Nasce de | Merge para | Push direto |
|---|---|---|---|---|
| `main` | Produção — apenas código e dados validados | `develop` via `release/*` | — | ❌ **Nunca. Somente via PR de `release/*` ou `hotfix/*`** |
| `develop` | Integração — latest de tudo aprovado | `main` (setup inicial) | `release/*` | ❌ **Nunca. Somente via PR de `feature/*`** |
| `staging` | Teste público — dados fictícios, validação visual | `staging` próprio | ❌ Nunca vai pra `develop` ou `main` | ✅ Permitido |
| `feature/<desc>` | Nova funcionalidade de UI/JS | `develop` | `develop` | ✅ |
| `mock/<op-desc>` | Conjunto de dados fictícios para staging | `staging` | `staging` | ✅ |
| `release/<semver>` | Estabilização antes da produção | `develop` | `main` + `develop` | ✅ |
| `hotfix/<desc>` | Correção crítica em produção | `main` | `main` + `develop` | ✅ |

---

## 3. Fluxo Visual

```
main        ──────────────────────────────────────────────────────  <- PROTEGIDA
                                                       ^
                                     PR aprovado (release/1.0.0)     <- unico caminho
                                                       ^
develop     ───────────────────────────────────────────+             <- PROTEGIDA
                ^                       ^
        feature/popup-stop      feature/home-cards

                    +==============================+
staging     ========| PARALELA — NUNCA MERGE ACIMA |================  <- dados ficticios
                    +==============================+
                ^                       ^
        mock/op-004-ficticia    mock/op-005-fronteira-sul
```

> **Regra de ouro:** nada vai para `main` sem antes passar por `develop`.
> O caminho obrigatório é: `feature/*` → **`develop`** → `release/*` → **`main`**.
> `staging` é uma linha paralela que **nunca** converge para `develop` ou `main`.
> Dados fictícios ficam confinados em `staging` permanentemente.

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

## 5. Fluxo de Trabalho — Dados Fictícios em Staging

```bash
# Criar branch mock a partir de staging
git checkout staging
git checkout -b mock/op-004-transporte-sul

# Editar/criar assets/js/data/operations/OP-004.json
# Rodar build
node build.js

# Criar pages/trip-200.html (copiar de pages/trip-001.html)
# Commitar
git add assets/js/data/operations/OP-004.json
git add assets/js/data/trips.js
git add pages/trip-200.html
git commit -m "mock(op-004): add fictional operation - Transporte Sul"

# Push e PR para staging
git push -u origin mock/op-004-transporte-sul
# → Abrir PR: mock/op-004-transporte-sul → staging
```

---

## 6. Numeração de tripId em Staging

| Ambiente | Faixa de tripId | Observação |
|---|---|---|
| Produção (`main`) | `001` – `101` | IDs reais, sequenciais, imutáveis |
| Staging | `200` em diante | Sem risco de colisão com produção |

> **Regra:** sempre verificar o maior `tripId` existente no staging antes de atribuir novos IDs.
> O `tripId` é global — não reinicia por operação.

---

## 7. Convenções de Nomenclatura

| Tipo | Padrão | Exemplos |
|---|---|---|
| Feature | `feature/<descricao-curta>` | `feature/popup-stop-details`, `feature/nav-prev-next` |
| Mock | `mock/<op-id-descricao>` | `mock/op-004-transporte-sul`, `mock/op-005-fronteira-rs` |
| Release | `release/<semver>` | `release/1.0.0`, `release/1.1.0` |
| Hotfix | `hotfix/<descricao>` | `hotfix/fix-trip-099-coords`, `hotfix/build-script` |

---

## 8. Padrão de Dados Fictícios — Schema Completo

Esta seção define os campos obrigatórios e opcionais para operações e viagens fictícias criadas em staging.

### 8.1 Estrutura de Operação

```json
{
  "operationId":   "OP-004",
  "operationName": "Nome descritivo da operação fictícia",
  "description":   "Descrição resumida da rota e carga",
  "status":        "completed | in_progress | pending",
  "startDate":     "YYYY-MM-DD",
  "endDate":       "YYYY-MM-DD",
  "totalDays":     3,

  "vehicle": {
    "truck":   "Marca Modelo Potência (Frota NNNN)",
    "trailer": "Tipo do semirreboque (Apelido)",
    "driver":  "Nome fictício do motorista"
  },

  "cargo": {
    "type":   "Descrição da carga",
    "weight": "XX.XXX toneladas",
    "value":  "R$ XXX.XXX,00"
  },

  "trips": [ ... ],

  "totals": { ... },
  "kpis":   { ... },
  "analysis": { ... },
  "vehicleDetail": { ... },
  "trailerDetail": { ... },

  "metadata": {
    "createdAt": "YYYY-MM-DD",
    "version":   "1.0",
    "project":   "101 on the Road",
    "author":    "Staging Mock Data",
    "fictional": true
  }
}
```

> O campo `"fictional": true` em `metadata` é obrigatório em todos os JSONs de staging.
> Serve como marcador inequívoco para distinguir dados reais de fictícios.

---

### 8.2 Estrutura de Viagem (Trip)

```json
{
  "tripId":            "200",
  "day":               1,
  "date":              "YYYY-MM-DD",
  "name":              "Dia N: Origem → Destino",
  "estimatedDistance": "XXX km",
  "estimatedTime":     "Xh Ymin",

  "origin": {
    "name":          "Nome do ponto de origem",
    "lat":           -00.0000,
    "lng":           -00.0000,
    "address":       "Rodovia BR-XXX, Km YYY – Cidade - UF",
    "departureTime": "HH:MM"
  },

  "destination": {
    "name":        "Nome do destino",
    "lat":         -00.0000,
    "lng":         -00.0000,
    "address":     "Rodovia BR-XXX, Km YYY – Cidade - UF",
    "arrivalTime": "HH:MM"
  },

  "stop": null,

  "performance": {
    "fuelConsumption_kml": 2.10,
    "fuelUsed_liters":     135.0,
    "avgSpeed_kmh":        58.0,
    "drivingTime":         "HH:MM",
    "efficiencyScore":     88,
    "classification":      "MUITO_BOM"
  },

  "costs": {
    "fuel_brl":    500.00,
    "perKm_brl":   1.80,
    "perTon_brl":  15.00
  },

  "odometer": {
    "start": 100000,
    "end":   100300
  }
}
```

---

### 8.3 Paradas Intermediárias — Campo `stop`

O campo `stop` suporta **uma parada por viagem** no schema atual (limitação do mapa Leaflet — um único waypoint intermediário). Quando houver imprevistos que gerem paradas múltiplas, registre a parada principal e documente as demais no campo `specialContext`.

#### Parada simples (sem imprevisto)

```json
"stop": {
  "name":          "Posto Ipiranga BR-116",
  "lat":           -24.000,
  "lng":           -48.000,
  "address":       "BR-116 Km 350 – Cajati - SP",
  "arrivalTime":   "09:30",
  "departureTime": "10:15",
  "duration":      "00:45",
  "reason":        "Abastecimento, refeição e banheiro"
}
```

---

### 8.4 Catálogo de Motivos de Parada (`reason`)

Use os textos padronizados abaixo para o campo `reason`. Combine quando necessário com " + ".

| Categoria | Valor do campo `reason` |
|---|---|
| **Rotina** | `"Abastecimento"` |
| **Rotina** | `"Refeição e banheiro"` |
| **Rotina** | `"Abastecimento, refeição e banheiro"` |
| **Checagem** | `"Checklist de amarração das cintas"` |
| **Checagem** | `"Checklist de amarração e reaperto de cintas"` |
| **Checagem** | `"Verificação de pneus e calibragem"` |
| **Manutenção** | `"Troca de pneu furado"` |
| **Manutenção** | `"Reparo de sistema de freio"` |
| **Imprevisto** | `"Motorista passou mal — parada para descanso médico"` |
| **Imprevisto** | `"Acidente na pista — espera por liberação da via"` |
| **Fiscal** | `"Balança rodoviária federal — pesagem obrigatória"` |
| **Fiscal** | `"Abordagem PRF — fiscalização de documentos e carga"` |
| **Fiscal** | `"Abordagem PRF — fiscalização de tacógrafo e jornada"` |
| **Logística** | `"Cruzamento de fronteira estadual (SC/PR) — documentação"` |
| **Logística** | `"Cruzamento de fronteira estadual (PR/SP) — documentação"` |
| **Logística** | `"Cruzamento de fronteira estadual (SP/MG) — documentação"` |
| **Logística** | `"Cruzamento de fronteira estadual (MG/GO) — documentação"` |

> Para paradas com múltiplos motivos: `"Abastecimento + Checklist de amarração das cintas"`.
> Para passagem de fronteira sem parada física: registre apenas no `specialContext`, não no `stop`.

---

### 8.5 Classificações de Performance (`classification`)

| Score | Classificação | Consumo típico (km/L) |
|---|---|---|
| 95–100 | `"EXCEPCIONAL"` | ≥ 2.10 |
| 88–94 | `"MUITO_BOM"` | 1.95 – 2.09 |
| 80–87 | `"OTIMO"` | 1.80 – 1.94 |
| 70–79 | `"BOM"` | 1.65 – 1.79 |
| 60–69 | `"REGULAR"` | 1.50 – 1.64 |
| < 60 | `"ABAIXO_DO_ESPERADO"` | < 1.50 |

---

### 8.6 Exemplo Completo — Viagem com Parada de Imprevisto

```json
{
  "tripId":            "202",
  "day":               2,
  "date":              "2025-03-14",
  "name":              "Dia 2: Posto Gaúcho → Pátio Logístico Curitiba",
  "estimatedDistance": "312 km",
  "estimatedTime":     "6h 20min",

  "origin": {
    "name":          "Posto Gaúcho (BR-101 Sul)",
    "lat":           -29.6843,
    "lng":           -50.7823,
    "address":       "BR-101, Km 58 – Torres - RS",
    "departureTime": "05:30"
  },

  "destination": {
    "name":        "Pátio Logístico Curitiba Sul",
    "lat":         -25.5700,
    "lng":         -49.3180,
    "address":     "Rodovia do Xisto (BR-476), Km 12 – Araucária - PR",
    "arrivalTime": "14:10"
  },

  "stop": {
    "name":          "Posto Fronteira RS/SC",
    "lat":           -29.3342,
    "lng":           -49.7301,
    "address":       "BR-101, Km 0 – Divisa RS/SC – Passo de Torres - SC",
    "arrivalTime":   "07:00",
    "departureTime": "07:45",
    "duration":      "00:45",
    "reason":        "Cruzamento de fronteira estadual (RS/SC) — documentação + Abordagem PRF — fiscalização de documentos e carga"
  },

  "performance": {
    "fuelConsumption_kml": 1.98,
    "fuelUsed_liters":     157.6,
    "avgSpeed_kmh":        52.0,
    "drivingTime":         "06:00",
    "efficiencyScore":     84,
    "classification":      "OTIMO"
  },

  "costs": {
    "fuel_brl":    598.88,
    "perKm_brl":   1.92,
    "perTon_brl":  18.10
  },

  "odometer": {
    "start": 112000,
    "end":   112312
  },

  "specialContext": "Viagem cruzou a fronteira RS/SC com abordagem da PRF. Documento CIOT apresentado sem irregularidades. Motorista abasteceu antes da fronteira. Carga: bobinas de chapa fria para estampagem."
}
```

---

## 9. Regra de Ouro — O Caminho para main

> **Nada vai para `main` sem antes passar por `develop`.**

```
feature/*  →  develop  →  release/*  →  main
hotfix/*                            →  main + develop
```

Qualquer código que pule `develop` e vá direto para `main` **viola a estratégia** e deve ser revertido.

| Situação | Ação correta |
|---|---|
| Nova funcionalidade pronta | PR de `feature/*` → `develop` |
| `develop` estável para lançar | Criar `release/x.y.z` a partir de `develop` |
| `release/x.y.z` validada | PR de `release/*` → `main` (e back-merge em `develop`) |
| Bug crítico em produção | PR de `hotfix/*` → `main` (e back-merge em `develop`) |
| Qualquer dado de staging | ❌ Nunca sobe — staging é isolada para sempre |

---

## 10. O que NÃO vai para staging

| ❌ Proibido | Motivo |
|---|---|
| Dados reais de clientes, motoristas, notas fiscais | Privacidade e LGPD |
| Coordenadas exatas de plantas industriais reais | Segurança |
| `tripId` entre 001 e 199 | Conflito com produção |
| `"fictional": true` ausente no `metadata` | Rastreabilidade |
| Merge de `staging` → `develop` ou `main` | Dados fictícios não vão pra produção |
| Push direto em `main` sem passar por `develop` | Viola a regra de ouro |
| Edição manual de `trips.js` | Sempre gerado por `node build.js` |
| `index.html.bak` ou arquivos temporários | Limpeza do repositório |

---

## 11. Checklist — Adicionando uma Nova Operação Fictícia

```
[ ] tripId começa em 200 ou maior (verificar maior ID em staging)
[ ] "fictional": true está presente em metadata
[ ] Coordenadas verificadas (lat/lng dentro dos limites do Brasil)
[ ] node build.js executado sem erros
[ ] pages/trip-NNN.html criado (copiado de pages/trip-001.html)
[ ] Um arquivo HTML por tripId
[ ] Nenhum dado real de pessoa física ou empresa
[ ] PR aberto de mock/* → staging (nunca direto para develop ou main)
```

---

## 12. Checklist — Promovendo código para main

```
[ ] Feature desenvolvida em feature/* (nunca em develop diretamente)
[ ] PR de feature/* → develop aprovado e mergeado
[ ] develop estável e testado
[ ] Branch release/x.y.z criada a partir de develop
[ ] Validação final feita na release branch
[ ] PR de release/* → main aprovado
[ ] Back-merge de release/* → develop realizado
[ ] Tag de versão criada em main (ex: v1.0.0)
[ ] NENHUM dado fictício presente no código que vai para main
```

---

## 13. Referências

- [`AGENTS.md`](AGENTS.md) — Regras para agentes de IA no repositório
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — Estrutura técnica e modelo de dados
- [`branching-strategy-plan.md`](branching-strategy-plan.md) — Plano de execução do setup inicial
- [`build.js`](build.js) — Script de build (único comando de automação)

---

*Documento mantido manualmente — atualizar sempre que a estratégia ou o schema evoluir.*
