-- Taxa de atraso por estado
SELECT uf_cliente,
       round(avg(flag_atraso)*100, 2) AS taxa_atraso_pct,
       count(*) AS pedidos
FROM analytics.fact_orders
GROUP BY uf_cliente
ORDER BY taxa_atraso_pct DESC;

-- Nota média por faixa de atraso
SELECT CASE WHEN flag_atraso=1 THEN 'Atrasado' ELSE 'No prazo' END AS situacao,
       round(avg(review_score), 2) AS nota_media,
       count(*) AS pedidos
FROM analytics.fact_orders
WHERE review_score IS NOT NULL
GROUP BY 1;

-- Ticket médio e frete médio por mês
SELECT date_trunc('month', purchase_ts) AS mes,
       round(avg(valor_pago),2) AS ticket_medio,
       round(avg(frete_total),2) AS frete_medio
FROM analytics.fact_orders
GROUP BY 1 ORDER BY 1;
