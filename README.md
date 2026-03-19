# ROS 2 Humble Docker Development Environment

A reusable Docker-based development template for **ROS 2 Humble** projects.

This repository provides a ready-to-use development environment built with **Dockerfile + Docker Compose + Makefile**, so you can quickly start a ROS 2 project without repeatedly setting up dependencies by hand.

## Features

- ROS 2 Humble development environment
- Dockerfile-based reproducible setup
- Docker Compose orchestration
- Non-root user support with UID/GID mapping
- X11 GUI forwarding support (`rviz2`, `rqt`, etc.)
- Simple daily workflow with `make` commands

## Project Structure

```text
.
├── README.md
├── .env.example
├── Makefile
├── docker-compose.yml
└── docker/
    ├── .dockerignore
    ├── Dockerfile
    └── entrypoint.sh

## Quick Start

```bash
cp .env.example .env
chmod +x docker/entrypoint.sh
make build
make up
make exec

For more details, you can expand this README with project-specific instructions.
Or visit my Blog: cherishxi.xyz
