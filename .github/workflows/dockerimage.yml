# Start from the PyTorch base image with CUDA and CUDNN support
FROM pytorch/pytorch:2.7.1-cuda11.8-cudnn9-runtime

# --- ENVIRONMENT VARIABLES ---
# Set environment variables for non-interactive installs, pip, and the app root
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/app \
    LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH" \
    PYTHONUNBUFFERED=1

# Set the working directory for subsequent commands
WORKDIR ${ROOT}


# --- SYSTEM DEPENDENCIES ---
# Update package lists and install necessary system libraries
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


# --- PYTHON DEPENDENCIES & COMFYUI INSTALLATION ---
# Upgrade pip and setuptools first
RUN pip3 install --no-cache-dir --upgrade pip setuptools==76.1.0

# Clone the ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI .

# Install all Python dependencies in a single layer to optimize caching and image size
RUN --mount=type=cache,target=/root/.cache/pip \
    pip3 install --no-cache-dir -r requirements.txt && \
    pip3 install --no-cache-dir \
        bitsandbytes==0.41.1 \
        torchsde \
        onnxruntime-gpu \
        ninja \
        triton \
        opencv-python \
        spandrel \
        kornia && \
    pip3 install --no-cache-dir -v xformers==0.0.26 --index-url https://download.pytorch.org/whl/cu118


# --- CUSTOM NODES ---
# Clone all custom nodes and install their specific dependencies
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git custom_nodes/ComfyUI-Manager && \
    git clone https://github.com/twri/sdxl_prompt_styler.git custom_nodes/sdxl_prompt_styler && \
    git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git custom_nodes/ComfyUI_IPAdapter_plus && \
    git clone https://github.com/zhangp365/ComfyUI-utils-nodes.git custom_nodes/ComfyUI-utils-nodes && \
    pip install --no-cache-dir google-generativeai && \
    git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git custom_nodes/comfyui_controlnet_aux && \
    pip install --no-cache-dir -r custom_nodes/comfyui_controlnet_aux/requirements.txt


# --- FINAL SETUP & CONFIGURATION ---
# Copy entrypoint scripts from the local context into the image
COPY ./scripts /scripts
# Ensure scripts are executable and have correct line endings
RUN sed -i 's/\r$//' /scripts/docker-entrypoint.sh && \
    chmod +x /scripts/*

# Pull latest changes for the repositories and apply environment-specific fixes
# Note: `git pull` makes the build less deterministic but gets the latest updates
RUN git checkout . && git pull && \
    cd custom_nodes/comfyui_controlnet_aux && git pull && \
    cd ../ComfyUI_IPAdapter_plus && git pull && cd ../.. && \
    # Fix for libnvrtc library path
    ln -s /opt/conda/lib/libnvrtc.so.11.8.89 /opt/conda/lib/python3.10/site-packages/torch/lib/libnvrtc.so && \
    # Patch for xformers version check
    sed -i 's/if int((xformers\.__version__).split(".")\[2\]) >= 28:/if int((xformers.__version__).split(".")\[2\].split("+"\)\[0\]) >= 28:/g' /app/comfy/ldm/pixart/blocks.py

RUN sed -i '1i #!/usr/bin/env python3' /app/main.py & chmod +x /app/main.py

# Set the entrypoint to our custom script
ENTRYPOINT ["/scripts/docker-entrypoint.sh"]

# Set default command-line arguments (can be overridden)
ENV CLI_ARGS="--listen 0.0.0.0"

# The command to run the application
CMD python3 main.py ${CLI_ARGS}