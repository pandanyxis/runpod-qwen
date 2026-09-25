# Docker voor RunPod: Qwen + llama.cpp

Deze image bevat een vaste llama.cpp-versie met CUDA. De eerste containerstart downloadt de Q4_K_P-versie van jouw model (circa 17,9 GB) en de bijbehorende vision-projector (circa 931 MB) naar `/workspace` en controleert SHA-256. Volgende starts hergebruiken het bestand. Je API-sleutel en model zitten niet in de image.

## Automatische build op GitHub

GitHub Actions bouwt en publiceert `ghcr.io/pandanyxis/runpod-qwen:vision`. Bekijk de laatste run onder Actions voordat je deployt. De basis is de officiële llama.cpp CUDA-image b11176 met CUDA 12.8.1, vastgezet op een immutable digest. De GitHub-workflow voegt onze startconfiguratie met tekst- en afbeeldingsondersteuning toe; zelf compileren is niet nodig.

## Zelf bouwen en publiceren

Pak het pakket uit en open een terminal in deze map. Docker met Linux-containers is nodig. Voor het bouwen is geen GPU nodig; voor inference wel een NVIDIA-GPU en een geschikte NVIDIA-driver/container-runtime.

Vervang `JOUW_DOCKERHUB_NAAM` door je eigen Docker Hub-account:

```sh
docker build --platform linux/amd64 -t JOUW_DOCKERHUB_NAAM/runpod-qwen:1 .
docker login
docker push JOUW_DOCKERHUB_NAAM/runpod-qwen:1
```

De build downloadt de officiële CUDA-image en voegt het startscript toe. De RunPod-host moet CUDA 12.8 of hoger ondersteunen. De gekozen GPU voor deployment is een A40 met 48 GB VRAM; de feitelijke beschikbaarheid wordt bij deployment gecontroleerd.

## RunPod-template

| Veld | Waarde |
|---|---|
| Container image | `ghcr.io/pandanyxis/runpod-qwen:vision` |
| Docker command / start command | Leeg laten; gebruik de image-entrypoint |
| HTTP ports | `8080` |
| Container disk | `20 GB` |
| Volume disk | `80 GB` |
| Volume mount path | `/workspace` |
| GPU | Bijvoorbeeld 1 x A40 of RTX A6000, 48 GB VRAM |
| Environment: `LLAMA_API_KEY` | Eigen willekeurige sleutel van minimaal 32 tekens |
| Environment: `CTX_SIZE` | `8192` |

Gebruik voor de sleutel bijvoorbeeld `openssl rand -hex 32`, of een wachtwoordgenerator. Zet de sleutel uitsluitend in de environment variables. Voor een private image moet RunPod ook je registry-credentials krijgen.

De eerste start downloadt het model; bekijk de logs tot de server gereed is. Opslag op een Pod-volume overleeft stoppen, maar niet het verwijderen van de Pod. Gebruik een network volume als het model onafhankelijk van de Pod bewaard moet blijven. Controleer het actuele GPU- en opslagtarief in RunPod voor deployment.

## Verbinden

Kies in de app **API providers → Custom**. Zet **Endpoint accepts image_url inputs** aan en **Known context** op `8192`. De API-base-URL moet eindigen op `/v1`. Afbeeldingen gaan als `image_url`-content mee naar `/v1/chat/completions`, bijvoorbeeld als `data:image/png;base64,...`.


- External llama.cpp server: `https://POD_ID-8080.proxy.runpod.net`
- Model ID: `qwen-hauhau`
- API-key: de ingestelde `LLAMA_API_KEY`.

Je screenshot vermeldt “Localhost only”. Als je app daarom geen externe server accepteert, gebruik API providers / OpenAI-compatible met base URL `https://POD_ID-8080.proxy.runpod.net/v1`.

Controleer `/health`: na laden geeft deze publieke route `{"status":"ok"}`. `/v1/models` en `/v1/chat/completions` vereisen `Authorization: Bearer JE_SLEUTEL`. Controleer bij deployment ook dat een aanvraag naar `/v1/models` zonder sleutel wordt geweigerd.

RunPod heeft een proxy-timeout van 100 seconden; lange promptverwerking kan die overschrijden. Gebruik streaming waar de client dit ondersteunt. De API wordt via RunPod HTTPS bereikbaar.

## Lokaal met Docker Compose

Kopieer `.env.example` naar `.env` en vul de sleutel in. Met een recente Docker Compose-versie die `gpus` ondersteunt:

```sh
docker compose up --build -d
docker compose logs -f
```

Lokaal bereikbaar op `http://127.0.0.1:8080`. Het named volume `qwen-data` bewaart het model. De lokale Compose-config bindt aan localhost; RunPod verzorgt de externe HTTPS-toegang bij deployment.

## Validatie en scope

De shellsyntax en de invoervalidatie zijn lokaal gecontroleerd. De image wordt gebouwd in GitHub Actions, inclusief een controle op runtimebibliotheken. De actuele buildstatus staat onder Actions. GPU-inference moet afzonderlijk worden gecontroleerd op de Pod. Dit pakket ondersteunt tekst en afbeeldingen via de BF16 vision-projector. Optionele FastMTP-versnelling is niet ingeschakeld.

Bronnen:
- https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF
- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://docs.runpod.io/pods/configuration/expose-ports

