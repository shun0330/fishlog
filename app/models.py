from datetime import date, datetime
from sqlalchemy import String, func
from sqlalchemy.orm import Mapped, mapped_column
from database import Base


class Catch(Base):
    __tablename__ = "catches"

    id: Mapped[int] = mapped_column(primary_key=True)
    fish: Mapped[str] = mapped_column(String(50))
    size_cm: Mapped[float | None]
    place: Mapped[str] = mapped_column(String(100))
    caught_on: Mapped[date]
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
