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
dim_date[data] 1──* fact_orders[data_compra]
```

| Tabela | Conteúdo |
|--------|----------|
| `fact_orders` | Fato (1 linha = 1 pedido entregue) + colunas calculadas: `situacao_entrega`, `faixa_atraso`, `perfil_seller`, `dia_semana_nome`, `rota`, `data_compra`. |
| `dim_date` | Calendário (marcada como tabela de datas) + `ano_mes`, `ano_trimestre`. |
| `_Medidas` | 28 medidas DAX (KPIs, % review ruim, time-intelligence vs. trimestre, cores de semáforo, simulador). |
| `Metas` | Limiares dos semáforos (atraso ≤8/12%, review ≤25/30%, nota ≥4,2/3,8). |
| `Param Distância/Prazo/Frete/Peso` | What-if parameters do simulador M1. |

## Páginas (8)

| # | Página | Conteúdo |
|---|--------|----------|
| 0 | Capa | Navegação (6 botões) |
| 1 | Visão Executiva | 5 KPIs + tendência mensal/trimestral + categorias + distribuição de nota |
| 2 | Logística & Atrasos | Efeito-limiar, perfil atrasado×no prazo, dia da semana, dispersão, multi-seller |
| 3 | Satisfação | Atraso×satisfação, 100% empilhado, pagamento, categorias, curva de impacto |
| 4 | Geográfica | Mapa por UF, top rotas, rankings UF cliente/seller |
| 5a | ML — Desempenho | Figuras dos modelos (`reports/*.png` embutidas no fundo) |
| 5b | ML — Simulador M1 | What-if + gauge de probabilidade + classificação + recomendação |
| 6 | Metodologia | Página-texto (problema, pipeline, estatística, glossário, limitações) |

Os **fundos** (`powerbi/backgrounds/*.svg`) foram rasterizados para PNG 1280×720 e
aplicados como plano de fundo de cada página; os visuais (transparentes, sem título)
são posicionados sobre os cards. O **tema** `olist_theme` (paleta teal Olist) já vem aplicado.

## Simulador M1 (página 5b)

O simulador é **interativo via What-if + DAX** (`_Medidas[Sim Probabilidade Atraso]`),
uma aproximação logística transparente baseada nas features de maior ganho do M1
(prazo prometido, distância, frete, peso). Para a **predição fiel do modelo treinado**,
substitua o gauge por um **Python visual** carregando `models/modelo1_atraso.pkl` e
`models/modelo1_thresholds.pkl` (ver `docs/dashboard_layout.md` §5). Os `.pkl` não estão
versionados (gerados por `notebooks/03_modelagem.ipynb`).

## Observações

- Os slicers do painel de filtros estão replicados nas páginas 1–4; para sincronizá-los,
  use *Exibir → Sincronizar segmentações* no Desktop.
- O mapa preenchido usa `uf_cliente` (categoria *State or Province*) e requer mapas do Bing.
