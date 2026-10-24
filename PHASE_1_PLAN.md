# PHASE 1 — Project Foundation
**Status:** Planning | **Version:** 1.0 | **Date:** 2026-10-24

## Scope
Establish the Godot 4 project structure, build pipeline, networking library selection, and a minimal client/server connection proof. Everything needed so that Phase 2 (movement lab) can start writing gameplay code on day one.

### In scope
- Godot 4 project with defined directory layout and conventions
- First-person camera scene (no gameplay — just a capsule in a gray-box room)
- Native client build (Windows) and headless server build (Linux)
- Docker image for the headless dedicated server
- CI pipeline: build validation on push (GitHub Actions via vm-prime)
- Networking library evaluation and selection (documented rationale)
- Minimal connection test: client connects to headless server, both log the event
- `.gitignore`, export presets, editor settings, GDScript style conventions
- Phase 1 signoff document

### Not in scope
- Movement, weapons, grenades, or any gameplay mechanics (Phase 2-3)
- Multiplayer state sync, prediction, or reconciliation (Phase 4)
- Art, models, textures, or sound (Phase 6)
- Steam integration (Phase 8)
- Matchmaking, accounts, or persistence (post-launch)
- Custom build of Godot engine — use stock release builds

---

## Decisions required

### D1: Godot version
**Decision:** Godot 4.7 stable (installed on laptop).
Use the standard build, not .NET — GDScript is the primary language. C# or GDExtension (C++) can be introduced later for performance-critical paths (physics, netcode) if needed.

### D2: Networking library
This is the main technical investigation of Phase 1. Candidates:

| Option | Pros | Cons |
|--------|------|------|
| **Godot built-in ENet** (MultiplayerPeer) | Zero dependencies, editor integration, RPC macros, works out of the box | High-level API hides packet details; harder to implement custom lag compensation and snapshot interpolation; ENet's reliability layer may not match competitive FPS needs |
| **ENet via GDExtension** | Same protocol, but direct control over channels/sequencing; proven in Source-era games | Requires C++ GDExtension build; more setup but full control |
| **GameNetworkingSockets (Valve)** | Built for competitive FPS; Steam Datagram Relay compatible; handles NAT traversal; battle-tested | C++ dependency; GDExtension wrapper needed; heavier initial setup |
| **Raw UDP + custom reliability** | Total control over packet format, sequencing, snapshot delta compression | Significant engineering effort; re-inventing solved problems |

**Recommendation:** Start with Godot built-in ENet for Phase 1 connection test (fastest path to "client talks to server"). Evaluate GameNetworkingSockets as a parallel spike during Phase 2-3 when we know what the netcode actually needs. The connection test is transport-agnostic — swapping the transport layer later is a known, bounded task.

### D3: Project directory layout
Following the technical architecture doc with Godot-specific structure:

```
angels_and_demons/
├── project.godot
├── client/                # Client-only scenes, UI, rendering, input
│   ├── scenes/
│   ├── scripts/
│   └── resources/
├── server/                # Server-only logic, headless entry point
│   ├── scenes/
│   └── scripts/
├── shared/                # Code used by both client and server
│   ├── scenes/
│   ├── scripts/
│   └── resources/
├── maps/                  # Map scenes and assets
├── tests/                 # Automated test scenes and scripts
├── infra/
│   ├── docker/            # Dockerfile, compose, server config
│   └── ci/                # GitHub Actions workflows
├── export_presets.cfg      # Godot export configurations
├── docs/                  # Phase plans, specs (already: phase_0/)
├── phase_0/               # Existing research outputs
├── research/              # Existing source study
└── .gitignore
```

### D4: GDScript conventions
- snake_case for files, variables, functions
- PascalCase for classes/nodes
- Type hints on all function signatures and member variables
- No `@onready` chains longer than 5 — use a setup function
- Signals over direct node references where possible
- `class_name` registration for any reusable class

---

## Architecture sketch

```
Phase 1 target (minimal):

  [Windows Client]                    [Linux Headless Server]
   Godot 4.7                           Godot 4.7 --headless
   ┌──────────────┐                    ┌──────────────────┐
   │ MainScene    │                    │ ServerScene      │
   │  └ FPCamera  │  ── ENet UDP ──>  │  └ ConnectionMgr │
   │  └ ConnectUI │  <── ENet UDP ──  │  └ Logger        │
   └──────────────┘                    └──────────────────┘
                                              │
                                       [Docker Container]
                                        godot --headless
                                        --main-pack server.pck
```

Client: opens a window, shows an empty gray-box room with first-person camera, has a "Connect" button.
Server: runs headless, listens on a port, accepts connections, logs peer ID.
Connection test: client connects, server logs it, client shows "Connected to server" — that's the entire Phase 1 deliverable.

---

## Work breakdown

### WB1: Godot project initialization (laptop)
- [ ] Create `project.godot` with correct settings (3D, forward+ renderer)
- [ ] Create directory structure per D3
- [ ] Add `.gitignore` for Godot (`.godot/`, `*.import` reimports, export builds)
- [ ] Create export presets: Windows client, Linux server (headless)
- [ ] Verify project opens in Godot editor without errors
- **Owner:** laptop (you + Claude Code)

### WB2: Gray-box test scene (laptop)
- [ ] Create `shared/scenes/test_room.tscn` — a simple enclosed box (CSG or mesh), floor, walls, basic lighting
- [ ] Create `client/scenes/player_camera.tscn` — first-person CharacterBody3D with Camera3D, mouse look, WASD (no physics tuning yet — just enough to walk around)
- [ ] Create `client/scenes/main_menu.tscn` — IP input field, connect button, status label
- [ ] Create `shared/scenes/main.tscn` — entry point that loads menu or game
- **Owner:** laptop

### WB3: Headless server scene (laptop + vm-prime)
- [ ] Create `server/scenes/server_main.tscn` — headless entry, starts ENet server on configurable port
- [ ] Create `server/scripts/server.gd` — accept connections, log peer join/leave, no game state
- [ ] Verify it runs with `godot --headless --main-pack server.pck`
- **Owner:** laptop creates scenes, vm-prime tests headless builds

### WB4: Networking connection test (laptop + vm-prime)
- [ ] Client: ENet peer connects to server IP:port
- [ ] Server: logs connection with peer ID and IP
- [ ] Client: displays "Connected" status on successful handshake
- [ ] Client: handles connection failure gracefully (timeout, refused)
- [ ] Both: clean disconnect logging
- [ ] Test: laptop client → vm-prime headless server over LAN
- **Owner:** split

### WB5: Docker packaging (vm-prime)
- [ ] `infra/docker/Dockerfile` — minimal Linux image with Godot headless runtime
- [ ] `infra/docker/docker-compose.yml` — server with UDP port exposure, volume mounts for config/logs
- [ ] Server runs identically native and containerized
- [ ] Document image build and run commands
- **Owner:** vm-prime

### WB6: CI pipeline (vm-prime)
- [ ] GitHub Actions workflow: on push to main, build client and server export
- [ ] Smoke test: server starts headless, listens, exits cleanly on SIGTERM
- [ ] Fail on GDScript parse errors (use `godot --check-only` or `--headless --script` validation)
- [ ] Artifact: upload server build as GitHub Actions artifact
- **Owner:** vm-prime

### WB7: Networking library evaluation (both)
- [ ] Document ENet behavior during connection test (latency, channel model, reliability options)
- [ ] Research GameNetworkingSockets: Godot binding maturity, build requirements, Steam relay path
- [ ] Write `docs/networking_evaluation.md` with recommendation and migration cost estimate
- [ ] Decision: confirm or revise D2 recommendation
- **Owner:** Claude Code research + your review

---

## Test plan

| Test | Method | Pass criteria |
|------|--------|---------------|
| Clean build | `git clone` → open in Godot → no errors | Zero import/parse errors |
| Client runs | Launch client export on Windows | Window opens, camera moves, menu renders |
| Server runs native | `godot --headless` on Linux | Logs "Server listening on port XXXX", no crash |
| Server runs Docker | `docker compose up` | Same log output as native, port reachable |
| Connection | Client connects to server | Both log the connection event, client shows status |
| Disconnect | Client disconnects or closes | Server logs clean disconnect, no crash |
| CI green | Push to main | GitHub Actions passes, server artifact uploaded |
| Headless no GPU | Server on vm-prime (no display) | Runs without X11/Wayland, no rendering errors |

---

## Benchmarks
Phase 1 benchmarks are minimal — just proving the pipeline works:
- Server startup time < 5s to "listening" state
- Docker image size < 500MB (ideally < 200MB with minimal base)
- CI build time < 10 minutes
- Connection handshake < 1s on LAN

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Godot headless Linux export issues | Medium | High | Test early; Godot 4.3 has improved headless support but edge cases exist |
| ENet insufficient for competitive FPS netcode | Medium | Low (Phase 1) | We're only using it for connection test; deeper evaluation in WB7, swap in Phase 4 if needed |
| Docker + Godot headless GPU dependency | Medium | Medium | Use `--rendering-driver dummy` or server export with no rendering |
| GitHub Actions lacks Godot export templates | Low | Medium | Use `chickensoft-games/setup-godot` action or manual template install |
| GDScript performance for netcode | Low (Phase 1) | Low | Not relevant until Phase 4; GDExtension C++ is the escape hatch |

---

## Dependencies
- Godot 4.7 stable installed on laptop (Windows) — **done**
- Godot 4.7 headless export templates for Linux on vm-prime
- Docker on vm-prime — likely already installed
- GitHub repo `gotospaceplace/angels_and_demons` — **exists**
- GitHub Actions enabled on the repo

---

## Rollback
Phase 1 adds no gameplay code. If Godot proves unsuitable, the research docs, design documents, and directory conventions carry forward to any engine. The worst case is we learn Godot can't do headless dedicated servers well, which is valuable information.

---

## Owner training exercises

### E1: Godot project structure
After WB1-WB2, explore the Godot editor:
- Open the scene tree, understand nodes vs scenes vs resources
- Modify the test room geometry (add a box, move a wall)
- Change the camera FOV, verify it updates in-editor
- **Goal:** comfortable navigating the Godot editor and scene system

### E2: GDScript basics
- Read through the player camera script — understand `_input()`, `_physics_process()`, `_ready()`
- Add a debug label that shows the camera's position (Vector3)
- **Goal:** can read and make small changes to GDScript

### E3: Export and headless builds
- Export the client on Windows, run the .exe outside the editor
- SSH to vm-prime, run the headless server, connect from laptop
- **Goal:** understand the build/export pipeline and client-server split

### E4: Docker basics
- `docker compose up` the server on vm-prime
- `docker compose logs -f` to watch output
- Connect from laptop client
- `docker compose down` to stop
- **Goal:** comfortable running and debugging the containerized server

---

## Acceptance checklist (gate criteria)

- [ ] Clean `git clone` → Godot editor opens project without errors
- [ ] Windows client export runs: window, camera, mouse look, WASD
- [ ] Linux headless server export runs on vm-prime without GPU/display
- [ ] Client connects to server over LAN, both log the event
- [ ] Server runs in Docker, client connects identically
- [ ] CI pipeline passes on push: builds, smoke test, artifact upload
- [ ] `docs/networking_evaluation.md` committed with recommendation
- [ ] GDScript conventions documented and followed in all committed scripts
- [ ] No placeholder/stub code left without a tracking comment

---

## Demo instructions
1. On vm-prime: `cd angels_and_demons && docker compose -f infra/docker/docker-compose.yml up`
2. On laptop: run the client export (or press F5 in Godot editor)
3. Enter vm-prime's IP (192.168.30.11) and port in the connect UI
4. Observe: client shows "Connected", server logs the peer
5. Close client, observe: server logs clean disconnect
6. On vm-prime: `docker compose down`

---

## Immediate next steps
1. **You (laptop):** Initialize Godot project (WB1), create test scene (WB2), create connection scripts (WB3-WB4)
2. **vm-prime (Claude Code here):** Set up Docker packaging (WB5), CI pipeline (WB6), headless build testing
3. **Both:** Networking evaluation (WB7) happens alongside as we learn from the connection test
4. **Gate review:** When all checklist items are green, commit `PHASE_1_SIGNOFF.md`
