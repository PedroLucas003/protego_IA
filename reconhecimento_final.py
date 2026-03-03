import cv2
import face_recognition
import os
import numpy as np
from datetime import datetime

# --- CONFIGURAÇÕES ---
IP_ESP32 = "192.168.1.91"  # <--- CONFIRA SE O IP NÃO MUDOU!
URL_VIDEO = f"http://{IP_ESP32}:81/stream"
PASTA_FOTOS = "banco_faces"

# Listas para guardar a memória da IA
conhecidos_encodings = []
conhecidos_nomes = []

def carregar_banco_dados():
    print("🔄 Carregando banco de dados de rostos...")
    if not os.path.exists(PASTA_FOTOS):
        print(f"❌ ERRO: A pasta '{PASTA_FOTOS}' não existe!")
        return

    arquivos = os.listdir(PASTA_FOTOS)
    for arquivo in arquivos:
        if arquivo.endswith(('.jpg', '.png', '.jpeg')):
            nome = os.path.splitext(arquivo)[0].upper()
            caminho = f"{PASTA_FOTOS}/{arquivo}"
            
            # Carrega a foto e aprende o rosto
            imagem = face_recognition.load_image_file(caminho)
            encodings = face_recognition.face_encodings(imagem)
            
            if len(encodings) > 0:
                conhecidos_encodings.append(encodings[0])
                conhecidos_nomes.append(nome)
                print(f"✅ Rosto aprendido: {nome}")
            else:
                print(f"⚠️ Aviso: Nenhum rosto achado na foto {arquivo}")
    print(f"Total de pessoas conhecidas: {len(conhecidos_nomes)}")

# --- INÍCIO ---
carregar_banco_dados()

print(f"📡 Conectando na câmera: {URL_VIDEO}...")
cap = cv2.VideoCapture(URL_VIDEO)

if not cap.isOpened():
    print("❌ Erro ao conectar. Verifique IP e Wi-Fi.")
    exit()

while True:
    ret, frame = cap.read()
    if not ret:
        print("Sinal perdido. Reconectando...")
        cap.release()
        cap = cv2.VideoCapture(URL_VIDEO)
        continue

    # OTIMIZAÇÃO: Reduzir a imagem para processar rápido (0.25 = 1/4 do tamanho)
    frame_pequeno = cv2.resize(frame, (0, 0), fx=0.25, fy=0.25)
    rgb_pequeno = cv2.cvtColor(frame_pequeno, cv2.COLOR_BGR2RGB)

    # 1. Detectar rostos
    face_locations = face_recognition.face_locations(rgb_pequeno)
    face_encodings = face_recognition.face_encodings(rgb_pequeno, face_locations)

    # 2. Reconhecer rostos
    for (top, right, bottom, left), face_encoding in zip(face_locations, face_encodings):
        matches = face_recognition.compare_faces(conhecidos_encodings, face_encoding, tolerance=0.5)
        name = "DESCONHECIDO"

        face_distances = face_recognition.face_distance(conhecidos_encodings, face_encoding)
        if len(face_distances) > 0:
            best_match_index = np.argmin(face_distances)
            if matches[best_match_index]:
                name = conhecidos_nomes[best_match_index]

        # Multiplica por 4 para voltar ao tamanho original (já que reduzimos lá em cima)
        top *= 4
        right *= 4
        bottom *= 4
        left *= 4

        # Desenhar na tela
        cor = (0, 255, 0) if name != "DESCONHECIDO" else (0, 0, 255) # Verde ou Vermelho
        cv2.rectangle(frame, (left, top), (right, bottom), cor, 2)
        cv2.rectangle(frame, (left, bottom - 35), (right, bottom), cor, cv2.FILLED)
        cv2.putText(frame, name, (left + 6, bottom - 6), cv2.FONT_HERSHEY_DUPLEX, 0.8, (255, 255, 255), 1)

    cv2.imshow('Sistema de Reconhecimento Facial', frame)

    if cv2.waitKey(1) == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()