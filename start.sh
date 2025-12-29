#!/bin/bash
set -e

# Configuration
MIN_SPACE_GB=10
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Claude Code Docker-in-Docker Setup ==="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo "ERROR: Docker Compose is not available. Please install Docker Compose plugin."
    exit 1
fi

# Check disk space
echo "Checking disk space..."
MOUNT_POINT=$(df "$SCRIPT_DIR" | tail -1 | awk '{print $6}')
AVAIL_KB=$(df "$SCRIPT_DIR" | tail -1 | awk '{print $4}')
AVAIL_GB=$((AVAIL_KB / 1024 / 1024))

echo "  Mount point: $MOUNT_POINT"
echo "  Available: ${AVAIL_GB}GB"
echo "  Required: ${MIN_SPACE_GB}GB"

if [ "$AVAIL_GB" -lt "$MIN_SPACE_GB" ]; then
    echo ""
    echo "ERROR: Insufficient disk space!"
    echo "  Need at least ${MIN_SPACE_GB}GB, but only ${AVAIL_GB}GB available."
    echo "  Please free up disk space before continuing."
    exit 1
fi

echo "  Disk space: OK"
echo ""

# Build and start containers
echo "Building and starting containers..."
cd "$SCRIPT_DIR"
docker compose build
docker compose up -d

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To attach to Claude Code interactively:"
echo "  docker compose -f $SCRIPT_DIR/docker-compose.yml exec claude claude"
echo ""
echo "Or attach to the running container:"
echo "  docker compose -f $SCRIPT_DIR/docker-compose.yml attach claude"
echo ""
echo "To stop the containers:"
echo "  docker compose -f $SCRIPT_DIR/docker-compose.yml down"
echo ""
echo "To view logs:"
echo "  docker compose -f $SCRIPT_DIR/docker-compose.yml logs -f"
echo ""
echo "Security notes:"
echo "  - Claude runs in an isolated network (no host network access)"
echo "  - Docker containers spawn via DinD (not host Docker daemon)"
echo "  - Your workspace is persisted in the 'workspace' volume"
echo ""
