# ==============================================================================
#  POVOAR BANCO — Protego IA
#  Compatível com schema Railway do Guilherme
#  Colunas pessoas: id, nome, cpf, rg, nivel_perigo, status,
#                   mandados, crimes, artigos, observacoes,
#                   confianca, prova_de_vida, tem_mandado, timestamp
# ==============================================================================

import psycopg2
import json
from dotenv import load_dotenv
import os

load_dotenv()
DB_URL = os.getenv("DB_URL")

def get_conn():
    return psycopg2.connect(DB_URL)

# ==============================================================================
#  DADOS
# ==============================================================================

CAMERAS = [
    ("ESP32-CAM Bodycam 01", "Viatura Alpha - Recife/PE",     "192.168.1.91"),
    ("ESP32-CAM Bodycam 02", "Viatura Beta  - Recife/PE",     "192.168.1.92"),
    ("ESP32-CAM Bodycam 03", "Base Operacional - Caruaru/PE", "192.168.1.93"),
]

# (nome, cpf, rg, nivel_perigo, status, observacoes, mandados[], crimes[], artigos[])
PESSOAS = [
    (
        "CARLOS ALBERTO MENDES SILVA", "123.456.789-00", "1234567",
        "CRITICO", "FORAGIDO",
        "Lider de faccao. Foragido desde 03/2024. Extremamente perigoso.",
        ["PRISAO", "BUSCA"],
        ["Trafico de Drogas", "Homicidio Doloso", "Associacao Criminosa"],
        ["Art. 33 Lei 11.343/06", "Art. 121 par.2 CP", "Art. 288 CP"]
    ),
    (
        "RODRIGO FERREIRA SANTOS", "987.654.321-11", "7654321",
        "ALTO", "MONITORADO",
        "Integrante de organizacao de trafico. Usa disfarces frequentemente.",
        [],
        ["Trafico de Drogas", "Porte Ilegal de Arma"],
        ["Art. 33 Lei 11.343/06", "Art. 14 Lei 10.826/03"]
    ),
    (
        "MARCOS PAULO OLIVEIRA LIMA", "456.123.789-22", "4561237",
        "ALTO", "FORAGIDO",
        "Condenado por roubo qualificado. Nao cumpriu pena.",
        ["PRISAO"],
        ["Roubo Qualificado", "Receptacao"],
        ["Art. 157 par.2 CP", "Art. 180 CP"]
    ),
    (
        "ANA LUCIA BARBOSA COSTA", "321.654.987-33", "3216549",
        "MEDIO", "MONITORADO",
        "Investigada por lavagem de dinheiro. Usa Honda Civic prata.",
        [],
        ["Lavagem de Dinheiro"],
        ["Art. 1 Lei 9.613/98"]
    ),
    (
        "JOSIVALDO PEREIRA NASCIMENTO", "654.321.987-44", "6543219",
        "MEDIO", "ATIVO",
        "Reincidente. Passagens por furto. Usa nome falso Jose Carlos.",
        [],
        ["Furto", "Furto Qualificado", "Receptacao"],
        ["Art. 155 CP", "Art. 155 par.4 CP", "Art. 180 CP"]
    ),
    (
        "WELLINGTON SOUZA ARAUJO", "789.456.123-55", "7894561",
        "ALTO", "ATIVO",
        "Associado ao trafico de armas. Residencia no Bairro do Recife.",
        ["BUSCA", "APREENSAO"],
        ["Trafico de Armas", "Associacao Criminosa"],
        ["Art. 17 Lei 10.826/03", "Art. 288 CP"]
    ),
    (
        "FABIO HENRIQUE MELO TORRES", "111.222.333-66", "1112223",
        "BAIXO", "ATIVO",
        "Envolvido em brigas de bar. Agressivo sob efeito de alcool.",
        [],
        ["Lesao Corporal"],
        ["Art. 129 CP"]
    ),
    (
        "PAULO ROBERTO CAVALCANTE", "444.555.666-77", "4445556",
        "CRITICO", "PRESO",
        "Preso em 01/2025. Aguarda julgamento por homicidio qualificado.",
        [],
        ["Homicidio Qualificado", "Trafico de Drogas"],
        ["Art. 121 par.2 I e IV CP", "Art. 33 Lei 11.343/06"]
    ),
]

HISTORICO = [
    ("CARLOS ALBERTO MENDES SILVA", "Trafico de Drogas",    "Art. 33 Lei 11.343/06", "BO-2021-00123", "CONDENADO",   "Preso com 5kg de cocaina em 2021. Condenado a 8 anos."),
    ("CARLOS ALBERTO MENDES SILVA", "Associacao Criminosa", "Art. 288 CP",            "BO-2022-00456", "INDICIADO",   "Lideranca de organizacao criminosa."),
    ("CARLOS ALBERTO MENDES SILVA", "Homicidio Doloso",     "Art. 121 par.2 CP",      "BO-2023-00789", "INVESTIGADO", "Suspeito de ordenar execucao. Inquerito em andamento."),
    ("RODRIGO FERREIRA SANTOS",     "Trafico de Drogas",    "Art. 33 Lei 11.343/06", "BO-2022-00321", "CONDENADO",   "Flagrado com 2kg de maconha e 500g de crack."),
    ("RODRIGO FERREIRA SANTOS",     "Porte Ilegal de Arma", "Art. 14 Lei 10.826/03", "BO-2022-00322", "CONDENADO",   "Pistola .40 sem registro."),
    ("MARCOS PAULO OLIVEIRA LIMA",  "Roubo Qualificado",    "Art. 157 par.2 CP",      "BO-2020-00654", "CONDENADO",   "Roubo a mao armada de estabelecimento comercial."),
    ("MARCOS PAULO OLIVEIRA LIMA",  "Receptacao",           "Art. 180 CP",            "BO-2019-00111", "CONDENADO",   "Venda de eletronicos roubados."),
    ("ANA LUCIA BARBOSA COSTA",     "Lavagem de Dinheiro",  "Art. 1 Lei 9.613/98",   "BO-2023-00888", "INVESTIGADO", "Movimentacao suspeita de R$2 milhoes."),
    ("JOSIVALDO PEREIRA NASCIMENTO","Furto",                 "Art. 155 CP",            "BO-2018-00200", "CONDENADO",   "Furto em supermercado."),
    ("JOSIVALDO PEREIRA NASCIMENTO","Furto Qualificado",     "Art. 155 par.4 CP",      "BO-2020-00300", "CONDENADO",   "Furto com arrombamento."),
    ("WELLINGTON SOUZA ARAUJO",     "Trafico de Armas",     "Art. 17 Lei 10.826/03", "BO-2023-00555", "INDICIADO",   "Carregamento com 15 armas ilegais."),
    ("WELLINGTON SOUZA ARAUJO",     "Associacao Criminosa", "Art. 288 CP",            "BO-2023-00556", "INDICIADO",   "Intermediario de faccao armada."),
    ("FABIO HENRIQUE MELO TORRES",  "Lesao Corporal",       "Art. 129 CP",            "BO-2022-00050", "CONDENADO",   "Agressao em briga de bar."),
    ("PAULO ROBERTO CAVALCANTE",    "Homicidio Qualificado","Art. 121 par.2 I e IV",  "BO-2024-00010", "INDICIADO",   "Dois homicidios por motivo torpe."),
    ("PAULO ROBERTO CAVALCANTE",    "Trafico de Drogas",    "Art. 33 Lei 11.343/06", "BO-2023-00900", "CONDENADO",   "Condenado a 6 anos em 2023."),
]

MANDADOS = [
    ("CARLOS ALBERTO MENDES SILVA", "PRISAO",    "MPR-2024-0001", "3a Vara Criminal de Recife",  "Mandado de prisao preventiva por homicidio."),
    ("CARLOS ALBERTO MENDES SILVA", "BUSCA",     "MPR-2024-0002", "3a Vara Criminal de Recife",  "Busca e apreensao na Rua das Flores, 123."),
    ("MARCOS PAULO OLIVEIRA LIMA",  "PRISAO",    "MPR-2023-0045", "1a Vara de Execucoes Penais", "Nao compareceu para inicio do cumprimento de pena."),
    ("WELLINGTON SOUZA ARAUJO",     "BUSCA",     "MPR-2024-0078", "2a Vara Criminal de Recife",  "Busca e apreensao por suspeita de arsenal."),
    ("WELLINGTON SOUZA ARAUJO",     "APREENSAO", "MPR-2024-0079", "2a Vara Criminal de Recife",  "Apreensao de veiculos ligados ao trafico."),
]

# ==============================================================================
#  INSERÇÃO
# ==============================================================================
def povoar():
    print("=" * 60)
    print("  POPULANDO BANCO — Protego IA")
    print("=" * 60)

    conn = get_conn()
    cur  = conn.cursor()

    # ── Câmeras ──────────────────────────────────────────────
    print("\n📷  Inserindo câmeras...")
    for nome, local, ip in CAMERAS:
        cur.execute("SELECT id FROM cameras WHERE ip = %s", (ip,))
        if cur.fetchone():
            print(f"   ⚠️  {ip} já existe.")
            continue
        cur.execute("""
            INSERT INTO cameras (nome, localizacao, ip, ativa)
            VALUES (%s, %s, %s, TRUE)
        """, (nome, local, ip))
        print(f"   ✅  {nome}")

    # ── Pessoas ───────────────────────────────────────────────
    print("\n👤  Inserindo pessoas...")
    pessoa_ids = {}
    for (nome, cpf, rg, perigo, status, obs, mandados, crimes, artigos) in PESSOAS:
        cur.execute("SELECT id FROM pessoas WHERE nome = %s", (nome,))
        existing = cur.fetchone()
        if existing:
            pessoa_ids[nome] = existing[0]
            print(f"   ⚠️  {nome} já existe.")
            continue
        cur.execute("""
            INSERT INTO pessoas
                (nome, cpf, rg, nivel_perigo, status, observacoes,
                 mandados, crimes, artigos,
                 confianca, prova_de_vida, tem_mandado, timestamp)
            VALUES (%s, %s, %s, %s, %s, %s,
                    %s::jsonb, %s::jsonb, %s::jsonb,
                    %s, %s, %s, NOW())
            RETURNING id
        """, (
            nome, cpf, rg, perigo, status, obs,
            json.dumps(mandados),
            json.dumps(crimes),
            json.dumps(artigos),
            0.0,
            False,
            len(mandados) > 0
        ))
        pid = cur.fetchone()[0]
        pessoa_ids[nome] = pid
        print(f"   ✅  {nome} | {perigo} | {status}")

    # ── Histórico Criminal ────────────────────────────────────
    print("\n⚖️   Inserindo histórico criminal...")
    for (nome, crime, artigo, bo, situacao, desc) in HISTORICO:
        pid = pessoa_ids.get(nome)
        if not pid:
            print(f"   ⚠️  Pessoa não encontrada: {nome}")
            continue
        cur.execute("SELECT id FROM historico_criminal WHERE numero_bo = %s", (bo,))
        if cur.fetchone():
            print(f"   ⚠️  BO {bo} já existe.")
            continue
        cur.execute("""
            INSERT INTO historico_criminal
                (pessoa_id, tipo_crime, artigo_lei, numero_bo, situacao, descricao)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (pid, crime, artigo, bo, situacao, desc))
        print(f"   ✅  {nome[:35]:35s} | {crime}")

    # ── Mandados ──────────────────────────────────────────────
    print("\n📋  Inserindo mandados...")
    for (nome, tipo, numero, vara, desc) in MANDADOS:
        pid = pessoa_ids.get(nome)
        if not pid:
            print(f"   ⚠️  Pessoa não encontrada: {nome}")
            continue
        cur.execute("SELECT id FROM mandados WHERE numero_mandado = %s", (numero,))
        if cur.fetchone():
            print(f"   ⚠️  Mandado {numero} já existe.")
            continue
        cur.execute("""
            INSERT INTO mandados
                (pessoa_id, tipo, numero_mandado, vara_judicial, ativo, descricao)
            VALUES (%s, %s, %s, %s, TRUE, %s)
        """, (pid, tipo, numero, vara, desc))
        print(f"   ✅  {nome[:35]:35s} | {tipo}")

    conn.commit()
    cur.close()
    conn.close()

    print("\n" + "=" * 60)
    print("  BANCO POPULADO COM SUCESSO!")
    print("=" * 60)
    print(f"  Câmeras  : {len(CAMERAS)}")
    print(f"  Pessoas  : {len(PESSOAS)}")
    print(f"  Histórico: {len(HISTORICO)} registros")
    print(f"  Mandados : {len(MANDADOS)} mandados ativos")
    print()
    print("  ⚠️  Rode cadastrar_alvo.py para adicionar fotos reais.")
    print("=" * 60)

if __name__ == "__main__":
    povoar()