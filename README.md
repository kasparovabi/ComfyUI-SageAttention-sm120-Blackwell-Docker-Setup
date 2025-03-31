# ComfyUI-SageAttention-sm120-Blackwell-Docker-Setup

This guide provides a working Docker setup for running ComfyUI with SageAttention acceleration enabled on newer NVIDIA GPUs reporting compute capability `sm_120` (e.g., Blackwell architecture / RTX 50 series).

**Problem:** Users with this hardware often encounter issues when trying to use performance acceleration libraries like SageAttention alongside cutting-edge software like PyTorch nightly builds. Common problems include:
*   LLVM compiler errors during runtime (e.g., `Cannot select: intrinsic %llvm.nvvm.shfl.sync.bfly.i32`).
*   Dependency conflicts between `bitsandbytes`, `diffusers`, `transformers`, `huggingface-hub`, and the specific PyTorch version.
*   General instability during image generation.

**Solution:** This Dockerfile aims to create a stable environment by incorporating fixes and best practices identified during troubleshooting:
*   Uses a recent **PyTorch nightly build** (tested with CUDA 12.8), which generally has better, more up-to-date support for the newest hardware architectures.
*   Installs SageAttention specifically from the **`sm120_compilation` branch** of the official repository, which contains targeted fixes for this architecture.
*   Installs **`bitsandbytes`** using pip and relies on runtime environment variables (`LD_LIBRARY_PATH`) set via the `entrypoint.sh` script for proper CUDA library linking, avoiding potential conflicts with `BNB_CUDA_VERSION`.
*   Uses the **Triton version bundled with PyTorch nightly**, avoiding potential conflicts from a separate source build.
*   Installs compatible versions of **`diffusers` and `transformers`**.

## Prerequisites

*   Docker and NVIDIA Container Toolkit installed on your host machine.
*   Appropriate NVIDIA drivers installed on the host that support your Blackwell/sm_120 GPU and CUDA 12.8+.

## Files

1.  **`Dockerfile`**: Contains the build instructions.
2.  **`entrypoint.sh`**: Script run at container startup to set the environment.

*(Make sure both files are in the same directory before building)*

## Dockerfile Content

```dockerfile
# Base image with CUDA 12.8 runtime and Ubuntu 24.04
FROM nvidia/cuda:12.8.0-cudnn-runtime-ubuntu24.04

# Set DEBIAN_FRONTEND to noninteractive to avoid prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive

# Install essential system packages + build tools (for bitsandbytes/sageattention if needed)
RUN apt-get update --assume-yes && \
    apt-get install --assume-yes --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3-pip \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    build-essential \
    cmake && \
    # Clean up apt lists to reduce image size
    rm -rf /var/lib/apt/lists/*

# Create python venv
RUN python3.12 -m venv /opt/comfypython
ENV VIRTUAL_ENV=/opt/comfypython
ENV PATH="/opt/comfypython/bin:$PATH"

# Upgrade pip within the venv
RUN pip install --upgrade pip

# Clone ComfyUI and ComfyUI-Manager
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /opt/comfyui
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git /opt/comfyui-manager

# Install base requirements (using --no-cache-dir to potentially reduce layer size)
RUN pip install --no-cache-dir -r /opt/comfyui/requirements.txt
RUN pip install --no-cache-dir -r /opt/comfyui-manager/requirements.txt

# Install correct PyTorch Nightly for CUDA 12.8 (includes compatible Triton)
RUN pip install --no-cache-dir \
    --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

# Install compatible core libraries (let pip resolve huggingface_hub)
# Using versions confirmed to work well together recently
RUN pip install --no-cache-dir \
    diffusers~=0.32.0 \
    transformers~=4.50.0 \
    huggingface_hub>=0.23.0 # Ensure version compatible with both

# Install bitsandbytes (latest version, relying on runtime LD_LIBRARY_PATH)
RUN pip install --no-cache-dir bitsandbytes

# --- SageAttention Installation ---
# Clone SageAttention repository
RUN git clone https://github.com/thu-ml/SageAttention.git /opt/sageattention && \
    cd /opt/sageattention && \
    # Check out the specific branch for sm_120 compilation fixes
    git checkout sm120_compilation && \
    # Install using the setup.py from THIS branch
    python setup.py install

# Set working directory
WORKDIR /opt/comfyui

# Expose ComfyUI port
EXPOSE 8188

# Add entrypoint script (handles symlinks and runtime environment)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Default command to run ComfyUI with SageAttention
# Env vars like LD_LIBRARY_PATH and BNB_CUDA_VERSION handled in entrypoint.sh
CMD ["python", "main.py", "--listen", "0.0.0.0", "--port", "8188", "--use-sage-attention", "--disable-auto-launch"]
