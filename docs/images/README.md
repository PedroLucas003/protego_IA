# Imagens — GitHub Pages (`docs/images/`)

Coloque aqui as mídias exibidas no site. Após adicionar os arquivos, descomente as tags `<img>` correspondentes em `docs/index.html`.

## Estrutura de pastas

| Pasta | Conteúdo |
|-------|----------|
| `arquitetura/` | Diagramas gerais do sistema |
| `hardware/` | Fotos da bodycam, ESP32-CAM, PCB |
| `app/` | Prints do app Flutter (Suspeitos, Câmeras, Alertas, Monitor) |
| `plataforma/` | Dashboard EMQX, Railway, infraestrutura |
| `ia/` | HUD de reconhecimento, gráficos de desempenho |
| `videos/` | Vídeo demonstrativo (`.mp4` ou link externo) |

## Arquivos esperados pelo `index.html`

Use estes nomes (PNG ou JPG, preferência PNG para prints):

### Raiz ou `arquitetura/`
- `arquitetura.png` — diagrama de arquitetura (seção 02)

### `hardware/`
- `PCB.jpeg` — esquema 3D da placa (seção 03 e 06) ✅
- `hardware.jpg` — foto do hardware montado (pendente)

### `app/`
- `App_Suspeitos.jpeg` — aba Suspeitos ✅
- `App_Cameras.jpeg` — aba Câmeras ✅
- `App_Alertas.jpeg` — aba Alertas ✅
- `app-monitor.png` — tela de monitoramento (pendente)

### `plataforma/`
- `emqx-dashboard.png` — dashboard EMQX

### `ia/`
- `reconhecimento-hud.png` — print do HUD OpenCV
- `desempenho.png` — gráfico de performance

### `videos/`
- `demo.mp4` — vídeo demonstrativo (opcional)

## Como referenciar no HTML

Caminho relativo a partir de `docs/index.html`:

```html
<img src="images/app/app-suspeitos.png" alt="Tela Suspeitos">
<img src="images/hardware/bodycam.jpg" alt="Bodycam ESP32-CAM">
```

## Dicas

- Resolução recomendada: **1280px** na largura máxima (prints de celular podem ser menores).
- Evite arquivos acima de **2 MB** para o site carregar rápido.
- Não commite fotos com rostos reais de terceiros sem autorização.
