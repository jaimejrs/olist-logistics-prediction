"""
Constrói as dimensões do star schema no schema analytics (Neon):
  - dim_geografia  (uf, nome_estado, regiao, lat, lng)
  - dim_categoria  (categoria_principal, segmento)
  - dim_pagamento  (tipo_pagamento, descricao)
  - dim_cliente    (customer_unique_id, n_pedidos, recorrente)

Uso:  python src/build_dimensions.py
"""
import os, sys, time
sys.path.insert(0, os.path.dirname(__file__))
import pandas as pd
from sqlalchemy import text
from config import get_engine

UF_INFO = {
    "AC": ("Acre", "Norte", -9.02, -70.81), "AL": ("Alagoas", "Nordeste", -9.57, -36.55),
    "AP": ("Amapá", "Norte", 1.41, -51.77), "AM": ("Amazonas", "Norte", -3.97, -62.00),
    "BA": ("Bahia", "Nordeste", -12.96, -41.70), "CE": ("Ceará", "Nordeste", -5.20, -39.53),
    "DF": ("Distrito Federal", "Centro-Oeste", -15.78, -47.93), "ES": ("Espírito Santo", "Sudeste", -19.19, -40.34),
    "GO": ("Goiás", "Centro-Oeste", -15.98, -49.86), "MA": ("Maranhão", "Nordeste", -5.42, -45.44),
    "MT": ("Mato Grosso", "Centro-Oeste", -12.64, -55.42), "MS": ("Mato Grosso do Sul", "Centro-Oeste", -20.51, -54.54),
    "MG": ("Minas Gerais", "Sudeste", -18.10, -44.38), "PA": ("Pará", "Norte", -3.79, -52.48),
    "PB": ("Paraíba", "Nordeste", -7.28, -36.72), "PR": ("Paraná", "Sul", -24.89, -51.55),
    "PE": ("Pernambuco", "Nordeste", -8.38, -37.86), "PI": ("Piauí", "Nordeste", -6.60, -42.28),
    "RJ": ("Rio de Janeiro", "Sudeste", -22.25, -42.66), "RN": ("Rio Grande do Norte", "Nordeste", -5.81, -36.59),
    "RS": ("Rio Grande do Sul", "Sul", -30.17, -53.50), "RO": ("Rondônia", "Norte", -10.83, -63.34),
    "RR": ("Roraima", "Norte", 1.99, -61.33), "SC": ("Santa Catarina", "Sul", -27.45, -50.95),
    "SP": ("São Paulo", "Sudeste", -22.19, -48.79), "SE": ("Sergipe", "Nordeste", -10.57, -37.45),
    "TO": ("Tocantins", "Norte", -9.46, -48.26),
}

PAG_DESC = {"credit_card": "Cartão de crédito", "boleto": "Boleto", "voucher": "Voucher",
            "debit_card": "Cartão de débito", "not_defined": "Não definido"}

SEG_KEYWORDS = [
    ("Casa & Móveis", ["furniture", "bed_bath", "home", "house", "kitchen", "garden", "office_furn", "moveis", "decor", "construction_tools_garden"]),
    ("Eletrônicos & Tech", ["electronics", "computer", "telephony", "tablet", "pc", "audio", "tv", "console", "games", "informatica", "tech"]),
    ("Moda & Beleza", ["fashion", "health_beauty", "perfum", "watches", "luggage", "shoes", "bags"]),
    ("Lazer & Cultura", ["sports", "leisure", "toys", "books", "cds", "music", "art", "cine", "party"]),
    ("Alimentos & Bebidas", ["food", "drink"]),
    ("Bebês & Infantil", ["baby", "diaper"]),
    ("Ferramentas & Construção", ["construction", "tools", "industry", "industria"]),
]


def segmento(cat):
    c = (cat or "").lower()
    for nome, kws in SEG_KEYWORDS:
        if any(k in c for k in kws):
            return nome
    return "Outros"


def main():
    t0 = time.time()
    e = get_engine()
    print("Lendo distintos de fact_orders...")
    ufs = pd.read_sql("""
        SELECT uf FROM (
          SELECT uf_cliente AS uf FROM analytics.fact_orders WHERE uf_cliente IS NOT NULL
          UNION SELECT uf_seller FROM analytics.fact_orders WHERE uf_seller IS NOT NULL
        ) t GROUP BY uf""", e)["uf"].tolist()
    dim_geo = pd.DataFrame([{
        "uf": u, "nome_estado": UF_INFO.get(u, (u, "Outros", None, None))[0],
        "regiao": UF_INFO.get(u, (u, "Outros", None, None))[1],
        "lat": UF_INFO.get(u, (u, "Outros", None, None))[2],
        "lng": UF_INFO.get(u, (u, "Outros", None, None))[3],
    } for u in ufs])

    cats = pd.read_sql("SELECT DISTINCT categoria_principal FROM analytics.fact_orders WHERE categoria_principal IS NOT NULL", e)
    cats["segmento"] = cats["categoria_principal"].map(segmento)
    dim_cat = cats.sort_values("categoria_principal").reset_index(drop=True)

    pags = pd.read_sql("SELECT DISTINCT tipo_pagamento FROM analytics.fact_orders WHERE tipo_pagamento IS NOT NULL", e)
    pags["descricao"] = pags["tipo_pagamento"].map(lambda x: PAG_DESC.get(x, x))
    dim_pag = pags

    dim_cli = pd.read_sql("""
        SELECT customer_unique_id,
               COUNT(*)                              AS n_pedidos,
               MAX(flag_atraso)                      AS teve_atraso,
               ROUND(AVG(review_score)::numeric, 2)  AS nota_media,
               ROUND(SUM(valor_pago)::numeric, 2)    AS valor_total
        FROM analytics.fact_orders
        GROUP BY customer_unique_id""", e)
    dim_cli["recorrente"] = (dim_cli["n_pedidos"] >= 2).astype(int)

    print(f"  dim_geografia={len(dim_geo)} | dim_categoria={len(dim_cat)} "
          f"| dim_pagamento={len(dim_pag)} | dim_cliente={len(dim_cli):,}")

    print("Gravando dimensões...")
    for nome, df in [("dim_geografia", dim_geo), ("dim_categoria", dim_cat),
                     ("dim_pagamento", dim_pag), ("dim_cliente", dim_cli)]:
        with e.begin() as c:
            c.execute(text(f"DROP TABLE IF EXISTS analytics.{nome} CASCADE"))
        df.to_sql(nome, e, schema="analytics", if_exists="replace", index=False,
                  chunksize=10_000, method="multi")
        print(f"  analytics.{nome}: {len(df):,} linhas")

    seg_counts = dim_cat["segmento"].value_counts().to_dict()
    print("Segmentos:", seg_counts)
    print(f"Recorrentes: {dim_cli['recorrente'].sum():,} de {len(dim_cli):,} clientes "
          f"({dim_cli['recorrente'].mean()*100:.1f}%)")
    print(f"Concluído em {time.time()-t0:.1f}s")


if __name__ == "__main__":
    main()
