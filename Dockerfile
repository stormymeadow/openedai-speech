FROM python:3.11-slim

RUN pip install -U pip

ARG TARGETPLATFORM
RUN apt-get update && apt-get install --no-install-recommends -y curl ffmpeg wget
RUN if [ "$TARGETPLATFORM" != "linux/amd64" ]; then apt-get install --no-install-recommends -y build-essential ; fi
RUN if [ "$TARGETPLATFORM" != "linux/amd64" ]; then curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y ; fi
ENV PATH="/root/.cargo/bin:${PATH}"
# for deepspeed support - doesn't seem worth it, image +7.5GB, over the 10GB ghcr.io limit, and no noticable gain in speed or VRAM usage?
#RUN curl -O https://developer.download.nvidia.com/compute/cuda/repos/debian11/x86_64/cuda-keyring_1.1-1_all.deb
#RUN dpkg -i cuda-keyring_1.1-1_all.deb && rm cuda-keyring_1.1-1_all.deb
#RUN apt-get update && apt-get install --no-install-recommends -y libaio-dev build-essential cuda-toolkit
#ENV CUDA_HOME=/usr/local/cuda

RUN wget https://repo.radeon.com/amdgpu-install/6.1.3/ubuntu/jammy/amdgpu-install_6.1.60103-1_all.deb
RUN yes Y | apt-get install -y ./amdgpu-install_6.1.60103-1_all.deb && apt update
RUN apt-get install -y $(apt-cache depends rocm | tail -n +2 | sed "s/Depends://g" | grep -v rocm-developer-tools)
RUn apt-get install -y $(apt-cache depends rocm-developer-tools | tail -n +2 | sed "s/Depends://g" | grep -vE "tracer|debug|gdb|dbg|profile")

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN mkdir -p voices config

ARG USE_ROCM
ENV USE_ROCM=${USE_ROCM}

COPY requirements*.txt /app/
RUN if [ "${USE_ROCM}" = "1" ]; then mv /app/requirements-rocm.txt /app/requirements.txt; fi
RUN pip install --index-url https://download.pytorch.org/whl/rocm5.7 -r requirements-rocm-torch.txt 
RUN pip install -r requirements.txt 

COPY *.py *.sh *.default.yaml README.md LICENSE /app/

ARG PRELOAD_MODEL
ENV PRELOAD_MODEL=${PRELOAD_MODEL}
ENV TTS_HOME=voices
ENV HF_HOME=voices
ENV COQUI_TOS_AGREED=1
ENV HSA_OVERRIDE_GFX_VERSION=11.0.0

CMD bash startup.sh
