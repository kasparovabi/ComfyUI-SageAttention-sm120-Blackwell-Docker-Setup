#!/bin/bash
source /opt/comfypython/bin/activate
export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64:${LD_LIBRARY_PATH}
unset BNB_CUDA_VERSION
mkdir -p /opt/comfyui/custom_nodes
if [ ! -L "/opt/comfyui/custom_nodes/ComfyUI-Manager" ]; then
  ln -s /opt/comfyui-manager /opt/comfyui/custom_nodes/ComfyUI-Manager
  echo "ComfyUI-Manager symlinked."
fi
exec "$@"
