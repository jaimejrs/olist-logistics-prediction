# Dashboard — Layout & UX/UI (Fase 9)

> Especificação visual do dashboard **Power BI** do projeto *Olist Logistics Prediction*.
> Define páginas, grid, posição de cards, filtros, gráficos e páginas de texto.
> Fonte de dados: `analytics.fact_orders` (96.203 pedidos entregues, 2017-2018), `dim_date`,
> `mart_logistics`, `mart_customer_satisfaction` + modelos `.pkl` em `models/`.

---

## 1. Princípios de UX/UI adotados

| Princípio | Aplicação no dashboard |
|-----------|------------------------|
| **Pirâmide invertida** | KPI → tendência → detalhe. Começa pela síntese executiva e desce ao operacional. |
| **Regra dos 5 segundos** | Cada página responde a *uma* pergunta lida no topo (título-pergunta). |
| **Z-pattern / F-pattern** | Informação mais importante no topo-esquerdo; navegação à esquerda, ação à direita. |
| **Consistência** | Mesmo cabeçalho, painel de filtros e rodapé em todas as páginas. |
| **Pré-atenção / cor com função** | Cor só comunica estado (vermelho=ruim, verde=bom, cinza=neutro). Sem decoração. |
| **Data-ink ratio (Tufte)** | Sem 3D, sem sombras pesadas, sem gradientes em barras, gridlines suaves. |
| **Acessibilidade** | Paleta segura para daltonismo, contraste AA, rótulos de dados diretos nas barras. |
| **Mobile-aware** | Layout 16:9 desktop + view mobile vertical com KPIs empilhados na Visão Executiva. |

### Canvas & grid
- **Tamanho:** 1280 × 720 px (16:9), tipo *Custom*.
- **Grid base:** colunas de 12 (gutter 8px), margens de 24px. *Snap to grid* + *Snap to objects* ligados.
- **Cabeçalho:** faixa superior de 64px (logo Olist à esquerda, título da página ao centro, filtro de período à direita).
- **Painel de filtros:** barra lateral esquerda de 220px (recolhível via bookmark).
- **Rodapé:** 24px — fonte dos dados + data de atualização + nº de pedidos no filtro.

### Sistema visual
- **Paleta** (derivada da marca Olist — teal):
  - Primária `#0CAA9E` (teal) · Escura `#0B5563` · Destaque/risco `#E4572E` (laranja-vermelho)
  - Positivo `#2E933C` · Atenção `#F2B705` · Neutros `#F5F7F8` (fundo), `#2B2B2B` (texto), `#9AA5A8` (eixos)
- **Tipografia:** Segoe UI. Títulos 20pt semibold · KPI número 28–32pt bold · rótulos 10–11pt.
- **Cards:** cantos arredondados 8px, fundo branco, borda `#E6EBED` 1px, sombra sutil.
- **Iconografia:** ícones de linha monocromáticos no cabeçalho de cada KPI.

---

## 2. Mapa de navegação (7 páginas)

```
[0] Capa / Navegação
        │
        ├─ [1] Visão Executiva ........ KPIs gerais + tendência (entrada padrão)
        ├─ [2] Logística & Atrasos .... domínio do Modelo M1
        ├─ [3] Satisfação do Cliente .. domínio do Modelo M2
        ├─ [4] Análise Geográfica ..... mapa, rotas, UF origem/destino
        ├─ [5] Inteligência Preditiva . resultados ML + SIMULADOR M1
        └─ [6] Metodologia / Sobre .... página-texto (regras, estatística, glossário)
```

Navegação por **botões de página** num menu lateral fixo (ícone + rótulo), com estado *selected*
destacado em teal. Botão "voltar à capa" no logo. Transições por *Page navigation action*
(sem bookmarks frágeis para troca de página).

---

## 3. Painel de filtros (global, lateral esquerda)

Slicers sincronizados via **Sync slicers** entre as páginas 1–4 (a página 5 tem inputs próprios;
a 6 não tem filtros). Recolhível por bookmark (ícone funil expande/colapsa).

| Ordem | Filtro | Tipo de slicer | Campo |
|-------|--------|----------------|-------|
| 1 | **Período** | Between (timeline) | `dim_date[data]` (relaciona `purchase_ts`) |
| 2 | Ano / Trimestre | Dropdown hierárquico | `dim_date[ano] > [trimestre]` |
| 3 | UF do cliente | Dropdown (busca) | `fact_orders[uf_cliente]` |
| 4 | UF do seller | Dropdown (busca) | `fact_orders[uf_seller]` |
| 5 | Categoria | Dropdown (busca) | `fact_orders[categoria_principal]` |
| 6 | Tipo de pagamento | Lista (chips) | `fact_orders[tipo_pagamento]` |
| 7 | Situação de entrega | Botões (No prazo / Atrasado) | `fact_orders[flag_atraso]` |

- Botão **"Limpar filtros"** (bookmark *Clear all slicers*) no topo do painel.
- Indicador de filtros ativos no rodapé ("Exibindo X de 96.203 pedidos").
- Filtro de **Período** também espelhado no cabeçalho (acesso rápido sem abrir o painel).

---

## 4. Páginas — wireframes e conteúdo

Legenda do grid: `┌─┐` cards · larguras em colunas de 12.

### [0] Capa / Navegação
Página de entrada, sem dados — contexto e direção.

```
┌────────────────────────────────────────────────────────────┐
│                      [ LOGO OLIST ]                         │
│            Olist Logistics Prediction                       │
│   Prever atrasos de entrega e quedas de satisfação          │
│   num marketplace brasileiro · 96.203 pedidos · 2017–2018   │
│                                                             │
│   ┌ Visão Executiva ┐  ┌ Logística ┐  ┌ Satisfação ┐        │
│   ┌ Geográfica ┐  ┌ Preditivo ┐  ┌ Metodologia ┐            │
│                                                             │
│   Fonte: Brazilian E-Commerce Public Dataset (Kaggle)       │
└────────────────────────────────────────────────────────────┘
```
- 6 botões-cartão grandes (navegação) com ícone + título + subtítulo de 1 linha.
- Texto curto do problema de negócio (as duas perguntas-alvo).

---

### [1] Visão Executiva  — *"Como está a operação como um todo?"*

Linha de **KPIs (cards)** no topo (5 cards, 1 linha, cada ~2,4 col), com **comparação vs. trimestre anterior** (seta ▲▼ + variação %):

```
┌───────────┬───────────┬───────────┬───────────┬───────────┐
│ Pedidos   │ Taxa de   │ Nota média│ Lead time │ % Review  │
│ entregues │ atraso    │ (1–5)     │ médio (d) │ ruim      │
│  96.203   │  ~8–10%▲  │  ~4,1 ▼   │  ~12,5d   │ ~25–30%   │
└───────────┴───────────┴───────────┴───────────┴───────────┘
```

Abaixo, **2 linhas de gráficos** (6 col cada):

| Posição | Visual | Pergunta | Fonte (query) |
|---------|--------|----------|---------------|
| Meio-esq | **Linha dupla**: pedidos (área) + taxa de atraso % (linha) por mês | Sazonalidade e risco no tempo | Q3 |
| Meio-dir | **Linha**: nota média + taxa review ruim por trimestre | Satisfação melhora ou piora? | Q11 |
| Base-esq | **Barras horizontais**: Top categorias por taxa de atraso | Onde dói mais | Q4 |
| Base-dir | **Donut/Barras**: distribuição de `review_score` (1–5) | Forma da satisfação | reports/review_score_distribuicao |

- KPI de risco (taxa de atraso, review ruim) em **vermelho** quando acima da meta; verde abaixo.
- Tooltip de página customizado nos pontos da série temporal (mostra ticket, frete, lead time do mês).

---

### [2] Logística & Atrasos — *"O que causa os atrasos?"* (domínio M1)

KPIs (4 cards): Taxa de atraso · Atraso médio (dias, só atrasados) · Lead time médio · Prazo prometido médio.

```
┌── KPIs (4) ───────────────────────────────────────────────┐
├── 7 col ──────────────────────────┬── 5 col ──────────────┤
│ Faixas de atraso × nota (Q9)      │ Perfil: atrasado vs    │
│ barras divergentes / colunas      │ no prazo (Q6) — tabela │
│ (efeito-limiar da nota)           │ comparativa (ticket,   │
│                                   │ frete, peso, itens,    │
│                                   │ parcelas, lead time)   │
├── 6 col ──────────────────────────┼── 6 col ──────────────┤
│ Taxa de atraso por dia da semana  │ Scatter: frete × lead  │
│ (Q7) colunas                      │ time, cor=atraso (Q/H4)│
├── 12 col ─────────────────────────┴───────────────────────┤
│ Multi-seller × atraso (Q12) + categorias problemáticas (Q4)│
└────────────────────────────────────────────────────────────┘
```
- Destaque visual do **efeito-limiar**: a nota desaba a partir da faixa "Atrasado até 7 dias".
- Scatter usa `reports/h4_frete_leadtime.png` como referência analítica (ρ=0,38).

---

### [3] Satisfação do Cliente — *"O que derruba a nota?"* (domínio M2)

KPIs (4 cards): Nota média · % Review ruim (≤3) · % Promotores (5) · Nº de reviews.

```
┌── KPIs (4) ───────────────────────────────────────────────┐
├── 6 col ──────────────────────────┬── 6 col ──────────────┤
│ Atraso × satisfação (Q2)          │ Distribuição review    │
│ barras: nota média e %review ruim │ por situação de entrega│
│ (No prazo vs Atrasado) — valida H1│ (100% stacked)         │
├── 6 col ──────────────────────────┼── 6 col ──────────────┤
│ Satisfação por tipo de pagamento  │ Nota média por         │
│ (Q8) — nota: efeito NEGLIGÍVEL    │ categoria (top/bottom) │
│ (nota didática no card)           │ barras                 │
├── 12 col ─────────────────────────┴───────────────────────┤
│ Faixas de atraso × % review ruim (Q9) — curva de impacto   │
└────────────────────────────────────────────────────────────┘
```
- **Card de insight** (texto) destacando: *"Atraso reduz satisfação — Cliff's δ=0,55 (efeito grande). Tipo de pagamento é significativo mas irrelevante na prática (V=0,01)."*

---

### [4] Análise Geográfica — *"Onde estão as rotas críticas?"*

```
├── 7 col ──────────────────────────┬── 5 col ──────────────┤
│ MAPA do Brasil (preenchido)       │ Top 10 rotas seller→   │
│ taxa de atraso por UF cliente (Q1)│ cliente (Q10) tabela   │
│ gradiente teal→vermelho           │ com barra de %atraso   │
│ (toggle: UF cliente / UF seller)  │ embutida               │
├── 6 col ──────────────────────────┼── 6 col ──────────────┤
│ Ranking UF cliente: taxa atraso   │ Ranking UF seller:     │
│ + lead time (Q1) barras           │ origens problemáticas  │
│                                   │ (Q5) barras            │
└────────────────────────────────────────────────────────────┘
```
- Botão **toggle (bookmark)** alterna o mapa entre origem (`uf_seller`) e destino (`uf_cliente`).
- Tooltip do mapa: pedidos, taxa de atraso, lead time, frete médio, distância média da UF.
- Opcional: linhas de rota no `distancia_km` se usar visual de mapa com latitude/longitude.

---

### [5] Inteligência Preditiva — *"Dá pra prever antes de acontecer?"* (ML + Simulador)

Duas seções com **navegação por abas internas (bookmarks):** `Desempenho dos modelos` | `Simulador M1`.

**Aba A — Desempenho dos modelos**
```
┌── M1 — Atraso (AUC 0,78) ─────────┬── M2 — Review ruim (0,71) ──┐
│ card AUC + CV (0,786±0,005)       │ card AUC + CV (0,715±0,004) │
│ img m1_avaliacao (ROC/PR)         │ img m2_avaliacao            │
│ img m1_feature_importance         │ img m2_feature_importance   │
│ img m1_shap_summary               │                             │
│ img m1_threshold (custo-sensível) │                             │
└────────────────────────────────────────────────────────────────┘
```
Imagens versionadas em `reports/`. Card de leitura: *"M1 — top features: prazo prometido + distância.
M2 é dominado por atraso (confirma a H1)."*

**Aba B — Simulador M1 (interativo real)**
Painel de entrada (esquerda) → resultado (direita). Decisão do usuário: **simulador real**, então a
predição vem do modelo `.pkl`, não de aproximação DAX.

```
├── 5 col INPUTS ───────────────────┬── 7 col RESULTADO ────────┐
│ UF seller        [dropdown]       │  PROBABILIDADE DE ATRASO  │
│ UF cliente       [dropdown]       │       ┌─────────┐         │
│ Distância (km)   [slider what-if] │       │  37%    │ gauge   │
│ Prazo prometido  [slider what-if] │       └─────────┘         │
│ Frete (R$)       [slider what-if] │  Classificação: ALTO RISCO│
│ Peso (g)         [slider what-if] │  (threshold custo: 0,30)  │
│ Categoria        [dropdown]       │  Fatores que mais pesam   │
│ Dia da semana    [dropdown]       │  (mini SHAP local)        │
│ [ Calcular ]                      │  Recomendação operacional │
└────────────────────────────────────────────────────────────────┘
```
**Implementação do simulador (real):** uma das duas vias —
1. **Python visual** dentro do Power BI: carrega `models/modelo1_atraso.pkl` +
   `models/modelo1_thresholds.pkl`, recebe os valores dos slicers what-if como dataframe e plota
   o gauge de probabilidade. Mais fiel (usa o modelo treinado), requer Python no Power BI Desktop/Gateway.
2. **Endpoint Python (FastAPI) + Power BI**: o `.pkl` servido como API; o relatório consome via
   *Web.Contents*/PowerQuery ou um custom visual. Indicado se publicar no Power BI Service.

> Os controles de entrada usam **What-if parameters** (numéricos) + slicers de dimensão (UF, categoria).
> O threshold do gauge vem de `modelo1_thresholds.pkl` (faixa verde/amarelo/vermelho).

---

### [6] Metodologia / Sobre — *página-texto* (governança & confiança)

Sem gráficos interativos; blocos de texto formatados (text boxes + tabelas-imagem). Dá credibilidade
ao portfólio e documenta as regras.

```
┌────────────────────────────────────────────────────────────┐
│ 1. Problema de negócio (2 alvos: M1 atraso, M2 review ruim) │
│ 2. Fonte & escopo: Kaggle · 96.203 pedidos · delivered ·    │
│    2017-2018 · grão = 1 pedido                              │
│ 3. Pipeline Medallion (raw→staging→analytics) — mini-diagrama│
│ 4. Resultados estatísticos (tabela das 4 hipóteses + efeito)│
│    H1 Mann-Whitney δ=0,55 · Frete×região η²=0,16 · etc.    │
│ 5. Modelos (M1 0,78 / M2 0,71) + anti-leakage              │
│ 6. Glossário de métricas (taxa de atraso, lead time,        │
│    prazo prometido, flag_review_ruim…)                      │
│ 7. Limitações & próximos passos                            │
└────────────────────────────────────────────────────────────┘
```
- Reaproveita conteúdo de `docs/regras_negocio.md` e `docs/dicionario_dados.md`.
- Tabela das hipóteses destaca a lição: **significância ≠ relevância**.

---

## 5. Interatividade & padrões de comportamento

| Recurso | Onde | Como |
|---------|------|------|
| **Drill-through** | Categoria/UF → página de detalhe | clicar numa categoria abre [2] filtrada |
| **Cross-filter** | Todas as páginas de gráfico | clique numa barra filtra os demais visuais |
| **Tooltips de página** | Séries temporais e mapa | tooltip rico (mini-cards) em vez do default |
| **Bookmarks** | Painel de filtros, toggle do mapa, abas da pág. 5 | botões com estado on/off |
| **Botão "?"** | Cabeçalho | overlay de ajuda explicando ícones/filtros |
| **Reset** | Painel de filtros | "Limpar filtros" volta ao estado inicial |

### Metas/limiares (semáforos nos KPIs)
- Taxa de atraso: ≤8% verde · 8–12% amarelo · >12% vermelho.
- % review ruim: ≤25% verde · 25–30% amarelo · >30% vermelho.
- Nota média: ≥4,2 verde · 3,8–4,2 amarelo · <3,8 vermelho.
(parametrizáveis via tabela de metas no modelo.)

---

## 6. Modelo de dados no Power BI (star schema)

```
dim_date ──< fact_orders >── (mart_logistics, mart_customer_satisfaction como views de apoio)
                  │
            dim_uf (calculada) ── opcional p/ mapa (lat/long médias por UF)
```
- Relacionamento `dim_date[data]` 1:* `fact_orders[purchase_ts]` (cast p/ date).
- Medidas DAX centrais (tabela `_Medidas`): `Taxa Atraso %`, `% Review Ruim`, `Nota Média`,
  `Lead Time Médio`, `Pedidos`, `Δ vs Trim. Anterior` (time intelligence com `dim_date`).
- Tabela `Metas` (1 linha) para os limiares dos semáforos.
- Tabelas what-if (`Param Distância`, `Param Prazo`, `Param Frete`, `Param Peso`) para o simulador.

---

## 7. Checklist de entrega (Fase 9)

- [ ] Tema `.json` com a paleta Olist aplicado.
- [ ] 7 páginas montadas no grid 1280×720.
- [ ] Painel de filtros sincronizado (pág. 1–4) + limpar/colapsar.
- [ ] Medidas DAX + tabela de metas (semáforos).
- [ ] Tooltips de página, drill-through e cross-filter validados.
- [ ] Simulador M1 funcional (Python visual carregando `modelo1_atraso.pkl`).
- [ ] View mobile da Visão Executiva.
- [ ] Página Metodologia preenchida a partir dos `docs/`.
- [ ] Publicação `.pbix` em `powerbi/` + screenshots em `reports/`.
```
