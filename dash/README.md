# Dashboard Power BI — Olist Logistics Prediction (.pbip)

Projeto Power BI no formato **PBIP / PBIR** (pastas versionáveis), construído conforme
[`docs/dashboard_layout.md`](../docs/dashboard_layout.md). Abra o arquivo
`olist-logistics-prediction.pbip` no **Power BI Desktop**.

## Pré-requisitos

1. **Power BI Desktop** (versão recente).
2. Preview **"Store reports using enhanced metadata format (PBIR)"** habilitado:
   *Arquivo → Opções → Recursos de visualização (preview) → PBIR*. (Necessário para abrir a pasta `definition/`.)
3. Acesso ao banco **PostgreSQL (Neon)** com as tabelas do schema `analytics`
   (geradas por `python -m src.run_etl`).

## Conectar aos dados

O modelo lê `analytics.fact_orders` e `analytics.dim_date` via conector **PostgreSQL**,
parametrizado para não expor segredos no repositório:

1. Abra o `.pbip`.
2. **Transformar dados → Editar parâmetros** e informe:
   - `PG_Server` — host do Neon, ex.: `ep-exemplo-123456.sa-east-1.aws.neon.tech`
   - `PG_Database` — nome do banco, ex.: `olist`
3. **Atualizar**. Informe usuário/senha do Neon quando solicitado (SSL obrigatório).

> O `DATABASE_URL` do projeto (`.env`) contém esses dados; copie host e database de lá.

## Modelo de dados (star schema)

```
dim_date · dim_geografia · dim_categoria · dim_pagamento · dim_cliente
                              ╲ │ ╱
                          fact_orders   (1 linha = 1 pedido entregue)
```

| Tabela | Conteúdo |
|--------|----------|
| `fact_orders` | Fato (1 linha = 1 pedido entregue) + colunas calculadas: `situacao_entrega`, `faixa_atraso`, `perfil_seller`, `dia_semana_nome`, `rota`, `data_compra`. |
| `dim_date` | Calendário (marcada como tabela de datas) + `ano_mes`, `ano_trimestre`. |
| `dim_geografia` | UF → região, lat/lng. Role-playing: UF cliente (ativa) e UF seller (inativa, via `USERELATIONSHIP`). |
| `dim_categoria` · `dim_pagamento` · `dim_cliente` | Segmento da categoria · descrição do pagamento · cliente único (recorrência, nota média, valor). |
| `_Medidas` | 35 medidas DAX (KPIs, % review ruim, time-intelligence vs. trimestre, cores de semáforo, receita e recompra). |
| `Metas` | Limiares dos semáforos (atraso ≤8/12%, review ≤25/30%, nota ≥4,2/3,8). |

## Páginas (Capa + 5)

Arco narrativo: **macro → causa logística → causa satisfação → onde → quem → como**.

| # | Página | Pergunta | Conteúdo |
|---|--------|----------|----------|
| 0 | Capa | — | Navegação (6 botões) |
| 1 | Visão Executiva | Como está a operação? | 5 KPIs + tendência mensal/trimestral + categorias + distribuição de nota |
| 2 | Logística & Atrasos | O que causa os atrasos? | Efeito-limiar, perfil atrasado×no prazo, dia da semana, dispersão, multi-seller |
| 3 | Satisfação do Cliente | O que derruba a nota? | Atraso×satisfação, 100% empilhado, pagamento, categorias, curva de impacto |
| 4 | Geografia & Regiões | Onde estão as regiões e rotas críticas? | Macro por região (destino×origem) → mapa por UF + top rotas → rankings UF cliente/seller |
| 5 | Valor do Cliente | Quem são os clientes e quanto valem? | Receita, receita em risco, recompra/retenção |

> A página **Geografia & Regiões** unifica as antigas *Geográfica* e *Regional* (macro→micro).
> A camada de **Machine Learning foi descontinuada** — não há páginas de modelos nem simulador.

Os **fundos** (`powerbi/backgrounds/*.svg`) são rasterizados para PNG 1280×720
(via Chromium headless / Playwright — ver abaixo) e aplicados como plano de fundo de
cada página; os visuais (transparentes, sem título) são posicionados sobre os cards. O **tema**
`olist_theme` (paleta teal Olist) já vem aplicado.

## Regenerar os fundos (SVG → PNG)

Os títulos, rótulos e textos ficam embutidos nos SVG de `powerbi/backgrounds/`. Para alterá-los,
edite o `.svg` e rasterize de novo (1280×720) sobrescrevendo o `bg_*.png` em
`StaticResources/RegisteredResources/` (mesmo nome → não muda o JSON). As páginas *Logística* e
*Satisfação* usam o SVG diretamente como recurso (texto vetorizado).

## Observações

- Os slicers do painel de filtros estão replicados nas páginas 1–4; para sincronizá-los,
  use *Exibir → Sincronizar segmentações* no Desktop.
- O mapa preenchido usa `uf_cliente` (categoria *State or Province*) e requer mapas do Bing.
