from datetime import date, datetime
from pydantic import BaseModel, Field, ConfigDict


class CatchCreate(BaseModel):
    fish: str = Field(min_length=1, max_length=50)
    size_cm: float | None = Field(default=None, gt=0, lt=500)
    place: str = Field(min_length=1, max_length=100)
    caught_on: date


class CatchRead(CatchCreate):
    model_config = ConfigDict(from_attributes=True)
    id: int
    created_at: datetime
