import os
import json
import psycopg2
from dotenv import load_dotenv

load_dotenv()
DB_URL = os.getenv("DB_URL")

def conectar():
    try:
        conn = psycopg2.connect(DB_URL)
        print("✅  Conectado ao PostgreSQL com sucesso!")
        return conn
    except Exception as e:
        print(f"❌  Erro ao conectar: {e}")
        return None

def testar_insert(conn):
    print("\n🔄  Inserindo pessoa de teste...")
    cur = conn.cursor()

    # Encoding falso só para testar (128 zeros)
    encoding_fake = [0.0] * 128

    cur.execute("""
        INSERT INTO pessoas (nome_completo, cpf, rg, nivel_perigo, status, observacoes, encoding)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (cpf) DO NOTHING
        RETURNING id, nome_completo
    """, (
        "João Silva Teste",
        "111.111.111-11",
        "1234567",
        "ALTO",
        "FORAGIDO",
        "Pessoa de teste inserida pelo script Python",
        json.dumps(encoding_fake)
    ))

    resultado = cur.fetchone()
    if resultado:
        print(f"✅  Pessoa inserida! ID: {resultado[0]} | Nome: {resultado[1]}")
        pessoa_id = resultado[0]
    else:
        print("⚠️  CPF já existe, buscando ID existente...")
        cur.execute("SELECT id FROM pessoas WHERE cpf = %s", ("111.111.111-11",))
        pessoa_id = cur.fetchone()[0]

    # Insere histórico criminal
    cur.execute("""
        INSERT INTO historico_criminal (pessoa_id, tipo_crime, artigo_lei, situacao, descricao)
        VALUES (%s, %s, %s, %s, %s)
    """, (
        pessoa_id,
        "Tráfico de Drogas",
        "Art. 33 Lei 11.343/06",
        "CONDENADO",
        "Preso em flagrante com 2kg de cocaína"
    ))
    print("✅  Histórico criminal inserido!")

    # Insere mandado
    cur.execute("""
        INSERT INTO mandados (pessoa_id, tipo, numero_mandado, vara_judicial, ativo, descricao)
        VALUES (%s, %s, %s, %s, %s, %s)
        ON CONFLICT (numero_mandado) DO NOTHING
    """, (
        pessoa_id,
        "PRISAO",
        "MAND-2024-00123",
        "2ª Vara Criminal",
        True,
        "Mandado de prisão preventiva"
    ))
    print("✅  Mandado inserido!")

    conn.commit()
    cur.close()
    return pessoa_id

def testar_select(conn):
    print("\n🔄  Buscando dados inseridos...")
    cur = conn.cursor()

    cur.execute("""
        SELECT
            p.nome_completo,
            p.cpf,
            p.nivel_perigo,
            p.status,
            h.tipo_crime,
            h.situacao,
            m.tipo as mandado_tipo,
            m.ativo
        FROM pessoas p
        LEFT JOIN historico_criminal h ON h.pessoa_id = p.id
        LEFT JOIN mandados m ON m.pessoa_id = p.id
        WHERE p.cpf = '111.111.111-11'
    """)

    row = cur.fetchone()
    if row:
        print(f"""
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
👤  Nome:          {row[0]}
🪪  CPF:           {row[1]}
⚠️   Nível perigo: {row[2]}
🔴  Status:        {row[3]}
⚖️   Crime:         {row[4]} ({row[5]})
📋  Mandado:       {row[6]} | Ativo: {row[7]}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)
    cur.close()

def testar_deteccao(conn, pessoa_id):
    print("🔄  Simulando detecção pela câmera...")
    cur = conn.cursor()

    # Pega o ID da câmera cadastrada
    cur.execute("SELECT id FROM cameras LIMIT 1")
    camera = cur.fetchone()
    camera_id = camera[0] if camera else None

    cur.execute("""
        INSERT INTO deteccoes (camera_id, pessoa_id, nome_detectado, confianca, prova_de_vida)
        VALUES (%s, %s, %s, %s, %s)
        RETURNING id
    """, (camera_id, pessoa_id, "JOÃO SILVA TESTE", 0.92, True))

    deteccao_id = cur.fetchone()[0]
    print(f"✅  Detecção registrada! ID: {deteccao_id}")

    # Registra alerta
    cur.execute("""
        INSERT INTO alertas (deteccao_id, canal, mensagem, sucesso)
        VALUES (%s, %s, %s, %s)
    """, (deteccao_id, "sistema", "Alvo detectado: JOÃO SILVA TESTE | Confiança: 92%", True))
    print("✅  Alerta registrado!")

    conn.commit()
    cur.close()

def listar_tabelas(conn):
    print("\n📋  Tabelas no banco:")
    cur = conn.cursor()
    cur.execute("""
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        ORDER BY table_name
    """)
    for row in cur.fetchall():
        print(f"   ✓ {row[0]}")
    cur.close()

# ── EXECUÇÃO ──────────────────────────────────────────
conn = conectar()
if conn:
    listar_tabelas(conn)
    pessoa_id = testar_insert(conn)
    testar_select(conn)
    testar_deteccao(conn, pessoa_id)
    conn.close()
    print("\n🎉  Todos os testes passaram! Banco funcionando perfeitamente.")