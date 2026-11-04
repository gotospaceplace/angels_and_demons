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

## Stamping a Build Number

Before exporting, stamp the build with the current git hash, date, and an incrementing build counter. This writes `shared/scripts/build_info.gd` which is registered as the `BuildInfo` autoload.

**PowerShell (Windows):**

```powershell
$n = [int](Get-Content .build_number) + 1; $n | Set-Content .build_number -NoNewline
$hash = (git rev-parse --short HEAD)
$date = (Get-Date -Format "yyyy-MM-dd")
$ver = "0.1.0"
@"
extends Node

const BUILD_NUMBER := $n
const BUILD_HASH := "$hash"
const BUILD_DATE := "$date"
const BUILD_VERSION := "$ver"

static func get_build_string() -> String:
	if BUILD_HASH == "dev":
		return "%s-dev" % BUILD_VERSION
	return "%s build %d (%s %s)" % [BUILD_VERSION, BUILD_NUMBER, BUILD_HASH, BUILD_DATE]

static func get_short_string() -> String:
	if BUILD_HASH == "dev":
		return "dev"
	return "#%d-%s" % [BUILD_NUMBER, BUILD_HASH]
"@ | Set-Content shared/scripts/build_info.gd -Encoding utf8
```

**Bash (Linux / CI):**

```bash
n=$(($(cat .build_number) + 1)); echo -n "$n" > .build_number
hash=$(git rev-parse --short HEAD)
date=$(date +%Y-%m-%d)
ver="0.1.0"
cat > shared/scripts/build_info.gd <<EOF
extends Node

const BUILD_NUMBER := $n
const BUILD_HASH := "$hash"
const BUILD_DATE := "$date"
const BUILD_VERSION := "$ver"

static func get_build_string() -> String:
	if BUILD_HASH == "dev":
		return "%s-dev" % BUILD_VERSION
	return "%s build %d (%s %s)" % [BUILD_VERSION, BUILD_NUMBER, BUILD_HASH, BUILD_DATE]

static func get_short_string() -> String:
	if BUILD_HASH == "dev":
		return "dev"
	return "#%d-%s" % [BUILD_NUMBER, BUILD_HASH]
EOF
```

The `.build_number` file is git-ignored (machine-local counter). In the editor, `BuildInfo` defaults to `dev` mode with no stamp. Access the build string at runtime via `BuildInfo.get_build_string()` or `BuildInfo.get_short_string()`.

## Building the Windows Client

From the repository root, using the Godot console binary:

```bash
godot --headless --import
```

```bash
godot --headless --export-release "Windows Client" build/angels_and_demons_buildN.exe
```

Replace `N` with the current build number from `.build_number`. The exe is self-contained (`.pck` embedded) — distribute it directly, no zip needed.

**PowerShell (Windows):**

```powershell
$n = (Get-Content .build_number -Raw).Trim()
& $godot --headless --export-release "Windows Client" "build/angels_and_demons_build$n.exe"
```

**Bash (Linux / CI):**

```bash
n=$(cat .build_number)
godot --headless --export-release "Windows Client" "build/angels_and_demons_build${n}.exe"
```

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
| Windows Client | Windows x86_64 | `build/angels_and_demons_buildN.exe` | Game client |

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
    ├── angels_and_demons_buildN.exe  # Client builds (named by build number)
    └── server/
```
