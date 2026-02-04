# ----------------------------------------------------------------------
# 1️⃣ Base image – CUDA + PyTorch
# ----------------------------------------------------------------------
FROM pytorch/pytorch:2.9.0-cuda12.8-cudnn9-devel

# ----------------------------------------------------------------------
# 2️⃣ Build-time arguments
# ----------------------------------------------------------------------
ARG UID=1000
ARG GID=1000
ARG COMFYUI_VERSION=v0.12.2

# ----------------------------------------------------------------------
# 3️⃣ Global environment
# ----------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/app \
    PYTHONUNBUFFERED=1 \
    CLI_ARGS="--listen 0.0.0.0" \
    CUDA_HOME="/usr/local/cuda" \
    PATH="/app:/usr/local/cuda/bin:${PATH}" \
    LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

WORKDIR ${ROOT}

# ----------------------------------------------------------------------
# 4️⃣ System packages & user
# ----------------------------------------------------------------------
RUN --mount=type=cache,target=/var/cache/apt \
    groupadd -g ${GID} comfyui && \
    useradd -u ${UID} -g ${GID} -m -s /bin/bash comfyui && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        rsync \
        vim \
        libgl1 \
        libglib2.0-0 \
        python3-dev \
        build-essential \
        cmake && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ----------------------------------------------------------------------
# 5️⃣ Clone ComfyUI
# ----------------------------------------------------------------------
RUN git clone --depth 1 --branch ${COMFYUI_VERSION} \
        https://github.com/Comfy-Org/ComfyUI.git .

# ----------------------------------------------------------------------
# 6️⃣ Install ComfyUI-Manager
# ----------------------------------------------------------------------
WORKDIR /app/custom_nodes
RUN git clone --depth 1 https://github.com/Comfy-Org/ComfyUI-Manager.git

WORKDIR /app

# ----------------------------------------------------------------------
# 7️⃣ Python dependencies (single layer)
# ----------------------------------------------------------------------
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir \
        protobuf==4.25.8 \
        grpcio==1.59.3 \
        bitsandbytes \
        torchsde \
        onnxruntime-gpu \
        ninja \
        triton \
        opencv-python \
        spandrel \
        kornia \
        volcengine \
        google-generativeai \
        matplotlib \
        scikit-image \
        diffusers \
        segment_anything \
        blend_modes \
        timm \
        onnx \
        PyWavelets \
        --extra-index-url https://download.pytorch.org/whl/cu128

# ----------------------------------------------------------------------
# 8️⃣ Extra GPU extensions
# ----------------------------------------------------------------------
ENV TORCH_CUDA_ARCH_LIST="9.0"
RUN pip install --no-cache-dir \
        ninja setuptools wheel && \
    pip install --no-cache-dir \
        git+https://github.com/NVlabs/nvdiffrast.git --no-build-isolation 

# ----------------------------------------------------------------------
# 9️⃣ Git safe directories (needed for Manager)
# ----------------------------------------------------------------------
RUN git config --global --add safe.directory /app && \
    git config --global --add safe.directory /app/custom_nodes/ComfyUI-Manager

# ----------------------------------------------------------------------
# 🔟 Overlay preparation (Singularity / OOD)
# ----------------------------------------------------------------------
USER root
RUN mkdir -p /writable_root/app /writable_root/opt && \
    chmod -R 777 /writable_root && \
    chown -R comfyui:comfyui /app && \
    chmod +x /app/*.py

USER comfyui
ENV PATH="${PATH}:${ROOT}"

# ----------------------------------------------------------------------
# 🚀 Entrypoint
# ----------------------------------------------------------------------
CMD ["sh", "-c", "python3 /app/main.py $CLI_ARGS"]
