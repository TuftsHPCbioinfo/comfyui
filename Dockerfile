FROM pytorch/pytorch:2.8.0-cuda12.9-cudnn9-runtime

# --- ENVIRONMENT & ARGUMENTS ---
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/app \
    LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH" \
    PYTHONUNBUFFERED=1 \
    CLI_ARGS="--listen 0.0.0.0" \
    PATH=/app:$PATH

# Arguments for non-root user
ARG UID=1000
ARG GID=1000

WORKDIR ${ROOT}

# --- SYSTEM SETUP & DEPENDENCIES ---
# Create a non-root user and install system dependencies in one layer
RUN --mount=type=cache,target=/var/cache/apt \
    groupadd -g ${GID} comfyui && \
    useradd -u ${UID} -g ${GID} -m comfyui && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        vim \
        libgl1-mesa-glx \
        libglib2.0-0 \
        python3-dev \
        # [cite: 2]
        gcc \
        g++ && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# --- PROJECT & PYTHON DEPENDENCIES ---
# Clone all repositories first
RUN git clone --branch v0.3.50 --depth 1 --single-branch https://github.com/comfyanonymous/ComfyUI.git . && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager && \
    git clone https://github.com/twri/sdxl_prompt_styler.git custom_nodes/sdxl_prompt_styler && \
    git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git custom_nodes/ComfyUI_IPAdapter_plus && \
    git clone https://github.com/zhangp365/ComfyUI-utils-nodes.git custom_nodes/ComfyUI-utils-nodes && \
    git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git custom_nodes/comfyui_controlnet_aux

# Install all Python packages in a single RUN command to resolve dependencies correctly
# This is the most critical change to fix installation errors.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir --upgrade pip setuptools && \
    pip install --no-cache-dir \
        # Pinned versions to solve conflicts from your previous error log
        protobuf==4.25.8 \
        grpcio==1.59.3 \
        grpcio-status==1.59.3 \
        # Core torch dependencies [cite: 3]
        torch==2.8.0+cu129 \
        torchvision \
        torchaudio==2.8.0+cu129 \
        --extra-index-url https://download.pytorch.org/whl/cu129 \
        # Packages from main requirements.txt (and others) [cite: 4]
        -r requirements.txt \
        bitsandbytes \
        torchsde \
        onnxruntime-gpu \
        ninja \
        triton \
        opencv-python \
        spandrel \
        kornia \
        volcengine \
        # Packages from custom node requirements
        google-generativeai \
        -r custom_nodes/comfyui_controlnet_aux/requirements.txt

# --- FIXES & CONFIGURATION ---
# Apply necessary patches and set permissions
# Note: The 'git pull' commands were removed for reproducibility.
RUN sed -i 's/if int((xformers\.__version__).split(".")\[2\]) >= 28:/if int((xformers.__version__).split(".")\[2\].split("+"\)\[0\]) >= 28:/g' /app/comfy/ldm/pixart/blocks.py && \
    sed -i '1i #!/usr/bin/env python3' /app/main.py && \
    chmod +x /app/main.py && \
    chown -R comfyui:comfyui ${ROOT}

# Switch to the non-root user
USER comfyui

# --- RUN ---
CMD python3 main.py ${CLI_ARGS}
