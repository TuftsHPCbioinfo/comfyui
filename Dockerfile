# syntax=docker/dockerfile:1.7

# ----------------------------------------------------------------------
# 1) Base image
# ----------------------------------------------------------------------
FROM pytorch/pytorch:2.9.0-cuda12.8-cudnn9-devel

# ----------------------------------------------------------------------
# 2) Build arguments
# ----------------------------------------------------------------------
ARG UID=1000
ARG GID=1000
ARG COMFYUI_VERSION=v0.19.0
ARG COMFYUI_MANAGER_REPO=https://github.com/Comfy-Org/ComfyUI-Manager.git
ARG NVDIFFRAST_REPO=https://github.com/NVlabs/nvdiffrast.git

# ----------------------------------------------------------------------
# 3) Environment
# ----------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    ROOT=/app \
    CUDA_HOME=/usr/local/cuda \
    PATH=/app:/usr/local/cuda/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH} \
    CLI_ARGS="--listen 0.0.0.0 --port 8188"

WORKDIR ${ROOT}

# ----------------------------------------------------------------------
# 4) System packages + user
# ----------------------------------------------------------------------
RUN --mount=type=cache,target=/var/cache/apt \
    set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        git \
        git-lfs \
        rsync \
        curl \
        wget \
        vim \
        libgl1 \
        libglib2.0-0 \
        libgomp1 \
        python3-dev \
        build-essential \
        cmake \
        ninja-build; \
    rm -rf /var/lib/apt/lists/*; \
    groupadd -g "${GID}" comfyui; \
    useradd -m -u "${UID}" -g "${GID}" -s /bin/bash comfyui

# ----------------------------------------------------------------------
# 5) Clone ComfyUI
# ----------------------------------------------------------------------
RUN set -eux; \
    git clone --depth 1 --branch "${COMFYUI_VERSION}" https://github.com/Comfy-Org/ComfyUI.git "${ROOT}"

# ----------------------------------------------------------------------
# 6) Clone ComfyUI-Manager
# ----------------------------------------------------------------------
RUN set -eux; \
    mkdir -p "${ROOT}/custom_nodes"; \
    git clone --depth 1 "${COMFYUI_MANAGER_REPO}" "${ROOT}/custom_nodes/ComfyUI-Manager"

# ----------------------------------------------------------------------
# 7) Python dependencies
# ----------------------------------------------------------------------
RUN --mount=type=cache,target=/root/.cache/pip \
    set -eux; \
    python -m pip install --upgrade pip setuptools wheel; \
    pip install -r requirements.txt; \
    pip install \
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
# 8) Install nvdiffrast properly
#    This is the key fix for your earlier error.
# ----------------------------------------------------------------------
RUN --mount=type=cache,target=/root/.cache/pip \
    set -eux; \
    pip install --no-build-isolation "git+${NVDIFFRAST_REPO}"

# ----------------------------------------------------------------------
# 9) Git safe directories
# ----------------------------------------------------------------------
RUN set -eux; \
    git config --system --add safe.directory /app; \
    git config --system --add safe.directory /app/custom_nodes/ComfyUI-Manager

# ----------------------------------------------------------------------
# 10) Writable overlay prep for Singularity / Apptainer / OOD
# ----------------------------------------------------------------------
RUN set -eux; \
    mkdir -p /writable_root/app /writable_root/opt; \
    chmod -R 777 /writable_root; \
    chown -R comfyui:comfyui /app; \
    find /app -name "*.py" -type f -exec chmod +x {} \;

# ----------------------------------------------------------------------
# 11) Startup script
# ----------------------------------------------------------------------
RUN cat > /usr/local/bin/start-comfyui.sh <<'EOF' && chmod +x /usr/local/bin/start-comfyui.sh
#!/usr/bin/env bash
set -euo pipefail

echo "=== ComfyUI startup ==="
echo "Python: $(python --version)"
echo "Working dir: $(pwd)"
echo "CLI_ARGS: ${CLI_ARGS:-}"

python - <<'PY'
import torch
print("Torch version:", torch.__version__)
print("Torch CUDA version:", torch.version.cuda)
print("CUDA available:", torch.cuda.is_available())
print("Device count:", torch.cuda.device_count())
if torch.cuda.is_available():
    try:
        print("Current device:", torch.cuda.current_device())
        print("Device name:", torch.cuda.get_device_name(torch.cuda.current_device()))
    except Exception as e:
        print("CUDA visible but device query failed:", repr(e))
else:
    print("WARNING: CUDA is not available inside this container.")
    print("If you expected GPU access, run Docker with --gpus all")
    print("or Apptainer/Singularity with --nv, and make sure the host has NVIDIA drivers.")
PY

exec python /app/main.py ${CLI_ARGS:-"--listen 0.0.0.0 --port 8188"}
EOF

# ----------------------------------------------------------------------
# 12) Final user
# ----------------------------------------------------------------------
USER comfyui
WORKDIR /app
ENV PATH="${PATH}:${ROOT}"

# ----------------------------------------------------------------------
# 13) Expose port
# ----------------------------------------------------------------------
EXPOSE 8188

# ----------------------------------------------------------------------
# 14) Entrypoint
# ----------------------------------------------------------------------
CMD ["/usr/local/bin/start-comfyui.sh"]