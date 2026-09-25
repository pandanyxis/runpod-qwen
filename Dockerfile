# syntax=docker/dockerfile:1
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04 AS builder
ARG LLAMA_CPP_REF=4df29be4f4c3673f428170fda944a5b19f743bb8
ARG CUDA_ARCHITECTURES="80;86;89;90"
ARG BUILD_JOBS=4
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates git cmake build-essential libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src/llama.cpp
RUN git init . \
    && git remote add origin https://github.com/ggml-org/llama.cpp.git \
    && git fetch --depth 1 origin "$LLAMA_CPP_REF" \
    && git checkout --detach FETCH_HEAD
RUN cmake -S . -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DGGML_CUDA=ON -DGGML_NATIVE=OFF \
      -DCMAKE_CUDA_ARCHITECTURES="$CUDA_ARCHITECTURES" \
    && cmake --build build --target llama-server -j "$BUILD_JOBS"

FROM nvidia/cuda:12.8.1-runtime-ubuntu22.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl libcurl4 libgomp1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /src/llama.cpp/build/bin/ /opt/llama/bin/
COPY entrypoint.sh /usr/local/bin/start-qwen
RUN chmod +x /usr/local/bin/start-qwen
ENV LD_LIBRARY_PATH=/opt/llama/bin:/usr/local/cuda/lib64:/usr/local/nvidia/lib:/usr/local/nvidia/lib64 \
    CTX_SIZE=8192
WORKDIR /workspace
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=60m --retries=3 \
    CMD curl --fail --silent http://127.0.0.1:8080/health || exit 1
ENTRYPOINT ["/usr/local/bin/start-qwen"]
