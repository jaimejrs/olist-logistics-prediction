"""
Orquestrador do pipeline ETL completo:
  Raw (CSV) → Staging (views) → Analytics (fact + marts)

Uso:
  cd <raiz do projeto>
  python src/run_etl.py
"""
import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))

import ingest_raw
import build_staging
import build_analytics


def main():
    t0 = time.time()
    print("=" * 52)
    print("  ETL — Olist Logistics Prediction")
    print("=" * 52)

    print("\n[1/3] Ingestão Raw (CSV → banco)...")
    ingest_raw.main()

    print("\n[2/3] Construindo Staging (views)...")
    build_staging.main()

    print("\n[3/3] Construindo Analytics (fact + marts)...")
    build_analytics.main()

    elapsed = time.time() - t0
    print(f"\n{'='*52}")
    print(f"  Pipeline concluído em {elapsed:.1f}s")
    print("=" * 52)


if __name__ == "__main__":
    main()
