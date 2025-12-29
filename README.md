# Claude Code Docker-in-Docker (Secure Isolated Environment)

Run Claude Code CLI in a fully isolated Docker environment with Docker-in-Docker (DinD) capabilities. Claude can spawn containers through an isolated Docker daemon - **not your host's Docker** - ensuring your host system remains protected.

## Why This Project?

When running AI coding assistants with Docker access, security is critical. This setup ensures:

- **Host Docker Isolation**: Claude cannot access your host's Docker daemon
- **Network Isolation**: Claude uses a bridge network, no direct host network access
- **Filesystem Isolation**: Claude only sees its container filesystem + mounted volumes
- **Nested Container Safety**: Any containers Claude spawns run inside DinD, not on your host

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       HOST MACHINE                           │
│                                                              │
│  Host Docker daemon ─────────────────── NOT accessible       │
│  Host network ───────────────────────── NOT accessible       │
│  Host filesystem ────────────────────── NOT accessible       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │            Docker Compose (bridge network)              │ │
│  │                                                         │ │
│  │  ┌─────────────────────┐    ┌───────────────────────┐  │ │
│  │  │   claude container  │    │    dind container     │  │ │
│  │  │                     │    │                       │  │ │
│  │  │  • Node.js 20       │    │  • Docker daemon      │  │ │
│  │  │  • Docker CLI       │───▶│  • Isolated storage   │  │ │
│  │  │  • Claude Code CLI  │    │  • Spawned containers │  │ │
│  │  │                     │    │                       │  │ │
│  │  └─────────────────────┘    └───────────────────────┘  │ │
│  │            │                          │                 │ │
│  │            └────────────┬─────────────┘                 │ │
│  │                         │                               │ │
│  │                 [Bridge Network]                        │ │
│  │                         │                               │ │
│  │                     Internet                            │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Security Features

| Feature | Implementation |
|---------|----------------|
| No host Docker access | Host's `/var/run/docker.sock` is NOT mounted |
| No host network | Containers use isolated bridge network |
| Isolated Docker daemon | DinD runs its own Docker daemon |
| Container isolation | Containers spawned by Claude run inside DinD |
| Internet via bridge | Outbound internet through NAT only |
| Disk space safety | Pre-flight check ensures sufficient space |

## Prerequisites

- Linux host (tested on Kali, Debian, Ubuntu)
- Docker Engine installed
- Docker Compose v2+
- 10GB+ free disk space
- Claude Max subscription (for OAuth authentication)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR_USERNAME/claude-dind.git
cd claude-dind
```

### 2. (Optional) Configure Docker Storage

If you have limited space on your root filesystem, configure Docker to use a different partition:

```bash
# Create Docker data directory on your preferred partition
sudo mkdir -p /path/to/your/storage/docker-data

# Configure Docker daemon
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "data-root": "/path/to/your/storage/docker-data"
}
EOF

# Restart Docker
sudo systemctl restart docker
```

### 3. Start the Environment

```bash
sudo ./start.sh
```

This will:
1. Check for minimum 10GB disk space
2. Build the Claude container image
3. Pull the Docker-in-Docker image
4. Start both containers
5. Wait for DinD to be healthy

### 4. Attach to Claude Code

```bash
sudo docker compose exec -it claude claude
```

### 5. Authenticate

On first run, Claude Code will display a URL. Open it in your browser to authenticate with your Claude Max account. Your authentication tokens are persisted in a Docker volume.

## Usage

### Starting the Environment

```bash
cd claude-dind
sudo ./start.sh
```

### Attaching to Claude Code

```bash
# Interactive Claude Code session
sudo docker compose exec -it claude claude

# Or run a single command
sudo docker compose exec claude claude -p "What is Docker?"
```

#### What Does "Attach" Mean?

When you attach, your host terminal becomes a window into the container:

```
┌─────────────────────────────────────────────────────────┐
│                    HOST MACHINE                          │
│                                                          │
│  ┌──────────────────┐                                   │
│  │  Your Terminal   │◄─── You type here                 │
│  │  (host)          │                                   │
│  └────────┬─────────┘                                   │
│           │                                              │
│           │ stdin/stdout/stderr                         │
│           ▼                                              │
│  ┌──────────────────────────────────────────────────┐   │
│  │              CLAUDE CONTAINER                     │   │
│  │                                                   │   │
│  │  ┌────────────────────┐                          │   │
│  │  │  Claude Code CLI   │◄─── Runs HERE (isolated) │   │
│  │  │  (the AI process)  │                          │   │
│  │  └────────────────────┘                          │   │
│  │           │                                       │   │
│  │           │ DOCKER_HOST=tcp://dind:2375          │   │
│  │           ▼                                       │   │
│  │  ┌────────────────────┐                          │   │
│  │  │  DinD Container    │◄─── Containers spawn     │   │
│  │  │  (Docker daemon)   │     HERE, not on host    │   │
│  │  └────────────────────┘                          │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

| Component | Where It Runs |
|-----------|---------------|
| Your terminal | Host machine |
| Claude Code process | Inside container |
| AI API calls | Container → Internet |
| Containers Claude spawns | Inside DinD (nested) |

**This is why it's safe**: Even if Claude tried something malicious, it only affects the isolated container environment, not your host system.

### Checking Container Status

```bash
sudo docker compose ps
```

### Viewing Logs

```bash
# All logs
sudo docker compose logs -f

# Just Claude container
sudo docker compose logs -f claude

# Just DinD container
sudo docker compose logs -f dind
```

### Stopping the Environment

```bash
sudo docker compose down
```

### Full Cleanup (removes volumes too)

```bash
sudo docker compose down -v
```

## Persistent Data

Three Docker volumes store persistent data:

| Volume | Purpose | Path in Container |
|--------|---------|-------------------|
| `workspace` | Your projects and files | `/workspace` |
| `claude-config` | Claude auth tokens & settings | `/root/.claude` |
| `dind-storage` | Docker images/containers in DinD | `/var/lib/docker` |

### Accessing Your Workspace

Files you create in `/workspace` inside the container persist across restarts:

```bash
# Copy files into the workspace
sudo docker compose cp ./myproject claude:/workspace/

# Copy files out of the workspace
sudo docker compose cp claude:/workspace/myproject ./
```

## Verifying Security

### Test 1: Host Docker Socket Not Accessible

```bash
sudo docker compose exec claude ls -la /var/run/docker.sock
# Should return: "No such file or directory"
```

### Test 2: Claude Uses DinD Docker

```bash
sudo docker compose exec claude docker info | grep -i "name"
# Should show DinD's Docker, not host's
```

### Test 3: Containers Spawn Inside DinD

```bash
# From Claude container, run a container
sudo docker compose exec claude docker run --rm alpine echo "Hello from DinD!"

# Verify it's NOT visible on host
docker ps -a | grep alpine
# Should return nothing (container ran inside DinD)
```

### Test 4: Internet Access Works

```bash
sudo docker compose exec claude curl -s -o /dev/null -w "%{http_code}" https://google.com
# Should return: 200
```

## Troubleshooting

### "Insufficient disk space" Error

The start script requires 10GB free. Either free up space or modify `MIN_SPACE_GB` in `start.sh`.

### DinD Container Not Healthy

Check DinD logs:
```bash
sudo docker compose logs dind
```

Common causes:
- Kernel doesn't support required features
- Storage driver issues

### Claude Can't Connect to DinD

Verify DinD is running and healthy:
```bash
sudo docker compose ps
```

The `dind` service should show `(healthy)` status.

### Authentication Issues

If authentication fails or expires:
```bash
# Remove Claude config volume and re-authenticate
sudo docker compose down
docker volume rm claude-dind_claude-config
sudo ./start.sh
```

## Customization

### Change Workspace Location

To bind-mount a host directory instead of using a volume, edit `docker-compose.yml`:

```yaml
volumes:
  - /path/on/host:/workspace  # Instead of: workspace:/workspace
```

### Add Environment Variables

Edit `docker-compose.yml` to add variables to the Claude container:

```yaml
claude:
  environment:
    - DOCKER_HOST=tcp://dind:2375
    - MY_CUSTOM_VAR=value
```

### Use API Key Instead of OAuth

If using an API key instead of Claude Max:

```yaml
claude:
  environment:
    - DOCKER_HOST=tcp://dind:2375
    - ANTHROPIC_API_KEY=your-api-key-here
```

## File Structure

```
claude-dind/
├── docker-compose.yml    # Container orchestration
├── Dockerfile.claude     # Claude container build instructions
├── start.sh              # Startup script with disk check
└── README.md             # This file
```

## How It Works

1. **DinD Container**: Runs a full Docker daemon inside a container. This daemon is completely separate from your host's Docker.

2. **Claude Container**: Runs Claude Code CLI with Docker CLI installed. The `DOCKER_HOST` environment variable points to the DinD container, so all Docker commands go to DinD, not your host.

3. **Bridge Network**: Both containers share an isolated bridge network. They can communicate with each other and reach the internet, but cannot access your host network directly.

4. **Privileged Mode**: Both containers run with `--privileged` flag, which is required for DinD to function. However, this privilege is contained within the Docker isolation layer.

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions welcome! Please open an issue or PR.

## Security Considerations

While this setup provides strong isolation, keep in mind:

- The `--privileged` flag grants elevated capabilities within the container
- DinD containers have known limitations compared to native Docker
- For production/enterprise use, consider additional hardening (SELinux, AppArmor, user namespaces)

This project is designed for development and experimentation where you want to give Claude Code Docker access without risking your host system.
