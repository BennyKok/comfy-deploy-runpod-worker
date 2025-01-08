# Use Nvidia CUDA base image
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04 as base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget

# Impact pack deps
RUN apt-get install -y libgl1-mesa-glx libglib2.0-0

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Clone ComfyUI repository
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfyui
# Force comfyui on a specific version
RUN cd /comfyui && git reset --hard b12b48e170ccff156dc6ec11242bb6af7d8437fd

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install ComfyUI dependencies
RUN pip3 install --no-cache-dir torch==2.1.1 torchvision==0.16.1 torchaudio==2.1.1 --index-url https://download.pytorch.org/whl/cu121
RUN pip3 install --no-cache-dir xformers==0.0.23 --index-url https://download.pytorch.org/whl/cu121
RUN pip3 install -r requirements.txt

# Install runpod
RUN pip3 install runpod requests

# Download checkpoints/vae/LoRA to include in image
# RUN wget -O models/checkpoints/sd_xl_base_1.0.safetensors https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors
# RUN wget -O models/vae/sdxl_vae.safetensors https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors
# RUN wget -O models/vae/sdxl-vae-fp16-fix.safetensors https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors
# RUN wget -O models/loras/xl_more_art-full_v1.safetensors https://civitai.com/api/download/models/152309

# Example for adding specific models into image
# ADD models/checkpoints/sd_xl_base_1.0.safetensors models/checkpoints/
# ADD models/vae/sdxl_vae.safetensors models/vae/

# Install custom nodes

WORKDIR /comfyui/custom_nodes

RUN git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git
RUN cd ComfyUI-Manager && pip3 install -r requirements.txt

WORKDIR /comfyui

ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# RUN git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale --recursive
ADD src/install_deps.py src/deps.json ./
RUN python3 install_deps.py

WORKDIR /comfyui/custom_nodes

RUN git clone https://github.com/BennyKok/comfyui-deploy.git && cd comfyui-deploy && git reset --hard 73853a60ff48a83fff1f71c6f7b26104ca75123d
RUN cd comfyui-deploy && pip3 install -r requirements.txt

WORKDIR /

# Add the start and the handler
ADD src/start.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh

# Start the container
CMD /start.sh
