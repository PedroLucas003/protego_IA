import cv2
import requests
import numpy as np

# --- CONFIGURAÇÕES ---
# 1. IP da Câmera (Confira se é esse mesmo no Serial Monitor)
IP_ESP32 = "192.168.1.91"  
URL_VIDEO = f"http://{IP_ESP32}:81/stream"

# Carrega o detector de rostos padrão do OpenCV (vem junto com a instalação)
# Esse método não precisa de dlib nem de face_recognition!
face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

print(f"📡 Conectando à Bodycam em {URL_VIDEO}...")
cap = cv2.VideoCapture(URL_VIDEO)

if not cap.isOpened():
    print("❌ Erro: Não conectou. Verifique o IP e se o ESP32 está ligado.")
    print("Dica: Tente acessar o IP pelo navegador para ver se a câmera está online.")
    exit()

print("✅ Conectado! Pressione 'q' para sair.")

while True:
    ret, frame = cap.read()
    if not ret:
        print("⚠️ Sinal perdido... tentando reconectar.")
        cap.release()
        cap = cv2.VideoCapture(URL_VIDEO)
        continue

    # --- PASSO 1: TRATAMENTO DE IMAGEM ---
    # Transforma em cinza (a IA antiga funciona melhor em preto e branco)
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # --- PASSO 2: DETECÇÃO ---
    # scaleFactor=1.1 -> Reduz a imagem 10% a cada passo para achar rostos de vários tamanhos
    # minNeighbors=5 -> Exige 5 confirmações para ter certeza que é um rosto (evita falsos positivos)
    faces = face_cascade.detectMultiScale(gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30))

    # --- PASSO 3: DESENHAR NA TELA ---
    for (x, y, w, h) in faces:
        # Desenha um retângulo verde
        cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 255, 0), 2)
        
        # Escreve "ALVO" em cima
        cv2.putText(frame, "ROSTO DETECTADO", (x, y-10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)
        
        # (Opcional) Aqui você mandaria um alerta simples para a nuvem
        # requests.post("http://seusite.com/api", json={"alerta": "rosto_detectado"})

    # Mostra o vídeo colorido na tela
    cv2.imshow('Bodycam - Monitoramento (Modo Compatibilidade)', frame)

    if cv2.waitKey(1) == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()