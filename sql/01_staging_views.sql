-- ============================================================
-- Staging Views — tipagem, padronização e deduplicação
-- Todas idempotentes via CREATE OR REPLACE
-- ============================================================

-- orders: cast de datas e padronização de status
CREATE OR REPLACE VIEW staging.orders AS
SELECT
    order_id,
    customer_id,
    lower(order_status)                         AS order_status,
    order_purchase_timestamp::timestamp         AS purchase_ts,
    order_approved_at::timestamp                AS approved_ts,
    order_delivered_carrier_date::timestamp     AS carrier_ts,
    order_delivered_customer_date::timestamp    AS delivered_ts,
    order_estimated_delivery_date::timestamp    AS estimated_ts
FROM raw.orders;

-- order_reviews: deduplicação — mantém o review mais recente por pedido
CREATE OR REPLACE VIEW staging.order_reviews AS
SELECT DISTINCT ON (order_id)
    order_id,
    review_score,
    review_creation_date::timestamp AS review_ts
FROM raw.order_reviews
ORDER BY order_id, review_creation_date DESC;

-- geolocation: agrega múltiplos registros por CEP (evita produto cartesiano no JOIN)
CREATE OR REPLACE VIEW staging.geolocation AS
SELECT
    geolocation_zip_code_prefix AS zip_prefix,
    avg(geolocation_lat)        AS lat,
    avg(geolocation_lng)        AS lng,
    max(geolocation_state)      AS uf
FROM raw.geolocation
GROUP BY geolocation_zip_code_prefix;

-- customers: padroniza cidade/UF e expõe customer_unique_id
CREATE OR REPLACE VIEW staging.customers AS
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix::text      AS zip_prefix,
    lower(trim(customer_city))          AS cidade_cliente,
    upper(trim(customer_state))         AS uf_cliente
FROM raw.customers;

-- sellers: padroniza cidade/UF
CREATE OR REPLACE VIEW staging.sellers AS
SELECT
    seller_id,
    seller_zip_code_prefix::text        AS zip_prefix,
    lower(trim(seller_city))            AS cidade_seller,
    upper(trim(seller_state))           AS uf_seller
FROM raw.sellers;

-- products: join com tradução de categoria + COALESCE para nulos
CREATE OR REPLACE VIEW staging.products AS
SELECT
    p.product_id,
    COALESCE(t.product_category_name_english, 'unknown') AS categoria_en,
    COALESCE(p.product_category_name, 'unknown')         AS categoria_pt,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM raw.products p
LEFT JOIN raw.category_translation t
       ON t.product_category_name = p.product_category_name;
