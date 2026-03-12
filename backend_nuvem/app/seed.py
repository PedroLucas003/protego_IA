from app.database import SessionLocal, engine, Base
from app.models import Pessoa

Base.metadata.create_all(bind=engine)

db = SessionLocal()

existe = db.query(Pessoa).first()
if not existe:
    pessoa = Pessoa(
        timestamp="2026-03-12T14:32:00",
        nome="JOAO SILVA",
        cpf="111.111.111-11",
        rg="1234567",
        nivel_perigo="ALTO",
        status="FORAGIDO",
        mandados="PRISAO",
        crimes="Trafico de Drogas",
        artigos="Art. 33 Lei 11.343/06",
        observacoes="Preso em flagrante em 2023",
        confianca=92.5,
        prova_de_vida=True,
        tem_mandado=True,
    )
    db.add(pessoa)
    db.commit()
    print("Seed inserida com sucesso.")
else:
    print("Banco já possui dados.")

db.close()