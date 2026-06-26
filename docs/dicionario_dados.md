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
