-- ============================================================
-- Business Queries — Olist Logistics Prediction
-- Fonte: analytics.fact_orders (96k pedidos entregues, 2017-2018)
-- ============================================================

-- Q1: Taxa de atraso por estado do cliente
-- Insight: identifica regiões com maior risco logístico
SELECT uf_cliente,
       COUNT(*)                                    AS pedidos,
       ROUND(AVG(flag_atraso) * 100, 2)           AS taxa_atraso_pct,
       ROUND(AVG(lead_time_dias)::numeric, 1)      AS lead_time_medio_dias
FROM analytics.fact_orders
GROUP BY uf_cliente
ORDER BY taxa_atraso_pct DESC;


-- Q2: Nota média e taxa de review ruim por situação de entrega
-- Insight: quantifica o impacto do atraso na satisfação (valida H1)
SELECT
    CASE WHEN flag_atraso = 1 THEN 'Atrasado' ELSE 'No prazo' END AS situacao,
    COUNT(*)                                        AS pedidos,
    ROUND(AVG(review_score)::numeric, 2)            AS nota_media,
    ROUND(AVG(flag_review_ruim::float) * 100, 2)   AS taxa_review_ruim_pct
FROM analytics.fact_orders
WHERE review_score IS NOT NULL
GROUP BY flag_atraso
ORDER BY flag_atraso DESC;


-- Q3: Ticket médio, frete médio e lead time médio por mês
-- Insight: sazonalidade do marketplace e comportamento logístico
SELECT
    DATE_TRUNC('month', purchase_ts)               AS mes,
    COUNT(*)                                        AS pedidos,
    ROUND(AVG(valor_pago)::numeric, 2)             AS ticket_medio,
    ROUND(AVG(frete_total)::numeric, 2)            AS frete_medio,
    ROUND(AVG(lead_time_dias)::numeric, 1)          AS lead_time_medio_dias,
    ROUND(AVG(flag_atraso) * 100, 2)               AS taxa_atraso_pct
FROM analytics.fact_orders
GROUP BY 1
ORDER BY 1;


-- Q4: Top 15 categorias por volume e taxa de atraso
-- Insight: categorias problemáticas para logística (peso/volume alto = mais atraso?)
SELECT
    categoria_principal,
    COUNT(*)                                        AS pedidos,
    ROUND(AVG(flag_atraso) * 100, 2)               AS taxa_atraso_pct,
    ROUND(AVG(lead_time_dias)::numeric, 1)          AS lead_time_medio,
    ROUND(AVG(frete_total)::numeric, 2)             AS frete_medio,
    ROUND(AVG(review_score)::numeric, 2)            AS nota_media
FROM analytics.fact_orders
GROUP BY categoria_principal
HAVING COUNT(*) > 200
ORDER BY taxa_atraso_pct DESC
LIMIT 15;


-- Q5: Taxa de atraso e lead time médio por estado do vendedor (uf_seller)
-- Insight: identifica origens logísticas problemáticas
SELECT
    uf_seller,
    COUNT(*)                                        AS pedidos,
    ROUND(AVG(flag_atraso) * 100, 2)               AS taxa_atraso_pct,
    ROUND(AVG(lead_time_dias)::numeric, 1)          AS lead_time_medio_dias,
    ROUND(AVG(frete_total)::numeric, 2)             AS frete_medio
FROM analytics.fact_orders
WHERE uf_seller IS NOT NULL
GROUP BY uf_seller
HAVING COUNT(*) > 100
ORDER BY taxa_atraso_pct DESC;


-- Q6: Perfil comparativo entre pedidos atrasados e no prazo
-- Insight: features que diferem entre grupos — insumo direto para o modelo de ML
SELECT
    CASE WHEN flag_atraso = 1 THEN 'Atrasado' ELSE 'No prazo' END AS grupo,
    COUNT(*)                                        AS pedidos,
    ROUND(AVG(valor_pago)::numeric, 2)             AS ticket_medio,
    ROUND(AVG(frete_total)::numeric, 2)            AS frete_medio,
    ROUND(AVG(qtd_itens)::numeric, 2)              AS itens_medio,
    ROUND(AVG(peso_total_g)::numeric, 0)           AS peso_medio_g,
    ROUND(AVG(max_parcelas)::numeric, 1)           AS parcelas_media,
    ROUND(AVG(lead_time_dias)::numeric, 1)          AS lead_time_medio
FROM analytics.fact_orders
GROUP BY flag_atraso
ORDER BY flag_atraso;


-- Q7: Distribuição de pedidos por dia da semana e taxa de atraso
-- Insight: pedidos feitos no fim de semana têm mais atraso? (feature temporal)
SELECT
    CASE dia_semana_compra
        WHEN 0 THEN '0-Dom' WHEN 1 THEN '1-Seg' WHEN 2 THEN '2-Ter'
        WHEN 3 THEN '3-Qua' WHEN 4 THEN '4-Qui' WHEN 5 THEN '5-Sex'
        WHEN 6 THEN '6-Sáb'
    END                                             AS dia_semana,
    COUNT(*)                                        AS pedidos,
    ROUND(AVG(flag_atraso) * 100, 2)               AS taxa_atraso_pct
FROM analytics.fact_orders
GROUP BY dia_semana_compra
ORDER BY dia_semana_compra;


-- Q8: Análise por tipo de pagamento
-- Insight: perfil de compra e satisfação por modalidade
SELECT
    tipo_pagamento,
    COUNT(*)                                                    AS pedidos,
    ROUND(AVG(valor_pago)::numeric, 2)                         AS ticket_medio,
    ROUND(AVG(max_parcelas)::numeric, 1)                       AS parcelas_media,
    ROUND(AVG(flag_atraso) * 100, 2)                           AS taxa_atraso_pct,
    ROUND(AVG(flag_review_ruim::float) * 100, 2)               AS taxa_review_ruim_pct
FROM analytics.fact_orders
WHERE tipo_pagamento IS NOT NULL
GROUP BY tipo_pagamento
ORDER BY pedidos DESC;


-- Q9: Faixas de atraso e impacto na nota
-- Insight: a nota cai linearmente com o atraso ou há um efeito-limiar?
SELECT
    CASE
        WHEN atraso_dias <= -15 THEN '1. Muito adiantado (> 15d antes)'
        WHEN atraso_dias <= -7  THEN '2. Adiantado (8-15d antes)'
        WHEN atraso_dias <= -1  THEN '3. Levemente adiantado (2-7d antes)'
        WHEN atraso_dias <= 0   THEN '4. No prazo (0-1d antes)'
        WHEN atraso_dias <= 7   THEN '5. Atrasado até 7 dias'
        WHEN atraso_dias <= 15  THEN '6. Atrasado 8-15 dias'
        ELSE                         '7. Muito atrasado (> 15 dias)'
    END                                             AS faixa_atraso,
    COUNT(*)                                        AS pedidos,
    ROUND(AVG(review_score)::numeric, 2)            AS nota_media,
    ROUND(AVG(flag_review_ruim::float) * 100, 2)   AS taxa_review_ruim_pct
FROM analytics.fact_orders
WHERE review_score IS NOT NULL
GROUP BY faixa_atraso
ORDER BY faixa_atraso;


-- Q10: Top 10 rotas (UF seller → UF cliente) por volume e atraso
-- Insight: rotas críticas para intervenção logística
SELECT
    uf_seller || ' → ' || uf_cliente                AS rota,
    COUNT(*)                                         AS pedidos,
    ROUND(AVG(flag_atraso) * 100, 2)                AS taxa_atraso_pct,
    ROUND(AVG(lead_time_dias)::numeric, 1)           AS lead_time_medio,
    ROUND(AVG(frete_total)::numeric, 2)              AS frete_medio
FROM analytics.fact_orders
WHERE uf_seller IS NOT NULL
GROUP BY uf_seller, uf_cliente
HAVING COUNT(*) > 300
ORDER BY pedidos DESC
LIMIT 10;


-- Q11: Evolução trimestral das métricas-chave
-- Insight: o marketplace melhorou ou piorou ao longo do tempo?
SELECT
    DATE_TRUNC('quarter', purchase_ts)              AS trimestre,
    COUNT(*)                                        AS pedidos,
    ROUND(AVG(flag_atraso) * 100, 2)               AS taxa_atraso_pct,
    ROUND(AVG(review_score)::numeric, 2)            AS nota_media,
    ROUND(AVG(lead_time_dias)::numeric, 1)          AS lead_time_medio,
    ROUND(AVG(valor_pago)::numeric, 2)             AS ticket_medio
FROM analytics.fact_orders
GROUP BY 1
ORDER BY 1;


-- Q12: Pedidos com múltiplos vendedores — são mais propensos a atraso?
-- Insight: coordenação multi-seller pode ser um fator de risco
SELECT
    CASE
        WHEN qtd_sellers = 1 THEN '1 seller'
        WHEN qtd_sellers = 2 THEN '2 sellers'
        ELSE '3+ sellers'
    END                                             AS perfil_seller,
    COUNT(*)                                        AS pedidos,
    ROUND(AVG(flag_atraso) * 100, 2)               AS taxa_atraso_pct,
    ROUND(AVG(lead_time_dias)::numeric, 1)          AS lead_time_medio,
    ROUND(AVG(review_score)::numeric, 2)            AS nota_media
FROM analytics.fact_orders
GROUP BY perfil_seller
ORDER BY perfil_seller;
