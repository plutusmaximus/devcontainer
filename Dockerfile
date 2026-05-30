#FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04@sha256:517da2300c184c9999ec203c2665244bdebd3578d12fcc7065e83667932643d9

FROM ubuntu:26.04

# cmake
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    gnupg \
    wget \
    lsb-release \
    && wget -qO - https://apt.kitware.com/keys/kitware-archive-latest.asc \
        | gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main" \
        > /etc/apt/sources.list.d/kitware.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends cmake \
    && rm -rf /var/lib/apt/lists/*

# Build tools and dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    software-properties-common \
    build-essential \
    git \
    pkg-config \
    gdb \
    ninja-build \
    wayland-protocols \
    && rm -rf /var/lib/apt/lists/*

# Mesa/Vulkan runtime tools
RUN apt-get update \
    && add-apt-repository -y ppa:kisak/kisak-mesa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    mesa-utils \
    vulkan-tools \
    mesa-vulkan-drivers \
    && rm -rf /var/lib/apt/lists/*

# GCC 13
RUN apt-get update \
    && add-apt-repository -y ppa:ubuntu-toolchain-r/test \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    g++-13 \
    && rm -rf /var/lib/apt/lists/*

# SDL dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    make \
    gnome-desktop-testing libasound2-dev libpulse-dev \
    libaudio-dev libfribidi-dev libjack-dev libsndio-dev libx11-dev libxext-dev libx11-xcb-dev \
    libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev libxss-dev libxtst-dev \
    libxkbcommon-dev libdrm-dev libgbm-dev libgl1-mesa-dev libgles2-mesa-dev \
    libegl1-mesa-dev libdbus-1-dev libibus-1.0-dev libudev-dev libthai-dev libusb-1.0-0-dev \
    libpipewire-0.3-dev libwayland-dev libdecor-0-dev liburing-dev \
    && rm -rf /var/lib/apt/lists/*

# Vulkan libs
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libvulkan1 \
    libvulkan-dev \
    && rm -rf /var/lib/apt/lists/*

# LLVM
RUN wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/llvm-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/llvm-archive-keyring.gpg] http://apt.llvm.org/jammy/ llvm-toolchain-jammy-22 main" \
        > /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    llvm-22 \
    clang-22 \
    lldb-22 \
    lld-22 \
    clangd-22 \
    && rm -rf /var/lib/apt/lists/*

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

RUN apt-get update \
    && apt-get install -y --no-install-recommends sudo \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/sudoers.d \
    && if getent group ${USERNAME} > /dev/null; then \
        echo "Group ${USERNAME} already exists"; \
    elif getent group ${USER_GID} > /dev/null; then \
        echo "Group with GID ${USER_GID} already exists; reusing it"; \
    else \
        groupadd --gid ${USER_GID} ${USERNAME}; \
    fi \
    && USER_GROUP="${USERNAME}" \
    && if ! getent group "${USER_GROUP}" > /dev/null; then \
        USER_GROUP="$(getent group ${USER_GID} | cut -d: -f1)"; \
    fi \
    && if id -u ${USERNAME} > /dev/null 2>&1; then \
        echo "User ${USERNAME} already exists"; \
    else \
        useradd --uid ${USER_UID} --gid "${USER_GROUP}" -m ${USERNAME} -s /bin/bash; \
    fi \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*