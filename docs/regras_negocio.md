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
- **Desduplicação de Reviews:** Ocasionalmente, o mesmo pedido possui mais de um review (avaliações feitas ou alteradas em datas distintas). A regra é utilizar o `DISTINCT ON (order_id)` capturando apenas a **avaliação mais recente**.
- **Desduplicação de Geolocation:** O dataset de geolocalização possui múltiplas coordenadas cadastradas sob o mesmo prefixo de CEP. Para evitar problemas no JOIN (produto cartesiano), agregamos a tabela por `zip_code_prefix`, calculando a média (AVG) de latitude e longitude.

## 4. Prevenção de "Data Leakage" (Vazamento de Dados)
Ao desenvolver o **Modelo 1 (Predição de Atraso)**, utilizaremos a perspectiva de tempo do "momento da compra". 
- **É proibido** o uso de variáveis que só passam a existir *após* a compra ou o despacho (ex.: `order_delivered_carrier_date`, `lead_time_dias` ou `atraso_dias`) no processo de treinamento e inferência do modelo de atraso.
- O modelo deverá ser alimentado apenas com os dados que o sistema Olist já possuiria no exato instante em que o cliente aperta o botão "Comprar" (UF de origem, UF de destino, peso, dimensões, valor do frete, preço do produto, categoria, dia da semana da compra, etc.).
