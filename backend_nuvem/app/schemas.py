from pydantic import BaseModel


class PessoaBase(BaseModel):
    timestamp: str
    nome: str
    cpf: str
    rg: str
    nivel_perigo: str
    status: str
    mandados: str
    crimes: str
    artigos: str
    observacoes: str | None = None
    confianca: float
    prova_de_vida: bool
    tem_mandado: bool


class PessoaResponse(PessoaBase):
    id: int

    class Config:
        from_attributes = True