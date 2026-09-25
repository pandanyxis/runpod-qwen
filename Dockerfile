# syntax=docker/dockerfile:1
# Official llama.cpp b11176, CUDA 12.8.1; immutable multi-platform image.
FROM ghcr.io/ggml-org/llama.cpp@sha256:1f4b9cf58982dd4d7cc497aea31b1a456ca9a3a1f94f527d317d3fdee0d60ab6
COPY entrypoint.sh /usr/local/bin/start-qwen
RUN chmod +x /usr/local/bin/start-qwen
ENV CTX_SIZE=8192
WORKDIR /workspace
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=60m --retries=3 \
    CMD curl --fail --silent http://127.0.0.1:8080/health || exit 1
ENTRYPOINT ["/usr/local/bin/start-qwen"]
