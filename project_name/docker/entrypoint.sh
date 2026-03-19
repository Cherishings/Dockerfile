#!/bin/bash
# ==============================================================
#  Container entrypoint — sources ROS and runs the user command
# ==============================================================
set -e

# Source ROS 2 base setup
source /opt/ros/humble/setup.bash

# Source workspace overlay if it exists (after colcon build)
if [ -f /workspace/install/setup.bash ]; then
    source /workspace/install/setup.bash
    echo "[entrypoint] Sourced workspace overlay (/workspace/install/setup.bash)"
fi

echo "[entrypoint] ROS_DISTRO=$ROS_DISTRO  ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}"

# Execute the CMD passed to the container (default: bash)
exec "$@"
