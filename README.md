# Claude Code Docker-in-Docker

Run Claude Code CLI in an isolated Docker environment with web terminal access.

## Features

- **Isolated Docker Environment**: Claude runs Docker commands inside a container (DinD), not on your host
- **Web Terminal**: Access Claude Code via browser using ttyd
- **Authentication**: Basic auth protection for web access
- **Multi-session**: Multiple users can connect simultaneously with separate contexts
- **Persistent Storage**: Projects and config survive container restarts

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Host Machine                        │
│  ┌────────────────────────────────────────────────────┐ │
│  │              claude-net network                     │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │ │
│  │  │   dind   │  │  claude  │  │      ttyd        │  │ │
│  │  │ (docker) │◄─│  (cli)   │  │  (web terminal)  │  │ │
│  │  └──────────┘  └──────────┘  └──────────────────┘  │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/aknanai/claude-dind.git
cd claude-dind
```

### 2. Configure environment

```bash
cp .env.example .env
```

Edit `.env` and set your credentials:

```env
TTYD_USERNAME=your_username
TTYD_PASSWORD=your_secure_password
```

### 3. Build and start

```bash
docker build -f Dockerfile.claude -t claude-code:latest .
docker compose up -d
```

### 4. Access Claude Code

Open `http://localhost:7681` in your browser and login with your credentials.

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TTYD_USERNAME` | Web terminal username | `admin` |
| `TTYD_PASSWORD` | Web terminal password | `changeme` |
| `TTYD_PORT` | Web terminal port | `7681` |
| `CLAUDE_PROJECTS_PATH` | Host path for projects | `./projects` |
| `CLAUDE_CONFIG_PATH` | Host path for Claude config | `./config` |

### Synology NAS Setup

For Synology, use absolute paths in your `.env`:

```env
CLAUDE_PROJECTS_PATH=/volume1/docker/claude/projects
CLAUDE_CONFIG_PATH=/volume1/docker/claude/config
```

Create directories before starting:

```bash
sudo mkdir -p /volume1/docker/claude/{projects,config}
```

### Portainer Deployment

If using Portainer and `dockerfile_inline` fails:

1. Build the image manually first:
   ```bash
   sudo docker build -f Dockerfile.claude -t claude-code:latest .
   ```

2. Remove the `build` section from `docker-compose.yml` and keep only:
   ```yaml
   claude:
     image: claude-code:latest
   ```

3. Deploy the stack in Portainer

## Usage

### Multiple Sessions

Each browser tab/connection spawns a separate Claude session with its own context window. All sessions share:
- Workspace files (`/workspace`)
- Claude configuration
- API billing

### Docker Commands

Claude can run Docker commands inside the isolated dind container:

```bash
docker ps        # List containers (inside dind, not host)
docker build     # Build images
docker run       # Run containers
```

## Security

- Web terminal protected by basic authentication
- Docker commands run in isolated dind container
- Host Docker daemon is not accessible from Claude
- Credentials stored in `.env` (not committed to git)

## Troubleshooting

### "execvp failed: no such file or directory"

The ttyd container needs the Docker binary mounted. Ensure this volume is in the compose file:

```yaml
volumes:
  - /usr/local/bin/docker:/usr/local/bin/docker:ro
```

### "Bind mount failed: path does not exist"

Create the required directories:

```bash
mkdir -p ./projects ./config
# Or for Synology:
sudo mkdir -p /volume1/docker/claude/{projects,config}
```

### Network conflicts

If you get network overlap errors, add explicit IPAM config:

```yaml
networks:
  claude-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.44.0.0/24
          gateway: 172.44.0.1
```

## License

MIT
