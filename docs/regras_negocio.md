# Regras de Negócio e Decisões de Arquitetura

Este documento consolida as regras de negócio acordadas para o projeto **Olist Logistics Prediction**, servindo como base para as transformações no ETL (Camada Staging e Analytics) e na modelagem de Machine Learning.

## 1. Variáveis-Alvo (Target)
Nosso problema de negócio busca prever atrasos de entrega e baixa satisfação.
- **Variável Alvo 1 (Atraso Logístico):**
  - **Regra:** Um pedido é considerado **Atrasado (1)** se a data efetiva de entrega ao cliente (`order_delivered_customer_date`) for estritamente MAIOR que a data estimada informada no momento da compra (`order_estimated_delivery_date`).
  - **Se entregue no prazo ou antes:** **No prazo (0)**.
- **Variável Alvo 2 (Cliente Insatisfeito):**
  - **Regra:** Um pedido tem **Review Ruim (1)** se a nota final (`review_score`) for igual ou inferior a 3.
  - **Se a nota for 4 ou 5:** **Cliente Satisfeito (0)**.

## 2. Granularidade Analítica (A Regra de Ouro)
- Toda a modelagem estatística, de Machine Learning e o Dashboard final (Power BI) serão construídos no nível de granularidade: **1 Linha = 1 Pedido (`order_id`)**.
- As tabelas que possuem mais de uma linha por pedido (Itens e Pagamentos) serão **agregadas** (através de soma, máximo, contagem, etc.) para se unirem à tabela Fato no nível do pedido.

## 3. Tratamento de Anomalias e Qualidade de Dados (Camada Staging)
- **Filtro de Pedidos Concluídos:** O foco analítico do modelo requer que o desfecho de entrega exista. Pedidos com status diferente de `delivered` ou com data de entrega ao cliente nula não entram no cômputo da tabela analítica Fato.
- **Filtro Temporal:** O ano de 2016 representa o período de lançamento do marketplace (< 1% dos pedidos) e distorce análises sazonais e splits de treino/teste. Aplicar `purchase_ts >= '2017-01-01'` em toda a camada Analytics e nos modelos.
- **Desduplicação de Reviews:** Ocasionalmente, o mesmo pedido possui mais de um review (avaliações feitas ou alteradas em datas distintas). A regra é utilizar o `DISTINCT ON (order_id)` capturando apenas a **avaliação mais recente**.
- **Desduplicação de Geolocation:** O dataset de geolocalização possui múltiplas coordenadas cadastradas sob o mesmo prefixo de CEP. Para evitar problemas no JOIN (produto cartesiano), agregamos a tabela por `zip_code_prefix`, calculando a média (AVG) de latitude e longitude.
- **Nulos em Produtos:** O campo `product_category_name` tem ~1.85% de nulos — preencher com `'unknown'`. Campos numéricos de dimensão/peso com nulos residuais (~0.01%) — imputar com a mediana da coluna.
- **Agregação de Itens (order_items → orders):** `SUM(price) AS valor_produtos`, `SUM(freight_value) AS frete_total`, `COUNT(*) AS qtd_itens`, `COUNT(DISTINCT seller_id) AS qtd_sellers`.
- **Agregação de Pagamentos (order_payments → orders):** `SUM(payment_value) AS valor_pago`, `MAX(payment_installments) AS max_parcelas`, tipo de pagamento predominante como `payment_type`.
- **Distância geográfica (`distancia_km`):** distância de Haversine entre as coordenadas médias do CEP do cliente e do CEP do seller principal (maior item), calculada em SQL via `staging.geolocation`. ~0.5% de nulos (CEP ausente na base geográfica) — imputados pela mediana quando necessário.
- **Prazo prometido (`prazo_prometido_dias`):** `order_estimated_delivery_date − order_purchase_timestamp` em dias. Representa a janela de entrega prometida ao cliente no checkout.

## 4. Perspectiva temporal (compra × entrega)
Para uma leitura honesta dos dados, as colunas de `fact_orders` são separadas pelo instante em que passam a existir:
- **Conhecidas no momento da compra:** UF de origem/destino, `distancia_km`, `prazo_prometido_dias`, peso, dimensões, valor do frete, preço, categoria, dia da semana. A `prazo_prometido_dias` (estimado − compra) entra aqui, pois a data estimada é exibida ao cliente no checkout.
- **Conhecidas apenas após a entrega:** `lead_time_dias`, `atraso_dias`, `flag_atraso` e, após a avaliação, `review_score`/`flag_review_ruim`.

Essa separação evita atribuir ao "momento da compra" um fato que só se conhece na entrega.

## 5. Distribuição das classes-alvo
- `flag_atraso`: minoritária (~8–10% dos pedidos entregues).
- `flag_review_ruim`: minoritária (~25–30% dos reviews com nota ≤ 3).
