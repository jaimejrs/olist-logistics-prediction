# Dicionário de Dados - Olist E-Commerce

Este documento descreve o conteúdo dos 9 arquivos CSV fornecidos pelo Olist que compõem a nossa **Camada Raw**.

## Tabelas Transacionais

1. **`olist_orders_dataset.csv`** (Tabela Fato Principal)
   - **O que é:** O coração do dataset. Contém uma linha para cada pedido realizado.
   - **Campos chaves:** `order_id`, `customer_id`, `order_status`.
   - **Datas importantes:** Compra, aprovação, postagem na transportadora, entrega ao cliente e previsão de entrega.

2. **`olist_order_items_dataset.csv`** (Detalhes do Pedido)
   - **O que é:** Lista os itens (produtos) contidos em cada pedido. Um pedido pode ter múltiplos itens.
   - **Campos chaves:** `order_id`, `order_item_id`, `product_id`, `seller_id`.
   - **Métricas:** Preço do produto (`price`) e valor do frete rateado para o item (`freight_value`).

3. **`olist_order_reviews_dataset.csv`** (Avaliações)
   - **O que é:** Contém os dados de satisfação do cliente em relação a um pedido.
   - **Campos chaves:** `review_id`, `order_id`.
   - **Métricas:** Nota de 1 a 5 (`review_score`), título e texto do comentário, datas de envio e resposta da pesquisa.

4. **`olist_order_payments_dataset.csv`** (Pagamentos)
   - **O que é:** Opções de pagamento utilizadas em um pedido. Um pedido pode ter múltiplos pagamentos (ex: cartão de crédito + voucher).
   - **Campos chaves:** `order_id`, `payment_sequential`.
   - **Métricas:** Tipo de pagamento, parcelas (`payment_installments`) e valor pago (`payment_value`).

## Tabelas de Dimensão (Cadastros)

5. **`olist_customers_dataset.csv`** (Dimensão Clientes)
   - **O que é:** Informações sobre o cliente e sua localização.
   - **Campos chaves:** `customer_id` (ID que liga a compra ao pedido) e `customer_unique_id` (ID único do cliente real na plataforma, usado para mapear recompra).
   - **Atributos:** Prefixo do CEP, cidade e estado (UF).

6. **`olist_sellers_dataset.csv`** (Dimensão Vendedores)
   - **O que é:** Informações sobre o lojista/vendedor (parceiro do Olist) que despachou o pedido.
   - **Campos chaves:** `seller_id`.
   - **Atributos:** Prefixo do CEP, cidade e estado (UF).

7. **`olist_products_dataset.csv`** (Dimensão Produtos)
   - **O que é:** Características físicas e de catálogo dos produtos.
   - **Campos chaves:** `product_id`.
   - **Atributos:** Categoria (em português), peso (gramas), dimensões (comprimento, altura, largura em cm), número de fotos.

8. **`olist_geolocation_dataset.csv`** (Dimensão Geolocalização)
   - **O que é:** Mapeamento de CEPs do Brasil para coordenadas geográficas.
   - **Campos chaves:** `geolocation_zip_code_prefix`.
   - **Atributos:** Latitude, longitude, cidade e estado.

9. **`product_category_name_translation.csv`** (Dimensão Tradução)
   - **O que é:** Tabela simples que traduz o nome da categoria do português para o inglês.

---

# Camada Analytics (Modelo Dimensional)

Tabelas e views construídas pelo ETL no schema `analytics` (Neon/PostgreSQL). O grão de
`fact_orders` e dos marts é **1 linha = 1 pedido entregue** (`order_id`), recorte `delivered`
e `purchase_ts >= 2017-01-01`. Total atual: **96.203 pedidos**.

## `analytics.fact_orders` (tabela-fato)

Hub central de análises e ML. Itens e pagamentos são agregados ao grão do pedido.

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `order_id` | text | Identificador único do pedido (chave do grão). |
| `customer_unique_id` | text | Identificador único do cliente real (recompra). |
| `uf_cliente` | text | UF de destino (cliente). |
| `uf_seller` | text | UF de origem (seller do item principal). |
| `distancia_km` | numeric | Distância Haversine seller→cliente (coordenadas médias do CEP). ~0,5% nulos. |
| `categoria_principal` | text | Categoria (em inglês) do item de maior valor do pedido. |
| `purchase_ts` | timestamp | Data/hora da compra. |
| `ano_compra` | int | Ano da compra (derivado). |
| `mes_compra` | int | Mês da compra (1–12). |
| `dia_semana_compra` | int | Dia da semana da compra (0=domingo). |
| `prazo_prometido_dias` | numeric | Prazo prometido no checkout (`estimated_ts − purchase_ts`), em dias. **Feature pré-compra.** |
| `estimated_ts` | timestamp | Data estimada de entrega informada na compra. |
| `delivered_ts` | timestamp | Data real de entrega ao cliente (pós-compra). |
| `qtd_itens` | bigint | Quantidade de itens no pedido. |
| `qtd_sellers` | bigint | Número de sellers distintos no pedido. |
| `valor_produtos` | numeric | Soma dos preços dos produtos (R$). |
| `frete_total` | numeric | Soma dos fretes (R$). |
| `peso_total_g` | float | Peso total do pedido (gramas). |
| `valor_pago` | numeric | Valor total pago (R$). |
| `max_parcelas` | bigint | Parcelas do pagamento predominante. |
| `tipo_pagamento` | text | Tipo do pagamento predominante. |
| `review_score` | bigint | Nota da avaliação (1–5); nulo se sem review. |
| `lead_time_dias` | numeric | Dias entre compra e entrega (pós-entrega). |
| `atraso_dias` | numeric | Dias de atraso (`delivered_ts − estimated_ts`); negativo = adiantado. |
| `flag_atraso` | int | **Alvo M1.** 1 se entregue após o estimado, senão 0. |
| `flag_review_ruim` | int | **Alvo M2.** 1 se `review_score <= 3`; nulo se sem review. |

## `analytics.dim_date` (dimensão calendário)

Uma linha por dia no intervalo dos pedidos (2017-01-05 a 2018-08-29). Usada no Power BI
para inteligência temporal (relaciona com `purchase_date` dos marts).

| Coluna | Tipo | Descrição |
|--------|------|-----------|
| `data` | date | Data (chave). |
| `ano` | int | Ano. |
| `trimestre` | int | Trimestre (1–4). |
| `mes` | int | Mês (1–12). |
| `nome_mes` | text | Nome do mês (pt-BR). |
| `semana_ano` | int | Semana do ano. |
| `dia_semana` | int | Dia da semana (0=domingo). |
| `nome_dia_semana` | text | Nome do dia (pt-BR). |
| `dia` | int | Dia do mês. |
| `fim_de_semana` | bool | True para sábado/domingo. |

## `analytics.mart_logistics` (view → Modelo 1 e BI de logística)

Subconjunto de `fact_orders` focado em logística, com `purchase_date` para relacionar com
`dim_date`. Para treino do Modelo 1, **excluir** as colunas pós-entrega (`lead_time_dias`,
`atraso_dias`) por serem leakage. Colunas: `order_id`, `customer_unique_id`, `purchase_date`,
`uf_cliente`, `uf_seller`, `distancia_km`, `categoria_principal`, `ano_compra`, `mes_compra`,
`dia_semana_compra`, `prazo_prometido_dias`, `qtd_itens`, `qtd_sellers`, `valor_produtos`,
`frete_total`, `peso_total_g`, `valor_pago`, `max_parcelas`, `tipo_pagamento`, `lead_time_dias`,
`atraso_dias`, `flag_atraso`.

## `analytics.mart_customer_satisfaction` (view → Modelo 2 e BI de satisfação)

Subconjunto de `fact_orders` com review presente (`flag_review_ruim IS NOT NULL`). Aqui
`flag_atraso`/`atraso_dias` **são features válidas** (o review ocorre após a entrega). Acrescenta
`review_score` e `flag_review_ruim` em relação ao `mart_logistics`.
