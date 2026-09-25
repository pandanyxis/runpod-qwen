#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Startup failed at line $LINENO; inspect the container logs." >&2' ERR
: "${LLAMA_API_KEY:?Set LLAMA_API_KEY in the environment}"
if (( ${#LLAMA_API_KEY} < 32 )); then
  echo 'Use an API key with at least 32 random characters.' >&2
  exit 1
fi
export LLAMA_API_KEY
if [[ ! "${CTX_SIZE:-8192}" =~ ^[1-9][0-9]*$ ]]; then
  echo 'CTX_SIZE must be a positive integer.' >&2
  exit 1
fi
ROOT=/workspace/qwen-runpod
HF_REV=993a5971fda8f30dd1b7eb2654792ba4415c7460
MODEL=Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q4_K_P.gguf
SHA=ba36dc3c2b2ff5e0aa5d71092a8894546996a6a119ae391803dda07cdc08516d
PROJECTOR=mmproj-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-BF16.gguf
PROJECTOR_SHA=5681b690bcb8eb10cd28d62d078cb4e01521a3ea4880a3fc7d54de72de2dd142
mkdir -p "$ROOT/models"
cd "$ROOT/models"
if [[ ! -f "$MODEL" ]]; then
  echo 'Downloading the model to the persistent volume...'
  curl --fail --location --retry 5 --retry-delay 5 --continue-at - \
    "https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/$HF_REV/$MODEL" \
    --output "$MODEL.part"
  printf '%s  %s\n' "$SHA" "$MODEL.part" | sha256sum --check -
  mv "$MODEL.part" "$MODEL"
else
  printf '%s  %s\n' "$SHA" "$MODEL" | sha256sum --check -
fi
if [[ ! -f "$PROJECTOR" ]]; then
  echo 'Downloading the vision projector...'
  curl --fail --location --retry 5 --retry-delay 5 --continue-at - \
    "https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/$HF_REV/$PROJECTOR" \
    --output "$PROJECTOR.part"
  printf '%s  %s\n' "$PROJECTOR_SHA" "$PROJECTOR.part" | sha256sum --check -
  mv "$PROJECTOR.part" "$PROJECTOR"
else
  printf '%s  %s\n' "$PROJECTOR_SHA" "$PROJECTOR" | sha256sum --check -
fi
echo 'Starting llama-server with text and vision on port 8080.'
exec /opt/llama/bin/llama-server \
  --model "$ROOT/models/$MODEL" --alias qwen-hauhau \
  --mmproj "$ROOT/models/$PROJECTOR" \
  --host 0.0.0.0 --port 8080 \
  --ctx-size "${CTX_SIZE:-8192}" --parallel 1 \
  --n-gpu-layers 99 --flash-attn on \
  --batch-size 512 --ubatch-size 128 \
  --jinja --no-webui \
  --temp 1.0 --top-k 20 --top-p 0.95 --min-p 0.0

