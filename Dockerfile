# syntax=docker/dockerfile:1
# Official llama.cpp b11176, CUDA 12.8.1; immutable multi-platform image.
FROM ghcr.io/ggml-org/llama.cpp@sha256:1f4b9cf58982dd4d7cc497aea31b1a456ca9a3a1f94f527d317d3fdee0d60ab6
RUN apt-get update && apt-get install -y --no-install-recommends python3-venv \
    && python3 -m venv /opt/hf \
    && /opt/hf/bin/pip install --no-cache-dir huggingface_hub==2.0.0 hf-xet==1.6.0 \
    && rm -rf /var/lib/apt/lists/*
RUN python3 -m venv /opt/webui \
    && /opt/webui/bin/pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu \
    && /opt/webui/bin/pip install --no-cache-dir open-webui==0.11.4
COPY start-services.sh healthcheck.sh /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/start-qwen
RUN chmod +x /usr/local/bin/start-qwen /usr/local/bin/start-services.sh /usr/local/bin/healthcheck.sh
ENV ENABLE_WEBUI=true \
    DATA_DIR=/workspace/open-webui \
    CTX_SIZE=8192 \
    LD_LIBRARY_PATH=/app:/usr/local/cuda/lib64 \
    HF_HOME=/workspace/qwen-runpod/hf-cache \
    HF_XET_HIGH_PERFORMANCE=1 \
    HF_XET_NUM_CONCURRENT_RANGE_GETS=32 \
    HF_HUB_DOWNLOAD_TIMEOUT=60 \
    HF_HUB_DISABLE_UPDATE_CHECK=1
WORKDIR /workspace
EXPOSE 8080 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=60m --retries=3 \
    CMD /usr/local/bin/healthcheck.sh
ENTRYPOINT ["/usr/local/bin/start-services.sh"]
