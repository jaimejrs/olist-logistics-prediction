import glob, os
import pandas as pd
from config import get_engine

NOME_TABELA = {
    "olist_orders_dataset": "orders",
    "olist_order_items_dataset": "order_items",
    "olist_order_payments_dataset": "order_payments",
    "olist_order_reviews_dataset": "order_reviews",
    "olist_customers_dataset": "customers",
    "olist_products_dataset": "products",
    "olist_sellers_dataset": "sellers",
    "olist_geolocation_dataset": "geolocation",
    "product_category_name_translation": "category_translation",
}

def main():
    engine = get_engine()
    for path in glob.glob("data/raw/*.csv"):
        base = os.path.basename(path).replace(".csv", "")
        tabela = NOME_TABELA.get(base)
        if not tabela:
            continue
        df = pd.read_csv(path)
        df.to_sql(tabela, engine, schema="raw",
                  if_exists="replace", index=False, chunksize=10_000, method="multi")
        print(f"raw.{tabela}: {len(df)} linhas")

if __name__ == "__main__":
    main()
