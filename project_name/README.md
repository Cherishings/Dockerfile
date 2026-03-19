# ROS 2 Humble Docker 开发环境

> 本模板为工程级 Docker 开发环境，适用于 ROS 2 Humble 项目。  
> 配置一次，之后对着本文件操作即可开箱即用。

---

## 目录

1. [项目结构](#1-项目结构)
2. [文件说明](#2-文件说明)
3. [前置要求](#3-前置要求)
4. [首次使用完整流程](#4-首次使用完整流程)
5. [日常开发工作流](#5-日常开发工作流)
6. [Make 命令速查表](#6-make-命令速查表)
7. [复用模板到新项目](#7-复用模板到新项目)
8. [常见问题](#8-常见问题)

---

## 1. 项目结构

```
project_name/
├── README.md               ← 本文件
├── .env                    ← 环境变量（UID、GID、ROS_DOMAIN_ID 等）
├── Makefile                ← 快捷命令（make build / up / exec / down …）
├── docker-compose.yml      ← Docker Compose 编排文件
└── docker/
    ├── .dockerignore       ← 构建上下文排除规则
    ├── Dockerfile          ← 镜像定义文件
    └── entrypoint.sh       ← 容器启动入口脚本
```

---

## 2. 文件说明

### `.env`
Docker Compose 会在启动时**自动读取**同目录下的 `.env` 文件，不需要手动 source。  
其中定义的变量会在 `docker-compose.yml` 中以 `${变量名}` 方式引用。

| 变量 | 含义 | 默认值 |
|------|------|--------|
| `UID` | 宿主机用户的 User ID | `1000` |
| `GID` | 宿主机用户的 Group ID | `1000` |
| `USER_NAME` | 容器内用户名 | `developer` |
| `ROS_DOMAIN_ID` | ROS 2 网络域 ID，同一局域网多台机器用不同值以隔离 | `0` |
| `DISPLAY` | X11 显示变量，用于 GUI 转发（rviz2、rqt 等） | 继承宿主机 `$DISPLAY` |
| `COMPOSE_PROJECT_NAME` | Compose 项目名，影响容器/卷/网络名前缀 | `project_name` |

> **为什么要映射 UID/GID？**  
> 默认情况下容器内是 root 用户，在 `/workspace` 创建的文件到宿主机上会显示为 root 所有，无法直接编辑。  
> 通过把容器内用户的 UID/GID 设置为与宿主机相同，容器创建的文件在宿主机上就像普通用户创建的一样，不会有权限问题。

---

### `docker-compose.yml`
定义如何启动容器，包括：镜像来源、网络模式、挂载目录、环境变量等。

**关键配置说明：**

```yaml
build:
  args:
    UID: ${UID:-1000}      # 把 .env 里的 UID 传给 Dockerfile 的 ARG，用于创建非 root 用户
    GID: ${GID:-1000}
    USER_NAME: ${USER_NAME:-developer}

image: project_name:latest        # 构建后给镜像打 tag，下次 up 时如果镜像已存在就直接用，不重新构建

network_mode: host         # 容器共享宿主机的网络，适合 ROS 2 多节点通信
ipc: host                  # 共享宿主机的进程间通信（IPC），适合共享内存通信
pid: host                  # 共享宿主机 PID 空间，方便 Debug 时看到宿主机进程

privileged: true           # 容器有完整硬件访问权限，访问 /dev 下的 GPU、传感器等必须开启
user: "${UID:-1000}:..."   # 以非 root 用户身份运行容器（搭配 UID/GID 映射）

shm_size: 8g               # 共享内存大小，ROS 2 大量使用共享内存传输数据，建议 >= 2g

volumes:
  - ./:/workspace          # 把当前项目目录挂载到容器内 /workspace，宿主机和容器共享代码
  - /tmp/.X11-unix:/tmp/.X11-unix:rw   # X11 socket，用于 GUI 程序转发到宿主机显示器
  - /dev/dri:/dev/dri      # GPU 设备，用于 OpenGL / RViz2 硬件加速

restart: unless-stopped    # 容器崩溃后自动重启，但 docker compose down 后不自动启动
```

---

### `docker/Dockerfile`
描述如何**构建镜像**，镜像只在 `make build` 时构建一次，之后 `make up` 直接使用。

**关键步骤说明：**

```dockerfile
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# 开启 pipefail：管道命令中任意一步失败，整个 RUN 指令就报错并停止构建。
# 避免错误被静默忽略。

ENV DEBIAN_FRONTEND=noninteractive
# 安装包时不出现交互式提示（如"是否继续？"），保证构建不卡住。

RUN apt-get update && apt-get install -y --no-install-recommends \
    ...
    && rm -rf /var/lib/apt/lists/*
# --no-install-recommends：只装必要依赖，不装推荐包，减小镜像体积。
# rm -rf /var/lib/apt/lists/*：删除 apt 缓存，进一步减小镜像体积。
# 注意：用 apt-get 而不是 apt，因为 apt 在非交互环境会打印 warning。

ARG UID=1000
ARG GID=1000
ARG USER_NAME=developer
RUN groupadd ... && useradd ...
# 在镜像内创建与宿主机 UID/GID 相同的用户，解决文件权限问题。

RUN chmod +x /entrypoint.sh
# 给 entrypoint.sh 设置可执行权限。
# 这一步在 Dockerfile 里已经做了，所以镜像构建后容器里一定有执行权限。
# （在宿主机上也 chmod +x 是为了保证文件在 git 里有可执行位记录。）

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
# ENTRYPOINT 是每次容器启动都会运行的脚本（source ROS 环境等）。
# CMD 是传给 ENTRYPOINT 的默认参数，这里是 bash，即默认打开一个 shell。
```

---

### `docker/entrypoint.sh`
容器每次启动时**第一个执行**的脚本，在打开 bash 之前自动完成环境初始化。

```bash
source /opt/ros/humble/setup.bash
# source ROS 2 的基础环境变量，使 ros2 命令可用。

if [ -f /workspace/install/setup.bash ]; then
    source /workspace/install/setup.bash
fi
# 如果你已经 colcon build 过，source 你自己的 workspace overlay，
# 使你写的功能包的命令和话题都可以找到。

exec "$@"
# 执行传入的命令（默认是 bash）。
# exec 替换当前进程，使容器的 PID 1 就是你的命令，信号处理更正确。
```

---

### `Makefile`
封装了常用的 Docker 命令，避免每次手敲长命令。  
`make` 本质上是在执行 `docker compose` 命令，只是加了固定参数和依赖关系。

---

### `docker/.dockerignore`
告诉 Docker 构建时**不要把**哪些文件发送到构建上下文（build context）。  
排除 `.git`、`build/`、`install/` 等大目录，可以显著加快构建速度。

---

### 关于 `.env` 与 `.dockerignore`（上传 / 发布 时的注意事项）

- **不要把真实 `.env` 提交到仓库。** `.env` 通常包含主机特有或敏感信息（UID/GID、显示配置或 secret）。为此仓库提供了一个可提交的模板文件：`.env.example`，使用时复制并修改：

```bash
cp .env.example .env
# 编辑 .env 里的值为你的宿主机设置
```

- **使用 `.gitignore` 忽略 `.env`。** 我已在仓库根目录添加了 `.gitignore`，包含 `.env`、构建产物和常见编辑器临时文件，确保 `.env` 不会被意外推送到远程仓库。

- **关于 `.dockerignore` 的位置：** Docker 使用的 `.dockerignore` 必须放在构建上下文的根目录。当前 `docker-compose.yml` 的 `build.context` 指向 `./docker`，因此用于构建的忽略规则位于 `docker/.dockerignore`（已存在）。如果你改变了 build context（例如把上下文改为项目根 `.`），请在相应上下文根创建 `.dockerignore` 并加入 `.env`、`build/`、`install/` 等条目，避免把敏感信息或大文件发送给 Docker daemon。

- **在 CI / Docker Hub 构建时的建议：** 不要把 `.env` 放到远程仓库。对于需要的秘密或环境变量，应使用 CI 的 Secrets、Repository variables 或在构建时通过 `--build-arg`/runtime env 注入。这样既安全又可复现构建。

---


---

## 3. 前置要求

在宿主机上确认以下工具已安装：

```bash
# 检查 Docker
docker --version          # 需要 Docker Engine 20.10+

# 检查 Docker Compose（V2，命令是 docker compose 而不是 docker-compose）
docker compose version    # 需要 Compose V2

# 检查 make
make --version
```

如果没有 `make`：
```bash
sudo apt-get install make
```

---

## 4. 首次使用完整流程

> 按顺序执行，每一步都解释了在做什么。

### 步骤 1：进入项目目录

```bash
cd ~/project_name
```

### 步骤 2：确认 `.env` 里的 UID/GID 和你的宿主机匹配

```bash
# 查看你宿主机的 UID 和 GID
id -u    # 输出你的 UID（通常是 1000）
id -g    # 输出你的 GID（通常是 1000）
```

打开 `.env` 文件，确认 `UID` 和 `GID` 与上面命令的输出一致。  
如果不一致，修改 `.env` 里的值。

```bash
cat .env
```

### 步骤 3：给 entrypoint.sh 设置可执行权限（只需做一次）

```bash
chmod +x docker/entrypoint.sh
```

**为什么要做这一步：**  
`entrypoint.sh` 是一个 shell 脚本，Linux 下运行脚本必须有执行权限（`x` 位）。  
虽然 Dockerfile 里已经有 `RUN chmod +x /entrypoint.sh`（镜像构建时会设置），  
但在宿主机上也设置可执行位是为了让 git 记录这个权限（`git` 会追踪文件的可执行位），  
这样其他人克隆你的仓库后不需要再手动 `chmod`。

验证权限（应该看到 `-rwxr-xr-x`，x 代表可执行）：
```bash
ls -l docker/entrypoint.sh
# 正确输出示例：-rwxr-xr-x 1 user user 498 Mar  3 12:00 docker/entrypoint.sh
```

### 步骤 4：构建 Docker 镜像

```bash
make build
```

**这个命令在做什么：**  
执行 `docker compose build`，读取 `docker-compose.yml` 里的 `build.context`（即 `./docker` 目录），  
把 `docker/` 目录下的所有文件打包发送给 Docker daemon，  
然后逐行执行 `Dockerfile`，最终生成一个名为 `project_name:latest` 的镜像。

**耗时：** 首次构建约 5-15 分钟（需要下载 ROS base 镜像和安装包）。  
后续如果 Dockerfile 没有改动，直接 `make up` 即可，不需要重新构建。

构建完成后验证镜像存在：
```bash
docker images | grep project_name
# 应该看到：project_name   latest   <hash>   <size>
```

### 步骤 5：启动容器

```bash
make up
```

**这个命令在做什么：**  
1. 先执行 `xhost +local:docker`：允许 Docker 容器访问宿主机的 X11 显示服务器（这样 rviz2、rqt 等 GUI 程序可以显示在你的屏幕上）。每次重启电脑后都需要这一步，`make up` 会自动帮你做。  
2. 然后执行 `docker compose up -d`：以**后台（detach）模式**启动容器。`-d` 表示容器在后台运行，你的终端不会被占用。

验证容器正在运行：
```bash
make ps
# 或
docker ps | grep project_name
# 应该看到容器状态为 Up
```

### 步骤 6：进入容器的 bash shell

```bash
make exec
```

**这个命令在做什么：**  
执行 `docker compose exec ros2 bash`，在**已经运行的容器**里开启一个新的 bash shell。  
注意：每次运行 `make exec` 都是开一个**新的 shell 会话**，不会启动新容器。

进入后你会看到类似：
```
[entrypoint] ROS_DISTRO=humble  ROS_DOMAIN_ID=0
developer@your-hostname:~/workspace$
```
这说明：
- `entrypoint.sh` 已经自动 source 了 ROS 环境
- 你现在是 `developer` 用户（非 root），和宿主机 UID 相同
- 当前目录是 `/workspace`，对应宿主机的项目根目录

验证 ROS 环境已就绪：
```bash
ros2 topic list    # 应该有输出，没有报 command not found 就是正常的
echo $ROS_DISTRO   # 应该输出 humble
```

---

## 5. 日常开发工作流

### 每天开始工作

```bash
cd ~/project_name

# 如果容器没有运行（重启电脑后）
make up

# 进入容器
make exec
```

### 开多个终端窗口

每个新终端窗口里都执行：
```bash
cd ~/project_name && make exec
```
每次 `make exec` 开一个独立的 bash session，互不干扰，ROS 环境都已自动 source。

### 在容器内构建 ROS 包

```bash
# 在容器内
cd /workspace
colcon build --symlink-install

# 构建完成后，entrypoint.sh 下次启动会自动 source install/setup.bash
# 当前 session 需要手动 source 一次：
source install/setup.bash
```

### 停止容器

```bash
# 在宿主机终端
make down
```

**这个命令在做什么：**  
执行 `docker compose down`，停止并删除容器（但不删除镜像和 volumes）。  
下次 `make up` 会重新创建容器，挂载同样的目录，代码不会丢失。

### 重启容器

```bash
make restart
```

等同于先 `make down` 再 `make up`。

---

## 6. Make 命令速查表

| 命令 | 实际执行的命令 | 说明 |
|------|--------------|------|
| `make help` | — | 显示所有可用命令 |
| `make build` | `docker compose build` | 构建镜像（首次或改了 Dockerfile 后使用） |
| `make rebuild` | `docker compose build --no-cache` | 完全重建镜像，不使用缓存，强制重新下载所有包 |
| `make up` | `xhost +local:docker` + `docker compose up -d` | 允许 X11 转发，然后后台启动容器 |
| `make down` | `docker compose down` | 停止并删除容器（保留镜像和 volumes） |
| `make restart` | `make down` + `make up` | 重启容器 |
| `make exec` | `docker compose exec ros2 bash` | 在运行中的容器内打开新的 bash shell |
| `make attach` | `docker attach project_name` | 连接到容器的主进程（退出会停止容器，谨慎使用） |
| `make logs` | `docker compose logs -f --tail=100` | 实时查看容器输出日志（Ctrl+C 退出） |
| `make ps` | `docker compose ps` | 查看容器运行状态 |
| `make clean` | `docker compose down -v --rmi local` | **彻底清理**：删除容器、volumes 和镜像（需要重新 build）|
| `make xhost` | `xhost +local:docker` | 允许容器访问 X11（重启电脑后如果 GUI 无法显示时手动运行）|

---

## 7. 复用模板到新项目

把这 5 个文件复制到新项目，修改以下内容：

**第 1 步：改项目名**

`.env` 文件：
```
COMPOSE_PROJECT_NAME=你的新项目名
```

**第 2 步：改容器名和镜像名**

`docker-compose.yml` 文件：
```yaml
image: 你的新项目名:latest
container_name: 你的新项目名
```

同时修改 volumes 部分的卷名（避免和其他项目冲突）：
```yaml
volumes:
  - 你的新项目名_bash_history:/home/${USER_NAME:-developer}/.bash_history_dir
  - 你的新项目名_colcon_cache:/workspace/build

volumes:
  你的新项目名_bash_history:
  你的新项目名_colcon_cache:
```

**第 3 步：改 Makefile 里的容器名**

`Makefile` 文件，找到这一行：
```makefile
attach: ## Attach to the main container process
	docker attach project_name
```
改为：
```makefile
attach: ## Attach to the main container process
	docker attach 你的新项目名
```

**第 4 步：重新 chmod + build**

```bash
chmod +x docker/entrypoint.sh
make build
```

---

## 8. 常见问题

### GUI 程序打不开（rviz2、rqt 报错 "cannot connect to X server"）

在宿主机执行：
```bash
xhost +local:docker
```
然后重新进入容器。  
`make up` 会自动执行此命令，但有时宿主机重启后需要再次执行。

### 容器内创建的文件在宿主机上是 root 所有

说明 `.env` 里的 `UID`/`GID` 与宿主机不匹配。  
检查和修复：
```bash
id -u   # 查看宿主机 UID
id -g   # 查看宿主机 GID
# 修改 .env 里对应的值后重新 make build
```

### 改了 Dockerfile 后如何生效

```bash
make build     # 有缓存，只重新执行改动后的层，速度较快
# 或
make rebuild   # 完全不用缓存，从头构建，速度慢但最干净
```

### 想完全重置，从零开始

```bash
make clean     # 删除容器、volumes 和镜像
make build     # 重新构建
make up        # 重新启动
```

### 查看容器里安装了什么

```bash
make exec
# 进入容器后
pip list
dpkg -l | grep ros
```

### 容器启动后如何确认 ROS 环境正常

```bash
make exec
ros2 --version          # 显示 ROS 2 版本
echo $ROS_DISTRO        # 应输出 humble
ros2 topic list         # 列出当前话题（没有节点运行时可能为空，但不应报错）
```

---

## 附：完整首次使用命令流

```bash
cd ~/project_name
id -u && id -g            # 确认 UID/GID，对照 .env
chmod +x docker/entrypoint.sh   # 设置脚本可执行权限（只需一次）
make build                # 构建镜像（首次约 5-15 分钟）
make up                   # 启动容器
make exec                 # 进入容器
```
