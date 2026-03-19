#!/bin/bash
# ==============================================================
#  docker_study.sh
#
#  教学脚本：完整展示 Docker + ROS 2 开发环境的所有核心操作
#  以及每个命令"不用 Makefile / 不用 docker compose"时的等价写法
#
#  阅读方式：从上到下，每个区块都有：
#    [概念]  — 解释这一步在做什么
#    [命令]  — 实际可以执行的命令
#    [等价]  — 不用 Makefile/Compose 时裸 docker 命令写法
#
#  用法：
#    bash docker_study.sh        # 实际运行（会改变系统状态，谨慎）
#    cat docker_study.sh         # 只读不运行
# ==============================================================
set -e   # 任何命令失败立即停止

# ---------------------------------------------------------------
# 颜色输出（只是让阅读更方便）
# ---------------------------------------------------------------
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

section()  { echo -e "\n${CYAN}══════════════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}══════════════════════════════════════════════════${NC}"; }
explain()  { echo -e "${GREEN}[概念] $1${NC}"; }
equiv()    { echo -e "${YELLOW}[等价] $1${NC}"; }
cmd()      { echo -e "  \$ $1"; }

# ================================================================
# 0. 基础概念：Docker vs docker compose vs Makefile
# ================================================================
section "0. 工具层次关系"

explain "Docker Engine：底层容器运行时，提供 'docker' 命令。"
explain "docker compose：编排工具，读取 docker-compose.yml，批量管理多个容器/网络/卷。等价于把一大堆 docker run 参数写成配置文件。"
explain "Makefile：只是快捷方式，make build 实际上就是执行 docker compose build，没有任何魔法。不用 make 就是手敲背后的 docker compose / docker 命令而已。"

# ================================================================
# 1. X11 显示授权（GUI 程序转发到宿主机屏幕）
# ================================================================
section "1. X11 授权（每次重启电脑后执行一次）"

explain "容器是一个独立进程，默认没有权限连接宿主机的 X11 显示服务器（图形界面的'窗口管理器'）。xhost +local:docker 告诉 X11 服务器：允许 docker 组的连接。之后 RViz2、rqt、MuJoCo viewer 等 GUI 程序才能在宿主机屏幕上弹出窗口。"

cmd "xhost +local:docker"
equiv "就是这一条，Makefile 的 make xhost 内部就是执行这句话"

# ================================================================
# 2. 构建 Docker 镜像
# ================================================================
section "2. 构建镜像（首次或修改 Dockerfile 后执行）"

explain "构建镜像就是把 Dockerfile 里每一个 RUN/COPY/ENV 指令依次执行，生成一个可复用的'快照'（镜像）。构建只需做一次，之后 docker run / docker compose up 都直接使用这个镜像，不会重新安装包。"

explain "用 docker compose build（推荐，从 docker-compose.yml 读取所有参数）："
cmd "docker compose build"

explain "等价的裸 docker 命令（不用 compose，需要手动指定所有参数）："
cmd "docker build \\"
cmd "    --build-arg UID=\$(id -u) \\"
cmd "    --build-arg GID=\$(id -g) \\"
cmd "    --build-arg USER_NAME=developer \\"
cmd "    --tag project_name:latest \\"
cmd "    ./docker"
equiv "docker compose build 内部就是上面这条命令，compose 帮你从 docker-compose.yml 里读 build.args、context、tag"

explain "强制无缓存重建（改动了基础包/FROM 之后用）："
cmd "docker compose build --no-cache"
equiv "docker build --no-cache --build-arg UID=\$(id -u) ... --tag project_name:latest ./docker"

# ================================================================
# 3. 启动容器（后台运行）
# ================================================================
section "3. 启动容器"

explain "docker compose up -d 读取 docker-compose.yml 里的所有配置（volumes、environment、network_mode 等）并启动容器，-d 表示 detach（后台），终端不被占用。"

cmd "docker compose up -d"

explain "等价的裸 docker run 命令（你能看到 compose 帮你省了多少字）："
cmd "docker run -d \\"
cmd "    --name project_name \\"
cmd "    --network host \\"
cmd "    --ipc host \\"
cmd "    --pid host \\"
cmd "    --privileged \\"
cmd "    --user \$(id -u):\$(id -g) \\"
cmd "    --shm-size 8g \\"
cmd "    -e DISPLAY=\${DISPLAY} \\"
cmd "    -e QT_X11_NO_MITSHM=1 \\"
cmd "    -e ROS_DOMAIN_ID=0 \\"
cmd "    -e TERM=xterm-256color \\"
cmd "    -v \$(pwd):/workspace \\"
cmd "    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \\"
cmd "    -v /dev/dri:/dev/dri \\"
cmd "    --restart unless-stopped \\"
cmd "    project_name:latest"
equiv "make up 就是 xhost +local:docker && docker compose up -d，而 compose up 内部就是上面那条 docker run"

explain "参数逐一说明："
explain "  --network host    : 容器共享宿主机的网络栈，IP/端口和宿主机完全一样，ROS 2 多节点发现和通信依赖这个"
explain "  --ipc host        : 共享宿主机 IPC（进程间通信），ROS 2 大消息用共享内存传输时需要"
explain "  --pid host        : 共享宿主机 PID 空间，方便 gdb/perf 等调试工具"
explain "  --privileged      : 容器获得访问 /dev 下所有设备（GPU、传感器等）的权限"
explain "  --user \$(id -u):\$(id -g) : 以和宿主机相同的 UID/GID 运行，避免容器创建的文件在宿主机上是 root 所有"
explain "  --shm-size 8g     : 可用共享内存，ROS 2 DDS 大消息传输需要足够的 /dev/shm"
explain "  -v \$(pwd):/workspace : 把当前项目目录挂载进容器，代码改动双向实时同步"
explain "  -v /tmp/.X11-unix:... : X11 socket，GUI 程序通过它连接宿主机显示器"
explain "  --restart unless-stopped : 容器崩溃自动重启，除非你主动 docker stop"

# ================================================================
# 4. 进入容器（打开 shell）
# ================================================================
section "4. 进入运行中的容器"

explain "容器已经在后台跑了，你需要在里面打开一个 bash shell 来工作。有两种方式："

explain "方式 A：docker compose exec（推荐）— 在运行中的容器里启动一个新进程（新 shell）"
cmd "docker compose exec ros2 bash"
equiv "docker exec -it project_name bash"
explain "  这两者完全等价，exec 不会创建新容器，只是在已有容器内新开一个 bash 进程"
explain "  每次 make exec 就是执行上面其中一条，可以同时开多个终端窗口，每个都 exec 一次，互不干扰"

explain "方式 B：docker attach — 连接到容器的主进程（PID 1）"
cmd "docker attach project_name"
explain "  危险：Ctrl+C 会发送 SIGINT 给 PID 1，可能停掉容器。一般只用于查看容器主进程的输出"

# ================================================================
# 5. 环境变量：source 的含义与自动化
# ================================================================
section "5. 环境变量：为什么要 source，以及如何自动化"

explain "shell 的环境变量是进程级的，只影响当前进程及其子进程。"
explain "'source file.bash' 的作用是：在当前 shell 进程里执行 file.bash 里的命令，包括 export 语句。"
explain "所以 'source /opt/ros/humble/setup.bash' 会把 ROS 的 bin 目录加到 PATH 里，使 ros2 命令可用。"
explain "每次 docker exec 打开新 shell，前一个 shell 的环境变量不会自动继承，所以必须重新 source。"
explain ""
explain "三种自动化方式（推荐第 1 种）："

explain "方式 1：写进 ~/.bashrc（每次新 shell 自动执行）"
cmd "echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc"
cmd "echo 'if [ -f /workspace/install/setup.bash ]; then source /workspace/install/setup.bash; fi' >> ~/.bashrc"
explain "  ~/.bashrc 是 bash 的每次交互式启动脚本，写进去之后永久生效，不用再手动 source"

explain "方式 2：写进 /etc/profile.d/（系统级，所有用户的 login shell 都会执行）"
cmd "echo 'source /opt/ros/humble/setup.bash' | sudo tee /etc/profile.d/ros2.sh"
cmd "sudo chmod +x /etc/profile.d/ros2.sh"

explain "方式 3：在 Dockerfile 里写（镜像构建时就写好，所有从该镜像创建的容器都自动有）"
explain "  RUN echo 'source /opt/ros/humble/setup.bash' >> /home/developer/.bashrc"
explain "  这就是我们 Dockerfile 里已经做的事情"

explain "注意：workspace overlay（colcon build 后的 install/setup.bash）只有在 colcon build 完成后才存在，"
explain "所以不能在 Dockerfile 里 source（build 时 /workspace 是空的），只能在 ~/.bashrc 做条件 source："
explain "  if [ -f /workspace/install/setup.bash ]; then source /workspace/install/setup.bash; fi"

# ================================================================
# 6. 查看容器状态
# ================================================================
section "6. 查看容器状态与日志"

explain "查看正在运行的容器："
cmd "docker compose ps"
equiv "docker ps"
equiv "docker ps -a   # 包括已停止的容器"

explain "查看容器实时日志（Ctrl+C 退出）："
cmd "docker compose logs -f --tail=100"
equiv "docker logs -f --tail=100 project_name"
explain "  -f : follow，实时跟踪新日志"
explain "  --tail=100 : 只显示最后 100 行"

explain "查看容器内的进程："
cmd "docker compose exec ros2 ps aux"
equiv "docker exec project_name ps aux"

explain "查看容器的完整配置（网络、挂载、环境变量等）："
cmd "docker inspect project_name"

# ================================================================
# 7. 停止和删除
# ================================================================
section "7. 停止与清理"

explain "停止容器（保留镜像和 volumes）："
cmd "docker compose down"
equiv "docker stop project_name && docker rm project_name"
explain "  compose down 会停止+删除容器，但不删镜像和 volumes（数据不丢）"
explain "  docker stop 只停止，docker rm 才删除容器进程，两步等价于 compose down"

explain "停止并删除 volumes（清除持久化数据）："
cmd "docker compose down -v"
equiv "docker stop project_name && docker rm project_name && docker volume rm project_name_bash_history project_name_colcon_cache"

explain "完全清除（删容器+volumes+本项目镜像）："
cmd "docker compose down -v --rmi local"
equiv "docker stop project_name; docker rm project_name; docker volume rm \$(docker volume ls -q | grep project_name); docker rmi project_name:latest"

explain "查看系统中所有 Docker 对象占用的空间："
cmd "docker system df"
explain "清理所有未使用的容器/镜像/networks（谨慎，会删其他项目的）："
cmd "docker system prune -a"

# ================================================================
# 8. ROS 2 + colcon 常用操作
# ================================================================
section "8. ROS 2 + colcon 工作流（在容器内执行）"

explain "在 /workspace 目录（或子目录）里构建 ROS 2 包："
cmd "colcon build --symlink-install"
explain "  --symlink-install : 不复制 Python 文件，建符号链接，改完代码不用重新 build 立刻生效（仅 Python 包有效）"

explain "只构建特定包（加快速度）："
cmd "colcon build --symlink-install --packages-select pnd_adam"

explain "构建完成后必须 source overlay 才能 import 到新包："
cmd "source install/setup.bash"

explain "查看当前有哪些 ROS 话题（需要有节点在运行）："
cmd "ros2 topic list"
explain "查看某话题的发布者/订阅者/QoS："
cmd "ros2 topic info /lowstate"
explain "查看某话题的实时消息内容："
cmd "ros2 topic echo /lowstate"
explain "查看某话题的发布频率："
cmd "ros2 topic hz /lowcmd"
explain "查看当前运行的节点："
cmd "ros2 node list"
explain "发布一条测试消息（验证 DDS 通信）："
cmd "ros2 topic pub /test std_msgs/msg/String \"data: 'hello'\" -r 1"

# ================================================================
# 9. 调试工具
# ================================================================
section "9. 调试工具（容器内）"

explain "查看 Python 路径（诊断 import 失败）："
cmd "python3 -c \"import sys; print('\\n'.join(sys.path))\""

explain "查看某个包是否能 import："
cmd "python3 -c \"import pnd_adam; print('OK:', pnd_adam.__file__)\""

explain "查看环境变量（诊断 ROS 通信问题）："
cmd "echo ROS_DOMAIN_ID=\$ROS_DOMAIN_ID"
cmd "echo RMW_IMPLEMENTATION=\${RMW_IMPLEMENTATION:-<unset>}"
cmd "echo AMENT_PREFIX_PATH=\$AMENT_PREFIX_PATH"
cmd "echo PYTHONPATH=\$PYTHONPATH"

explain "查看 GPU/OpenGL 是否可用（诊断 rviz2/mujoco viewer 黑屏）："
cmd "glxinfo | grep 'OpenGL renderer'"

explain "在容器内实时看资源占用："
cmd "htop"

echo ""
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}  阅读完毕。以上命令均可直接在终端中单独执行。${NC}"
echo -e "${GREEN}  Makefile 只是把最常用的组合打包成短别名，${NC}"
echo -e "${GREEN}  没有任何不能被裸 docker / docker compose 命令替代的功能。${NC}"
echo -e "${GREEN}=====================================================${NC}"
