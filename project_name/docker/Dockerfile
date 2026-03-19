# ==============================================================
#  ROS 2 Humble Development Container
#  Template — reusable for any ROS 2 project
# ==============================================================
FROM osrf/ros:humble-desktop

# Fail fast on errors & avoid interactive prompts
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# ---- System packages ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    # --- Python build essentials ---
    python3-pip \
    python3-dev \
    python3-numpy \
    python3-colcon-common-extensions \
    python3-pytest \
    # --- General dev tools ---
    git \
    curl \
    wget \
    vim \
    nano \
    tmux \
    htop \
    tree \
    unzip \
    lsb-release \
    software-properties-common \
    # --- Build toolchain ---
    build-essential \
    cmake \
    gdb \
    ninja-build \
    pkg-config \
    # --- Networking & debugging ---
    net-tools \
    iproute2 \
    iputils-ping \
    dnsutils \
    # --- X11 / OpenGL (for GUI: rviz2, rqt, mujoco viewer …) ---
    libgl1-mesa-glx \
    libegl1-mesa \
    libxrender1 \
    libxext6 \
    libsm6 \
    libx11-6 \
    libxcb1 \
    mesa-utils \
    # --- Common C++ libs often needed in robotics projects ---
    libyaml-cpp-dev \
    libspdlog-dev \
    libboost-all-dev \
    libeigen3-dev \
    # --- ROS 2 specific ---
    ros-humble-rmw-cyclonedds-cpp \
    ros-humble-rosidl-generator-dds-idl \
    ros-humble-teleop-twist-keyboard \
    ros-humble-rqt \
    ros-humble-rqt-common-plugins \
    ros-humble-rviz2 \
    python3-rosdep \
    python3-vcstool \
    python3-argcomplete \
    # --- Shell quality-of-life ---
    bash-completion \
    && rm -rf /var/lib/apt/lists/*

# ---- pip packages ----
# numpy must be installed before colcon build (rosidl C extensions need ndarrayobject.h)
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel \
    && python3 -m pip install --no-cache-dir numpy

# ---- Create non-root user (mapped to host UID/GID) ----
ARG UID=1000
ARG GID=1000
ARG USER_NAME=developer

RUN groupadd --gid ${GID} ${USER_NAME} 2>/dev/null || true \
    && useradd --uid ${UID} --gid ${GID} -m -s /bin/bash ${USER_NAME} \
    && echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Give the user ownership of common ROS dirs
RUN mkdir -p /home/${USER_NAME}/.ros && chown -R ${UID}:${GID} /home/${USER_NAME}

# Ensure ROS environment is available for all shells (login and non-login)
# - /etc/profile.d/ros2.sh is picked up by login shells
# - append to user's .bashrc so `docker exec bash` (non-login interactive) also gets it
RUN echo 'source /opt/ros/humble/setup.bash' > /etc/profile.d/ros2.sh \
    && echo 'if [ -f /opt/ros/humble/setup.bash ]; then source /opt/ros/humble/setup.bash; fi' >> /home/${USER_NAME}/.bashrc \
    && chown ${UID}:${GID} /home/${USER_NAME}/.bashrc \
    && chmod +x /etc/profile.d/ros2.sh

# ---- Entrypoint ----
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER ${USER_NAME}
WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]