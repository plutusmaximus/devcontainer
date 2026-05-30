#FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04@sha256:517da2300c184c9999ec203c2665244bdebd3578d12fcc7065e83667932643d9

FROM ubuntu:26.04

# cmake
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    ca-certificates \
    gnupg \
    wget \
    lsb-release \
    && . /etc/os-release \
    && wget -qO - https://apt.kitware.com/keys/kitware-archive-latest.asc \
        | gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ ${UBUNTU_CODENAME} main" \
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
    && . /etc/os-release \
    && echo "deb [signed-by=/usr/share/keyrings/llvm-archive-keyring.gpg] http://apt.llvm.org/${UBUNTU_CODENAME}/ llvm-toolchain-${UBUNTU_CODENAME}-22 main" \
        > /etc/apt/sources.list.d/llvm.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        llvm-22 \
        clang-22 \
        lldb-22 \
        lld-22 \
        clangd-22 \
    && LLVM_VERSION_CHECK="$(llvm-config-22 --version | cut -d. -f1)" \
    && if [ "${LLVM_VERSION_CHECK}" != "22" ]; then \
        echo "ERROR: LLVM 22 is required, but llvm-config-22 reports ${LLVM_VERSION_CHECK}."; \
        exit 1; \
    fi \
    && rm -rf /var/lib/apt/lists/*

ARG VULKAN_HEADERS_TAG=vulkan-sdk-1.4.350.0

RUN git clone --depth 1 --branch ${VULKAN_HEADERS_TAG} \
    https://github.com/KhronosGroup/Vulkan-Headers.git /tmp/Vulkan-Headers \
    && cmake -S /tmp/Vulkan-Headers -B /tmp/Vulkan-Headers/build \
        -DCMAKE_INSTALL_PREFIX=/opt/vulkan-headers \
    && cmake --install /tmp/Vulkan-Headers/build \
    && rm -rf /tmp/Vulkan-Headers

ENV CMAKE_PREFIX_PATH=/opt/vulkan-headers

# GLFW dependencies (for Dawn)
#RUN apt-get install -y --no-install-recommends \
#    libxinerama-dev

# Adde users/groups for vscode devcontainer and for accessing the display server with the same UID/GID as the host user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

RUN apt-get update \
    && apt-get install -y --no-install-recommends sudo \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /etc/sudoers.d \
    && EXISTING_GROUP_BY_GID="$(getent group ${USER_GID} | cut -d: -f1 || true)" \
    && if getent group ${USERNAME} > /dev/null; then \
        USER_GROUP="${USERNAME}"; \
    elif [ -n "${EXISTING_GROUP_BY_GID}" ]; then \
        groupmod -n ${USERNAME} "${EXISTING_GROUP_BY_GID}"; \
        USER_GROUP="${USERNAME}"; \
    else \
        groupadd --gid ${USER_GID} ${USERNAME}; \
        USER_GROUP="${USERNAME}"; \
    fi \
    && EXISTING_USER_BY_UID="$(getent passwd ${USER_UID} | cut -d: -f1 || true)" \
    && if id -u ${USERNAME} > /dev/null 2>&1; then \
        echo "User ${USERNAME} already exists"; \
    elif [ -n "${EXISTING_USER_BY_UID}" ]; then \
        usermod -l ${USERNAME} -d /home/${USERNAME} -m -g "${USER_GROUP}" -s /bin/bash "${EXISTING_USER_BY_UID}"; \
    else \
        useradd --uid ${USER_UID} --gid "${USER_GROUP}" -m ${USERNAME} -s /bin/bash; \
    fi \
    && if [ "$(id -u ${USERNAME})" != "${USER_UID}" ] && ! getent passwd ${USER_UID} > /dev/null; then \
        usermod --uid ${USER_UID} ${USERNAME}; \
    fi \
    && usermod --gid "${USER_GROUP}" -s /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*