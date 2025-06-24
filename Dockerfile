# --- BASE IMAGE ---
FROM pytorch/pytorch:2.7.0-cuda11.8-cudnn9-runtime

# --- ENVIRONMENT VARIABLES ---
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/app \
    LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH" \
    PYTHONUNBUFFERED=1

WORKDIR ${ROOT}

# --- SYSTEM DEPENDENCIES ---
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        vim \
        libgl1-mesa-glx \
        libglib2.0-0 \
        python3-dev \
        gcc \
        g++ && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# --- PYTHON DEPENDENCIES ---
RUN pip install --no-cache-dir --upgrade pip setuptools

# Clone ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI .


RUN pip install --no-cache-dir \
    torch==2.7.0+cu118 \
    torchvision \
    torchaudio==2.7.0+cu118 \
    --extra-index-url https://download.pytorch.org/whl/cu118 \
    protobuf==5.29.5 \
    grpcio-status

# Install ComfyUI dependencies
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir \
        bitsandbytes \
        torchsde \
        onnxruntime-gpu \
        ninja \
        triton \
        opencv-python \
        spandrel \
        kornia && \
    pip install --no-cache-dir -v \
        xformers==0.0.30 --no-deps --index-url https://download.pytorch.org/whl/cu118

# --- CUSTOM NODES ---
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager && \
    git clone https://github.com/twri/sdxl_prompt_styler.git custom_nodes/sdxl_prompt_styler && \
    git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git custom_nodes/ComfyUI_IPAdapter_plus && \
    git clone https://github.com/zhangp365/ComfyUI-utils-nodes.git custom_nodes/ComfyUI-utils-nodes && \
    pip install --no-cache-dir google-generativeai && \
    git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git custom_nodes/comfyui_controlnet_aux && \
    pip install --no-cache-dir -r custom_nodes/comfyui_controlnet_aux/requirements.txt

# --- FIXES ---
RUN git checkout . && git pull && \
    cd custom_nodes/comfyui_controlnet_aux && git pull && \
    cd ../ComfyUI_IPAdapter_plus && git pull && cd ../.. && \
    ln -s /opt/conda/lib/libnvrtc.so.11.8.89 /opt/conda/lib/python3.11/site-packages/torch/lib/libnvrtc.so && \
    sed -i 's/if int((xformers\.__version__).split(".")\[2\]) >= 28:/if int((xformers.__version__).split(".")\[2\].split("+"\)\[0\]) >= 28:/g' /app/comfy/ldm/pixart/blocks.py

# Ensure main.py is executable
RUN sed -i '1i #!/usr/bin/env python3' /app/main.py && chmod +x /app/main.py

ENV CLI_ARGS="--listen 0.0.0.0"
ENV PATH=/app:$PATH

CMD python3 main.py ${CLI_ARGS}
