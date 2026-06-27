import os, sys
sys.path.insert(0, os.path.dirname(__file__))

from config import get_engine
from sqlalchemy import text

SQL_PATH = os.path.join(os.path.dirname(__file__), "..", "sql", "01_staging_views.sql")


def main():
    engine = get_engine()
    with open(SQL_PATH) as f:
        sql = f.read()

    # Remove linhas de comentário antes de dividir para evitar falsos splits em ';' dentro de comments
    sql_sem_comments = "\n".join(
        line for line in sql.splitlines() if not line.strip().startswith("--")
    )
    stmts = [s.strip() for s in sql_sem_comments.split(";") if s.strip()]

    with engine.begin() as conn:
        for stmt in stmts:
            conn.execute(text(stmt))

    print(f"✓ Staging: {len(stmts)} views criadas/atualizadas.")


if __name__ == "__main__":
    main()
