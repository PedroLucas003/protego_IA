# ==============================================================================
#  CADASTRAR ALVO — InsightFace ArcFace (512 dimensões)
#  Compatível com o reconhecimento_final.py atualizado
# ==============================================================================

import cv2
import os
import json
import numpy as np
import psycopg2
from PIL import Image, ImageOps
from insightface.app import FaceAnalysis
from dotenv import load_dotenv

load_dotenv()
DB_URL = os.getenv("DB_URL")

# Carrega InsightFace
print("Carregando InsightFace...")
app = FaceAnalysis(name="buffalo_l", providers=["CPUExecutionProvider"])
app.prepare(ctx_id=0, det_size=(640, 640))
print("Pronto.\n")

def get_conn():
    return psycopg2.connect(DB_URL)

def gerar_encoding(caminho_foto):
    """
    Gera embedding ArcFace (512 floats) a partir de uma foto.
    Corrige rotação EXIF automaticamente.
    """
    try:
        pil_img  = Image.open(caminho_foto).convert("RGB")
        pil_img  = ImageOps.exif_transpose(pil_img)  # corrige rotação do celular
        img_rgb  = np.array(pil_img)
        img_bgr  = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2BGR)

        faces = app.get(img_rgb)

        if not faces:
            print("❌  Nenhum rosto detectado na foto. Tente outra imagem.")
            return None

        if len(faces) > 1:
            print(f"⚠️  {len(faces)} rostos detectados. Usando o de maior confiança.")

        # Pega o rosto com maior score de detecção
        face = max(faces, key=lambda f: f.det_score)
        emb  = face.embedding.astype(np.float32)
        emb  = emb / (np.linalg.norm(emb) + 1e-6)  # normaliza

        print(f"✅  Encoding gerado ({len(emb)} dimensões) | Confiança detecção: {face.det_score:.2%}")
        return emb.tolist()

    except Exception as e:
        print(f"❌  Erro ao gerar encoding: {e}")
        return None

def cadastrar_alvo():
    print("=" * 55)
    print("  CADASTRAR NOVO ALVO")
    print("=" * 55)

    nome = input("Nome completo: ").strip().upper()
    if not nome:
        print("Nome obrigatorio.")
        return

    cpf  = input("CPF (Enter para pular): ").strip() or None
    rg   = input("RG  (Enter para pular): ").strip() or None

    print("\nNivel de perigo:")
    print("  1 - BAIXO   2 - MEDIO   3 - ALTO   4 - CRITICO")
    perigo_map = {"1": "BAIXO", "2": "MEDIO", "3": "ALTO", "4": "CRITICO"}
    perigo     = perigo_map.get(input("Opcao: ").strip(), "BAIXO")

    print("\nStatus:")
    print("  1 - ATIVO   2 - PRESO   3 - FORAGIDO   4 - MONITORADO")
    status_map = {"1": "ATIVO", "2": "PRESO", "3": "FORAGIDO", "4": "MONITORADO"}
    status     = status_map.get(input("Opcao: ").strip(), "ATIVO")

    obs = input("Observacoes (Enter para pular): ").strip() or None

    # Fotos — aceita múltiplas para melhor reconhecimento
    print("\nCaminho(s) da(s) foto(s) — quanto mais ângulos, melhor o reconhecimento.")
    print("Digite um caminho por linha. Linha vazia para terminar.")
    encodings = []
    while True:
        foto = input(f"Foto {len(encodings)+1}: ").strip().strip('"')
        if not foto:
            break
        if not os.path.exists(foto):
            print(f"  Arquivo nao encontrado: {foto}")
            continue
        enc = gerar_encoding(foto)
        if enc:
            encodings.append(enc)

    if not encodings:
        print("❌  Nenhum encoding gerado. Cadastro cancelado.")
        return

    # Salva no banco
    # Se múltiplos encodings: salva como lista de listas
    # Se único: salva como lista simples (retrocompatível)
    if len(encodings) == 1:
        encoding_json = json.dumps(encodings[0])
    else:
        encoding_json = json.dumps(encodings)

    try:
        conn = get_conn()
        cur  = conn.cursor()
        cur.execute("""
            INSERT INTO pessoas
                (nome, cpf, rg, nivel_perigo, status, observacoes,
                 mandados, crimes, artigos,
                 confianca, prova_de_vida, tem_mandado, timestamp, encoding)
            VALUES (%s, %s, %s, %s, %s, %s,
                    '[]'::jsonb, '[]'::jsonb, '[]'::jsonb,
                    %s, %s, %s, NOW(), %s::jsonb)
            RETURNING id
        """, (nome, cpf, rg, perigo, status, obs, 0.0, False, False, encoding_json))
        pid = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()

        print(f"\n✅  Alvo cadastrado com sucesso!")
        print(f"   Nome   : {nome}")
        print(f"   ID     : {pid}")
        print(f"   Perigo : {perigo} | Status: {status}")
        print(f"   Fotos  : {len(encodings)} encoding(s) de 512 dimensões")

    except Exception as e:
        print(f"❌  Erro ao salvar no banco: {e}")

def listar_alvos():
    try:
        conn = get_conn()
        cur  = conn.cursor()
        cur.execute("SELECT id, nome, nivel_perigo, status FROM pessoas ORDER BY nome")
        rows = cur.fetchall()
        cur.close()
        conn.close()

        print(f"\n{'='*55}")
        print(f"  ALVOS CADASTRADOS ({len(rows)})")
        print(f"{'='*55}")
        for r in rows:
            print(f"  {r[1]:35s}  {r[2]:8s}  {r[3]}")

    except Exception as e:
        print(f"❌  Erro: {e}")

def main():
    while True:
        print("\n" + "="*40)
        print("  PROTEGO IA — Gerenciamento de Alvos")
        print("="*40)
        print("  1 - Cadastrar novo alvo")
        print("  2 - Listar alvos")
        print("  0 - Sair")
        op = input("Opcao: ").strip()

        if op == "1":
            cadastrar_alvo()
        elif op == "2":
            listar_alvos()
        elif op == "0":
            break

if __name__ == "__main__":
    main()