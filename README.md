# Qwen Vision on RunPod with llama.cpp

A public Docker image for running an authenticated, OpenAI-compatible text and image API on an NVIDIA GPU.

```text
ghcr.io/pandanyxis/runpod-qwen:vision
```

The image is public and can be pulled without registry credentials. It downloads the model and vision projector automatically on first startup, verifies their SHA-256 checksums, and reuses them from persistent storage on later starts. Model weights and API keys are not included in the image.

## Model and runtime

- Model: [HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF](https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF).
- Quantization: Q4_K_P, approximately 17.9 GB.
- Vision projector: BF16, approximately 931 MB.
- Runtime: official llama.cpp b11176 CUDA 12.8.1 image, pinned by digest.
- Model revision: `993a5971fda8f30dd1b7eb2654792ba4415c7460`.
- Text generation and image understanding are supported. This is not an image-generation server.
- Optional FastMTP acceleration is not enabled.

## Deploy on RunPod

[Open the public RunPod template](https://console.runpod.io/hub/template/dmx2k72drz)

The template uses the tested image pinned by digest, 20 GB container disk, an 80 GB persistent volume, HTTP port 8080, and a 32,768-token context. Select an NVIDIA GPU with 48 GB VRAM and CUDA 12.8 or later. Before deploying, **add the environment variable `LLAMA_API_KEY` with your own random secret of at least 32 characters**. No shared API key is included; startup intentionally fails if you do not provide one. You may also add an optional `HF_TOKEN`. Creating or viewing the template does not start a GPU; deploying a Pod incurs the prices shown by RunPod.

Create a GPU Pod with these settings:

| Setting | Value |
|---|---|
| Container image | `ghcr.io/pandanyxis/runpod-qwen:vision` |
| Docker command / start command | Leave empty to use the image entrypoint |
| HTTP port | `8080` |
| Container disk | `20 GB` |
| Volume disk | `80 GB` |
| Volume mount path | `/workspace` |
| GPU | One NVIDIA A40 with 48 GB VRAM was tested |
| Host CUDA support | CUDA 12.8 or later |
| Environment: `LLAMA_API_KEY` | A random secret containing at least 32 characters |
| Environment: `CTX_SIZE` | `8192` by default; `32768` was also tested on an A40 |
| Environment: `HF_TOKEN` | Optional Hugging Face read token |

Generate a key using a password manager or `openssl rand -hex 32`. Set secrets in the Pod environment; never commit them to GitHub or bake them into the image.

Check current GPU availability and pricing before deploying. Watch the container logs during the initial download and model loading. The server is ready when `/health` returns `{"status":"ok"}`.

The Pod volume survives stopping the Pod, but not deleting it. Stopped Pods still incur storage charges. Use a network volume if model storage must be independent of the Pod.

## Connect your application

For an OpenAI-compatible client, select **API providers → Custom** and enter:

| Field | Value |
|---|---|
| API base URL | `https://POD_ID-8080.proxy.runpod.net/v1` |
| Model ID | `qwen-hauhau` |
| API key | Your `LLAMA_API_KEY` |
| Endpoint accepts image_url inputs | Enabled |
| Known context | Match the Pod's `CTX_SIZE` |

Replace `POD_ID` with your own Pod ID. The OpenAI-compatible base URL must end in `/v1`.

Clients that support remote llama.cpp servers directly may use `https://POD_ID-8080.proxy.runpod.net`. If that client option only accepts localhost, use its OpenAI-compatible custom provider instead.

Images are sent as `image_url` content items to `/v1/chat/completions`, including data URLs such as `data:image/png;base64,...`. The model describes or analyzes the supplied image.

The health endpoint is public. The model list and chat endpoints require `Authorization: Bearer YOUR_API_KEY`. Confirm that a request to `/v1/models` without a key returns HTTP 401.

RunPod exposes the API over HTTPS. Its HTTP proxy has a 100-second timeout, so long prompt processing can time out. Use streaming where supported by the client.

## Parallel Hugging Face downloads

The image includes `huggingface_hub==2.0.0` and `hf-xet==1.6.0`. The Hugging Face downloader fetches the model and vision projector with parallel chunk transfers.

These defaults are included:

```text
HF_HOME=/workspace/qwen-runpod/hf-cache
HF_XET_HIGH_PERFORMANCE=1
HF_XET_NUM_CONCURRENT_RANGE_GETS=32
HF_HUB_DOWNLOAD_TIMEOUT=60
```

The cache is stored on the persistent volume. Actual download speed depends on host bandwidth, the remote service, and storage performance.

This public model does not require a Hugging Face token. If needed, provide `HF_TOKEN` through the RunPod environment or a local `.env` file. Adding a token alone does not guarantee faster downloads.

Completed model files from the previous curl-based image are reused and checksum-verified. An incomplete curl `.part` file cannot be resumed by Xet, so that file starts again during the one-time migration. Later starts reuse the Hugging Face cache.

## Run locally with Docker Compose

Docker with Linux containers, an NVIDIA GPU, and a compatible NVIDIA driver/container runtime are required. Use a Docker Compose version that supports `gpus`.

Copy `.env.example` to `.env`, set `LLAMA_API_KEY`, then run:

```sh
docker compose up --build -d
docker compose logs -f
```

The local API is available at `http://127.0.0.1:8080`. The Compose configuration binds to localhost, and the `qwen-data` named volume stores the model.

## Build and publish your own image

No GPU is required to build the image. GitHub Actions builds and publishes this repository's `vision`, `latest`, and commit-SHA tags. See [Actions](https://github.com/pandanyxis/runpod-qwen/actions) for build results.

To publish under your own Docker Hub account:

```sh
docker build --platform linux/amd64 -t YOUR_DOCKERHUB_USERNAME/runpod-qwen:1 .
docker login
docker push YOUR_DOCKERHUB_USERNAME/runpod-qwen:1
```

The build extends the official prebuilt llama.cpp CUDA image; no llama.cpp compilation is required. For reproducible deployments, use a published image digest instead of a moving tag.

## Validation

On September 25, 2026, the image was tested on an A40 with a 32,768-token context:

- Health endpoint returned `ok`.
- Text generation succeeded.
- Image understanding correctly identified a red square on the left and a blue circle on the right.
- Requests to `/v1/models` without an API key returned HTTP 401.

GitHub Actions checks shell syntax, the server binary, the Hugging Face CLI, and Python package imports. Xet download acceleration was not benchmarked: the model files were already present when that image update was deployed.

## References

- [Model repository](https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF)
- [llama.cpp server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)
- [RunPod HTTP ports](https://docs.runpod.io/pods/configuration/expose-ports)
- [Hugging Face Xet configuration](https://huggingface.co/docs/huggingface_hub/package_reference/environment_variables#hf_xet_high_performance)
