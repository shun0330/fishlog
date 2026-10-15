import os
from urllib.parse import quote_plus
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase


def build_database_url() -> str:
    url = os.getenv("DATABASE_URL")
    if url:
        return url
    user = os.environ["DB_USER"]
    password = quote_plus(os.environ["DB_PASSWORD"])
    host = os.environ["DB_HOST"]
    port = os.getenv("DB_PORT", "5432")
    name = os.environ["DB_NAME"]
    return f"postgresql+psycopg://{user}:{password}@{host}:{port}/{name}"


engine = create_engine(build_database_url(), pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
