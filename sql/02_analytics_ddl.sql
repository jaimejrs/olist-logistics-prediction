-- ============================================================
-- Analytics DDL — fact_orders + marts
-- Idempotente: drops na ordem correta + CREATE
-- Grão: 1 linha por pedido entregue (order_id)
-- ============================================================

-- Drop na ordem inversa de dependência (views antes da tabela)
DROP VIEW  IF EXISTS analytics.mart_customer_satisfaction;
DROP VIEW  IF EXISTS analytics.mart_logistics;
DROP TABLE IF EXISTS analytics.fact_orders;
DROP TABLE IF EXISTS analytics.dim_date;

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
    -- Distância seller→cliente (Haversine, km) — conhecida no momento da compra
    ROUND((2 * 6371 * asin(sqrt(
        power(sin(radians(gs.lat - gc.lat) / 2), 2) +
        cos(radians(gc.lat)) * cos(radians(gs.lat)) *
        power(sin(radians(gs.lng - gc.lng) / 2), 2)
    )))::numeric, 2)                                                       AS distancia_km,
    -- Produto principal
    i.categoria_principal,
    -- Temporais (atributos conhecidos no momento da compra)
    o.purchase_ts,
    EXTRACT(YEAR  FROM o.purchase_ts)::int                                 AS ano_compra,
    EXTRACT(MONTH FROM o.purchase_ts)::int                                 AS mes_compra,
    EXTRACT(DOW   FROM o.purchase_ts)::int                                 AS dia_semana_compra,
    -- Prazo prometido pela Olist no checkout (estimado − compra) — conhecido na compra
    ROUND((EXTRACT(EPOCH FROM (o.estimated_ts - o.purchase_ts)) / 86400.0)::numeric, 2) AS prazo_prometido_dias,
    -- Datas de entrega (conhecidas apenas após a entrega)
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
    -- Métricas derivadas pós-entrega
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
LEFT JOIN staging.geolocation gc ON gc.zip_prefix       = c.zip_prefix::int  -- coords do cliente
LEFT JOIN staging.geolocation gs ON gs.zip_prefix       = s.zip_prefix::int  -- coords do seller
WHERE o.order_status = 'delivered'
  AND o.delivered_ts IS NOT NULL
  AND o.purchase_ts  >= '2017-01-01';

-- ------------------------------------------------------------
-- dim_date
-- Dimensão calendário — uma linha por dia no intervalo dos pedidos
-- Usado pelo Power BI para time intelligence (YTD, MoM, drill-down)
-- ------------------------------------------------------------
CREATE TABLE analytics.dim_date AS
SELECT
    d::date                                                     AS data,
    EXTRACT(YEAR    FROM d)::int                                AS ano,
    EXTRACT(QUARTER FROM d)::int                               AS trimestre,
    EXTRACT(MONTH   FROM d)::int                               AS mes,
    TO_CHAR(d, 'TMMonth')                                       AS nome_mes,
    EXTRACT(WEEK    FROM d)::int                               AS semana_ano,
    EXTRACT(DOW     FROM d)::int                               AS dia_semana,
    TO_CHAR(d, 'TMDay')                                         AS nome_dia_semana,
    EXTRACT(DAY     FROM d)::int                               AS dia,
    CASE WHEN EXTRACT(DOW FROM d) IN (0, 6) THEN TRUE
         ELSE FALSE END                                         AS fim_de_semana
FROM generate_series(
    (SELECT MIN(purchase_ts::date) FROM analytics.fact_orders),
    (SELECT MAX(purchase_ts::date) FROM analytics.fact_orders),
    '1 day'::interval
) AS d;

-- ------------------------------------------------------------
-- mart_logistics
-- Atributos conhecidos no momento da compra → BI de logística (flag_atraso)
-- purchase_date exposta para relacionamento com dim_date no Power BI
-- ------------------------------------------------------------
CREATE VIEW analytics.mart_logistics AS
SELECT
    order_id,
    customer_unique_id,
    purchase_ts::date   AS purchase_date,
    uf_cliente,
    uf_seller,
    distancia_km,
    categoria_principal,
    ano_compra,
    mes_compra,
    dia_semana_compra,
    prazo_prometido_dias,
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
-- Todos os atributos + flag_atraso → BI de satisfação (flag_review_ruim)
-- flag_atraso é permitida pois o review ocorre após a entrega
-- ------------------------------------------------------------
CREATE VIEW analytics.mart_customer_satisfaction AS
SELECT
    order_id,
    customer_unique_id,
    purchase_ts::date   AS purchase_date,
    uf_cliente,
    uf_seller,
    distancia_km,
    categoria_principal,
    mes_compra,
    dia_semana_compra,
    prazo_prometido_dias,
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
