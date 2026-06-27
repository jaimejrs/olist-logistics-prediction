import os, sys
sys.path.insert(0, os.path.dirname(__file__))

from config import get_engine
from sqlalchemy import text

SQL_PATH = os.path.join(os.path.dirname(__file__), "..", "sql", "02_analytics_ddl.sql")


def _quality_checks(conn):
    checks = [
        ("Grão único (order_id)",
         "SELECT COUNT(*) = COUNT(DISTINCT order_id) FROM analytics.fact_orders"),
        ("flag_atraso só 0 ou 1",
         "SELECT bool_and(flag_atraso IN (0, 1)) FROM analytics.fact_orders"),
        ("lead_time_dias >= 0 em >99% dos pedidos",
         "SELECT avg(CASE WHEN lead_time_dias >= 0 THEN 1.0 ELSE 0.0 END) >= 0.99 FROM analytics.fact_orders"),
        ("Sem order_id nulo",
         "SELECT COUNT(*) = 0 FROM analytics.fact_orders WHERE order_id IS NULL"),
    ]
    all_ok = True
    for descricao, query in checks:
        resultado = conn.execute(text(query)).scalar()
        status = "✓" if resultado else "✗"
        print(f"  {status} {descricao}")
        if not resultado:
            all_ok = False
    return all_ok


def main():
    engine = get_engine()
    with open(SQL_PATH) as f:
        sql = f.read()

    sql_sem_comments = "\n".join(
        line for line in sql.splitlines() if not line.strip().startswith("--")
    )
    stmts = [s.strip() for s in sql_sem_comments.split(";") if s.strip()]

    print("  Executando DDL...")
    with engine.begin() as conn:
        for stmt in stmts:
            conn.execute(text(stmt))

    print("  Verificando qualidade dos dados...")
    with engine.connect() as conn:
        total = conn.execute(text("SELECT COUNT(*) FROM analytics.fact_orders")).scalar()
        print(f"  fact_orders: {total:,} pedidos")
        ok = _quality_checks(conn)

    if not ok:
        raise RuntimeError("Data quality checks falharam — verifique os dados.")

    print("✓ Analytics: fact_orders, mart_logistics e mart_customer_satisfaction prontos.")


if __name__ == "__main__":
    main()
