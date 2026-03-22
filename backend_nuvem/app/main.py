import json

from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import Base, engine, get_db
from app.models import Pessoa, MqttEvento
from app.schemas import PessoaResponse, MqttEventoResponse, MqttIngestRequest

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


@app.post("/mqtt-ingest")
def mqtt_ingest(data: MqttIngestRequest, db: Session = Depends(get_db)):
    try:
        evento = MqttEvento(
            topic=data.topic,
            payload=json.dumps(data.payload, ensure_ascii=False)
        )

        db.add(evento)
        db.commit()
        db.refresh(evento)

        return {
            "status": "ok",
            "message": "Evento MQTT recebido com sucesso",
            "id": evento.id
        }

    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Erro ao salvar evento: {str(e)}")