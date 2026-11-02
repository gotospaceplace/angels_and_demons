# Build and Deploy Guide

## Prerequisites

- **Godot 4.7.2** — download the [standard](https://godotengine.org/download/) or console build for your platform
- **Export templates** — install via Godot Editor → Editor → Manage Export Templates → Download, or manually from the [Godot downloads page](https://godotengine.org/download/)
- **Git** — to clone and update the repository
- **Docker** (server only) — required for containerized server builds and VPS deployment

### Template install paths

| Platform | Path |
|----------|------|
| Windows  | `%APPDATA%\Godot\export_templates\4.7.2.stable\` |
| Linux    | `~/.local/share/godot/export_templates/4.7.2.stable/` |
| macOS    | `~/Library/Application Support/Godot/export_templates/4.7.2.stable/` |

## Building the Windows Client

From the repository root, using the Godot console binary:

```bash
godot --headless --import
```

```bash
mkdir -p build/client
```

```bash
godot --headless --export-release "Windows Client" build/client/angels_and_demons.exe
```

The first command imports all project resources (textures, sounds, scenes). The second exports the client to `build/client/angels_and_demons.exe` with its `.pck` embedded.

To distribute for playtesting, zip the `build/client/` folder and share the archive. The `.exe` is self-contained.

## Building the Linux Server (native)

```bash
godot --headless --import
```

```bash
mkdir -p build/server
```

```bash
godot --headless --export-release "Linux Server" build/server/angels_and_demons_server.x86_64
```

Run it with:

```bash
./build/server/angels_and_demons_server.x86_64 --headless
```

The server listens on UDP port **27050**.

## Building the Linux Server (Docker)

From the repository root:

```bash
docker compose -f infra/docker/docker-compose.yml up -d --build
```

This builds a multi-stage Docker image that downloads Godot and the export templates, exports the server binary, and packages it into a minimal Ubuntu container. The compose file maps port 27050/udp and creates persistent volumes for `config/` and `logs/`.

Useful commands:

```bash
docker compose -f infra/docker/docker-compose.yml logs -f
```

```bash
docker compose -f infra/docker/docker-compose.yml down
```

## VPS Deployment

### First-time setup

The deploy script handles everything on a fresh Ubuntu server — installs Docker, clones the repo, opens the firewall port, and starts the server:

```bash
ssh your-server
```

```bash
curl -fsSL https://raw.githubusercontent.com/gotospaceplace/angels_and_demons/main/infra/deploy.sh | bash
```

Or clone the repo and run the script directly:

```bash
git clone https://github.com/gotospaceplace/angels_and_demons.git /opt/angels-and-demons
cd /opt/angels-and-demons
bash infra/deploy.sh
```

### Updating a running server

```bash
ssh your-server
cd /opt/angels-and-demons
```

```bash
git pull --ff-only
```

```bash
docker compose -f infra/docker/docker-compose.yml up -d --build
```

This pulls the latest code, rebuilds the Docker image with the new source, and restarts the container. Existing config and log volumes are preserved.

## Running Tests

Tests run headless and exit with code 0 on success, 1 on failure.

| Suite | Command |
|-------|---------|
| Movement | `godot --headless --path . -- --test` |
| Network | `godot --headless --path . -- --test-network` |
| Combat | `godot --headless --path . -- --test-combat` |
| Validation | `godot --headless --path . -- --test-validation` |
| Benchmark | `godot --headless --path . -- --bench` |
| Script check | `godot --headless --path . -- --validate-scripts` |

On Windows, replace `godot` with the full path to the console binary, e.g.:

```
"C:\path\to\Godot_v4.7.2-stable_win64_console.exe" --headless --path . -- --test
```

## CI

GitHub Actions runs all of the above automatically on pushes to `main` and pull requests targeting `main`. The workflow is defined in `.github/workflows/build.yml` and includes:

1. **Validate** — import check, script validation, missing resource scan
2. **Test** — all four test suites plus the performance benchmark
3. **Canary** — verifies CI correctly detects broken scripts and missing resources
4. **Export** — builds the Linux server binary and uploads it as a build artifact (retained 14 days)

## Export Presets

Defined in `export_presets.cfg` at the repository root:

| Preset | Platform | Output | Type |
|--------|----------|--------|------|
| Linux Server | Linux x86_64 | `build/server/angels_and_demons_server.x86_64` | Dedicated server |
| Windows Client | Windows x86_64 | `build/client/angels_and_demons.exe` | Game client |

## Project Structure (build-relevant)

```
├── export_presets.cfg          # Godot export presets
├── project.godot               # Godot project config
├── infra/
│   ├── deploy.sh               # One-shot VPS deploy script
│   └── docker/
│       ├── Dockerfile          # Multi-stage server build
│       └── docker-compose.yml  # Container orchestration
├── .github/workflows/
│   └── build.yml               # CI pipeline
└── build/                      # Export output (git-ignored)
    ├── client/
    └── server/
```
