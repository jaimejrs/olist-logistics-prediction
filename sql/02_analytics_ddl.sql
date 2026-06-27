-- ============================================================
-- Analytics DDL — fact_orders + marts
-- Idempotente: drops na ordem correta + CREATE
-- Grão: 1 linha por pedido entregue (order_id)
-- ============================================================

-- Drop na ordem inversa de dependência (views antes da tabela)
DROP VIEW  IF EXISTS analytics.mart_customer_satisfaction;
DROP VIEW  IF EXISTS analytics.mart_logistics;
DROP TABLE IF EXISTS analytics.fact_orders;

-- ------------------------------------------------------------
-- fact_orders
-- Hub central de todas as análises e modelos
-- ------------------------------------------------------------
CREATE TABLE analytics.fact_orders AS
WITH itens AS (
    -- Agrega order_items para o grão do pedido
    -- Categoria e seller do item de maior valor = proxy do produto principal
    SELECT
        oi.order_id,
        COUNT(*)                                                            AS qtd_itens,
        COUNT(DISTINCT oi.seller_id)                                       AS qtd_sellers,
        ROUND(SUM(oi.price)::numeric, 2)                                   AS valor_produtos,
        ROUND(SUM(oi.freight_value)::numeric, 2)                           AS frete_total,
        SUM(COALESCE(p.product_weight_g, 0))                               AS peso_total_g,
        (ARRAY_AGG(COALESCE(t.product_category_name_english, 'unknown')
                   ORDER BY oi.price DESC))[1]                             AS categoria_principal,
        (ARRAY_AGG(oi.seller_id ORDER BY oi.price DESC))[1]               AS seller_principal_id
    FROM raw.order_items oi
    LEFT JOIN raw.products p
           ON p.product_id = oi.product_id
    LEFT JOIN raw.category_translation t
           ON t.product_category_name = p.product_category_name
    GROUP BY oi.order_id
),
pag AS (
    -- Agrega order_payments para o grão do pedido
    -- Tipo e parcelas do pagamento de maior valor = pagamento predominante
    SELECT
        order_id,
        ROUND(SUM(payment_value)::numeric, 2)                              AS valor_pago,
        (ARRAY_AGG(payment_installments ORDER BY payment_value DESC))[1]   AS max_parcelas,
        (ARRAY_AGG(payment_type         ORDER BY payment_value DESC))[1]   AS tipo_pagamento
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    -- Identificadores
    o.order_id,
    c.customer_unique_id,
    -- Geografias
    c.uf_cliente,
    s.uf_seller,
    -- Produto principal
    i.categoria_principal,
    -- Temporais (features seguras para Modelo 1 — existem no momento da compra)
    o.purchase_ts,
    EXTRACT(YEAR  FROM o.purchase_ts)::int                                 AS ano_compra,
    EXTRACT(MONTH FROM o.purchase_ts)::int                                 AS mes_compra,
    EXTRACT(DOW   FROM o.purchase_ts)::int                                 AS dia_semana_compra,
    -- Datas de entrega (pós-compra — usar apenas em análises e Modelo 2)
    o.estimated_ts,
    o.delivered_ts,
    -- Métricas de itens
    i.qtd_itens,
    i.qtd_sellers,
    i.valor_produtos,
    i.frete_total,
    i.peso_total_g,
    -- Métricas de pagamento
    p.valor_pago,
    p.max_parcelas,
    p.tipo_pagamento,
    -- Review
    r.review_score,
    -- Métricas derivadas pós-entrega (NÃO usar como feature no Modelo 1)
    ROUND((EXTRACT(EPOCH FROM (o.delivered_ts - o.purchase_ts))  / 86400.0)::numeric, 2) AS lead_time_dias,
    ROUND((EXTRACT(EPOCH FROM (o.delivered_ts - o.estimated_ts)) / 86400.0)::numeric, 2) AS atraso_dias,
    -- Variáveis-alvo
    CASE WHEN o.delivered_ts > o.estimated_ts THEN 1 ELSE 0 END           AS flag_atraso,
    CASE WHEN r.review_score IS NULL THEN NULL
         WHEN r.review_score <= 3   THEN 1
         ELSE 0 END                                                        AS flag_review_ruim
FROM staging.orders o
JOIN  staging.customers      c  ON c.customer_id       = o.customer_id
LEFT JOIN itens              i  ON i.order_id           = o.order_id
LEFT JOIN staging.sellers    s  ON s.seller_id          = i.seller_principal_id
LEFT JOIN pag                p  ON p.order_id           = o.order_id
LEFT JOIN staging.order_reviews r ON r.order_id         = o.order_id
WHERE o.order_status = 'delivered'
  AND o.delivered_ts IS NOT NULL
  AND o.purchase_ts  >= '2017-01-01';

-- ------------------------------------------------------------
-- mart_logistics
-- Features disponíveis no momento da compra → Modelo 1 (flag_atraso)
-- Inclui métricas pós-entrega para análise, mas o notebook de ML
-- deve excluí-las do X_train (lead_time_dias, atraso_dias)
-- ------------------------------------------------------------
CREATE VIEW analytics.mart_logistics AS
SELECT
    order_id,
    customer_unique_id,
    uf_cliente,
    uf_seller,
    categoria_principal,
    ano_compra,
    mes_compra,
    dia_semana_compra,
    qtd_itens,
    qtd_sellers,
    valor_produtos,
    frete_total,
    peso_total_g,
    valor_pago,
    max_parcelas,
    tipo_pagamento,
    lead_time_dias,
    atraso_dias,
    flag_atraso
FROM analytics.fact_orders;

-- ------------------------------------------------------------
-- mart_customer_satisfaction
-- Todas as features + flag_atraso como feature → Modelo 2 (flag_review_ruim)
-- flag_atraso é permitida aqui pois o review ocorre após a entrega
-- ------------------------------------------------------------
CREATE VIEW analytics.mart_customer_satisfaction AS
SELECT
    order_id,
    customer_unique_id,
    uf_cliente,
    uf_seller,
    categoria_principal,
    mes_compra,
    dia_semana_compra,
    qtd_itens,
    valor_produtos,
    frete_total,
    peso_total_g,
    valor_pago,
    max_parcelas,
    tipo_pagamento,
    lead_time_dias,
    atraso_dias,
    flag_atraso,
    review_score,
    flag_review_ruim
FROM analytics.fact_orders
WHERE flag_review_ruim IS NOT NULL;
