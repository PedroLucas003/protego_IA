from sqlalchemy import Column, Integer, String, Float, Boolean, Text
from app.database import Base


class Pessoa(Base):
    __tablename__ = "pessoas"

    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(String, nullable=False)
    nome = Column(String, nullable=False)
    cpf = Column(String, nullable=False, unique=True)
    rg = Column(String, nullable=False)
    nivel_perigo = Column(String, nullable=False)
    status = Column(String, nullable=False)
    mandados = Column(Text, nullable=False)
    crimes = Column(Text, nullable=False)
    artigos = Column(Text, nullable=False)
    observacoes = Column(Text, nullable=True)
    confianca = Column(Float, nullable=False)
    prova_de_vida = Column(Boolean, nullable=False)
    tem_mandado = Column(Boolean, nullable=False)