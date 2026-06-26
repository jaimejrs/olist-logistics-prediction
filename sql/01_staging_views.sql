CREATE OR REPLACE VIEW staging.orders AS
SELECT
    order_id,
    customer_id,
    lower(order_status)                          AS order_status,
    order_purchase_timestamp::timestamp          AS purchase_ts,
    order_approved_at::timestamp                 AS approved_ts,
    order_delivered_carrier_date::timestamp      AS carrier_ts,
    order_delivered_customer_date::timestamp     AS delivered_ts,
    order_estimated_delivery_date::timestamp     AS estimated_ts
FROM raw.orders;

CREATE OR REPLACE VIEW staging.order_reviews AS
SELECT DISTINCT ON (order_id)
    order_id, review_score,
    review_creation_date::timestamp AS review_ts
FROM raw.order_reviews
ORDER BY order_id, review_creation_date DESC;

CREATE OR REPLACE VIEW staging.geolocation AS
SELECT geolocation_zip_code_prefix AS zip_prefix,
       avg(geolocation_lat) AS lat,
       avg(geolocation_lng) AS lng,
       max(geolocation_state) AS uf
FROM raw.geolocation
GROUP BY geolocation_zip_code_prefix;
