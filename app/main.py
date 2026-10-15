from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from database import Base, engine, get_db
import models
import schemas

Base.metadata.create_all(bind=engine)

app = FastAPI(title="釣果記録API")


@app.get("/")
def root():
    return {"message": "釣果記録アプリ"}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/catches", response_model=schemas.CatchRead, status_code=201)
def create_catch(payload: schemas.CatchCreate, db: Session = Depends(get_db)):
    catch = models.Catch(**payload.model_dump())
    db.add(catch)
    db.commit()
    db.refresh(catch)
    return catch


@app.get("/catches", response_model=list[schemas.CatchRead])
def list_catches(db: Session = Depends(get_db)):
    stmt = select(models.Catch).order_by(models.Catch.caught_on.desc())
    return db.scalars(stmt).all()


@app.get("/catches/{catch_id}", response_model=schemas.CatchRead)
def get_catch(catch_id: int, db: Session = Depends(get_db)):
    catch = db.get(models.Catch, catch_id)
    if catch is None:
        raise HTTPException(status_code=404, detail="Catch not found")
    return catch


@app.put("/catches/{catch_id}", response_model=schemas.CatchRead)
def update_catch(catch_id: int, payload: schemas.CatchCreate, db: Session = Depends(get_db)):
    catch = db.get(models.Catch, catch_id)
    if catch is None:
        raise HTTPException(status_code=404, detail="Catch not found")
    for key, value in payload.model_dump().items():
        setattr(catch, key, value)
    db.commit()
    db.refresh(catch)
    return catch


@app.delete("/catches/{catch_id}", status_code=204)
def delete_catch(catch_id: int, db: Session = Depends(get_db)):
    catch = db.get(models.Catch, catch_id)
    if catch is None:
        raise HTTPException(status_code=404, detail="Catch not found")
    db.delete(catch)
    db.commit()
