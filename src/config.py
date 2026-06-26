import os
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()

def get_engine():
    url = os.environ.get("DATABASE_URL")
    if not url:
        raise ValueError("DATABASE_URL não configurada no .env")
    return create_engine(url, pool_pre_ping=True)
