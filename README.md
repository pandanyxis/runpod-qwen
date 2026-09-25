# Docker voor RunPod: Qwen + llama.cpp

Deze image bevat een vaste llama.cpp-versie met CUDA. De eerste containerstart downloadt de Q4_K_P-versie van jouw model (circa 17,9 GB) naar `/workspace` en controleert SHA-256. Volgende starts hergebruiken het bestand. Je API-sleutel en model zitten niet in de image.

## Bouwen en publiceren

Pak het pakket uit en open een terminal in deze map. Docker met Linux-containers is nodig. Voor het bouwen is geen GPU nodig; voor inference wel een NVIDIA-GPU en een geschikte NVIDIA-driver/container-runtime.

Vervang `JOUW_DOCKERHUB_NAAM` door je eigen Docker Hub-account:

```sh
docker build --platform linux/amd64 -t JOUW_DOCKERHUB_NAAM/runpod-qwen:1 .
docker login
docker push JOUW_DOCKERHUB_NAAM/runpod-qwen:1
```

De build compileert llama.cpp en kan enige tijd duren. Standaard zijn A100, A40/RTX A6000, L40/RTX 4090 en H100-architecturen opgenomen. Voor een andere GPU-architectuur moet je de build-argumentwaarde `CUDA_ARCHITECTURES` aanpassen. Blackwell is niet opgenomen in deze standaardbuild.

## RunPod-template

| Veld | Waarde |
|---|---|
| Container image | `JOUW_DOCKERHUB_NAAM/runpod-qwen:1` |
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

De shellsyntax en de invoervalidatie zijn lokaal gecontroleerd. Docker is in de gebruikte omgeving niet beschikbaar: de image is nog niet gebouwd, gepubliceerd of op een GPU getest. Dit pakket start tekstinference; optionele FastMTP-versnelling en de vision-projector zijn niet ingeschakeld.

Bronnen:
- https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF
- https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
- https://docs.runpod.io/pods/configuration/expose-ports
