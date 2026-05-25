FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# cmake
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gnupg \
    wget \
    lsb-release \
    && wget -qO - https://apt.kitware.com/keys/kitware-archive-latest.asc \
        | gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main" \
        > /etc/apt/sources.list.d/kitware.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends cmake

# Build tools and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    build-essential \
    git \
    pkg-config \
    gdb \
    ninja-build \
    wayland-protocols

# TEMP - REMOVE ME - used for testing why we can't use the nvidia device in this container.
RUN apt-get install -y --no-install-recommends \
    mesa-vulkan-drivers

# GCC 13
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    g++-13

# LLVM
RUN wget -qO /tmp/llvm.sh https://apt.llvm.org/llvm.sh \
    && chmod +x /tmp/llvm.sh \
    && /tmp/llvm.sh 22 all \
    && rm /tmp/llvm.sh

# SDL dependencies
RUN apt-get install -y --no-install-recommends \
    make \
    gnome-desktop-testing libasound2-dev libpulse-dev \
    libaudio-dev libfribidi-dev libjack-dev libsndio-dev libx11-dev libxext-dev libx11-xcb-dev \
    libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev libxss-dev libxtst-dev \
    libxkbcommon-dev libdrm-dev libgbm-dev libgl1-mesa-dev libgles2-mesa-dev \
    libegl1-mesa-dev libdbus-1-dev libibus-1.0-dev libudev-dev libthai-dev libusb-1.0-0-dev \
    libpipewire-0.3-dev libwayland-dev libdecor-0-dev liburing-dev

# Vulkan dependencies
RUN apt-get install -y --no-install-recommends \
    libvulkan1 \
    libvulkan-dev \
    vulkan-tools

ARG VULKAN_HEADERS_TAG=vulkan-sdk-1.4.350.0

RUN git clone --depth 1 --branch ${VULKAN_HEADERS_TAG} \
    https://github.com/KhronosGroup/Vulkan-Headers.git /tmp/Vulkan-Headers \
    && cmake -S /tmp/Vulkan-Headers -B /tmp/Vulkan-Headers/build \
        -DCMAKE_INSTALL_PREFIX=/opt/vulkan-headers \
    && cmake --install /tmp/Vulkan-Headers/build \
    && rm -rf /tmp/Vulkan-Headers

ENV CMAKE_PREFIX_PATH=/opt/vulkan-headers:${CMAKE_PREFIX_PATH}

# GLFW dependencies (for Dawn)
#RUN apt-get install -y --no-install-recommends \
#    libxinerama-dev

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME} -s /bin/bash \
    && apt-get update \
    && apt-get install -y --no-install-recommends sudo \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*