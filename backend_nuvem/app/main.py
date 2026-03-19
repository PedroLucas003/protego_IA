from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import Base, engine, get_db
from app.models import Pessoa, MqttEvento
from app.schemas import PessoaResponse, MqttEventoResponse

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Protego IA API")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/pessoas", response_model=list[PessoaResponse])
def listar_pessoas(db: Session = Depends(get_db)):
    return db.query(Pessoa).all()


@app.get("/pessoas/{pessoa_id}", response_model=PessoaResponse)
def buscar_pessoa(pessoa_id: int, db: Session = Depends(get_db)):
    pessoa = db.query(Pessoa).filter(Pessoa.id == pessoa_id).first()
    if not pessoa:
        raise HTTPException(status_code=404, detail="Pessoa não encontrada")
    return pessoa


@app.get("/mqtt-eventos", response_model=list[MqttEventoResponse])
def listar_eventos(db: Session = Depends(get_db)):
    return db.query(MqttEvento).order_by(MqttEvento.id.desc()).all()