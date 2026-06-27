CREATE TABLE IF NOT EXISTS analytics.fact_orders AS
WITH itens AS (
    SELECT order_id,
           count(*)                AS qtd_itens,
           count(DISTINCT seller_id) AS qtd_sellers,
           sum(price)              AS valor_produtos,
           sum(freight_value)      AS frete_total
    FROM raw.order_items
    GROUP BY order_id
),
pag AS (
    SELECT order_id,
           sum(payment_value)      AS valor_pago,
           (array_agg(payment_installments ORDER BY payment_value DESC))[1] AS max_parcelas,
           (array_agg(payment_type       ORDER BY payment_value DESC))[1] AS tipo_pagamento
    FROM raw.order_payments
    GROUP BY order_id
)
SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_state               AS uf_cliente,
    o.purchase_ts,
    o.delivered_ts,
    o.estimated_ts,
    i.qtd_itens, i.qtd_sellers,
    i.valor_produtos, i.frete_total,
    p.valor_pago, p.max_parcelas, p.tipo_pagamento,
    r.review_score,
    -- métricas derivadas
    EXTRACT(EPOCH FROM (o.delivered_ts - o.purchase_ts))/86400.0 AS lead_time_dias,
    EXTRACT(EPOCH FROM (o.delivered_ts - o.estimated_ts))/86400.0 AS atraso_dias,
    CASE WHEN o.delivered_ts > o.estimated_ts THEN 1 ELSE 0 END   AS flag_atraso,
    CASE WHEN r.review_score IS NULL THEN NULL
         WHEN r.review_score <= 2 THEN 1 ELSE 0 END               AS flag_review_ruim  -- notas 1-2 = ruim; NULL = sem avaliação
FROM staging.orders o
JOIN raw.customers c ON c.customer_id = o.customer_id
LEFT JOIN itens i ON i.order_id = o.order_id
LEFT JOIN pag   p ON p.order_id = o.order_id
LEFT JOIN staging.order_reviews r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.delivered_ts IS NOT NULL;
