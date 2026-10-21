# ANGELS AND DEMONS — Technical Architecture
**Status:** High-level target architecture; implementation details deferred | **Version:** 0.1

## Architectural decision summary
- **Engine candidate:** Godot 4, to be validated through a movement/networking prototype; not irrevocably locked.
- **Clients:** Windows first, Linux desirable; rendering/input/audio, client-side prediction, reconciliation, interpolation.
- **Game server:** headless authoritative Linux executable; no rendering or client-side asset requirement.
- **Deployment:** native process and official Docker image/Compose sample; Kubernetes/Helm later.
- **Transport:** latency-oriented UDP; exact networking stack selected after prototype benchmarking.
- **Distribution:** planned Steam release at ~$9.99; Steamworks adapters for identity/discovery; standalone operation preserved.
- **Community-first:** configurable server, map packages, admin console, plugin API boundaries.

## Logical components
```
Windows/Linux Client
  ├─ input, rendering, audio, UI, effects
  ├─ prediction / interpolation / reconciliation
  └─ Steam adapter OR standalone connection
             | UDP gameplay
Headless Dedicated Game Server
  ├─ authoritative movement + collision
  ├─ weapon/grenade/hit simulation
  ├─ teams, objectives, economy, rounds
  ├─ validated command intake + snapshots
  ├─ administration / bans / audit log
  └─ versioned extension interfaces
             |
Optional external services
  ├─ Steamworks: auth, server listings, distribution, Workshop later
  ├─ independent discovery/master server (optional)
  └─ statistics / community web API (optional)
```

## Server authority and consistency
- Clients submit input commands with sequencing; server validates and simulates outcomes.
- Server never trusts client-supplied position, health, inventory, damage, or hit confirmation.
- Shared deterministic-or-consistent movement logic where practical, with client reconciliation.
- Server lag compensation and snapshot/interpolation policies require controlled testing.
- Simulation tick, input rate, and snapshot rate are separate decisions; evaluate 64 Hz initially and test alternatives against the reference behavior. Do not assume a higher tick rate guarantees CS 1.6 fidelity.
- Instrument tick duration, packet loss, jitter, correction rate, and hit-registration outcomes.

## Hosting and isolation
- A single match/server instance is a standalone process and can run native or containerized.
- Docker Compose is initial community reference deployment; host UDP networking on Linux may simplify latency/port handling but requires deliberate security controls.
- Persistent mounts for config, logs, maps, and approved plugins. Stateless game process where practical.
- Unprivileged container, minimal image, no host Docker socket, restricted mounts/capabilities, resource limits.
- Community-hosted servers require no central login service to boot or serve configured LAN/private sessions.
- Official public sessions require validated Steam authentication. Distinguish authenticated Steam identities from standalone/guest identities in moderation logs.

## Steam integration boundaries
- Steamworks integration isolated behind interfaces for identity, server advertisement/discovery, and optional transport/content distribution.
- Direct-IP and LAN paths must remain functional without Steam service availability where client distribution and authentication policies permit.
- Steam Datagram Relay is a future evaluation, not an assumed feature of every server.
- SteamCMD-based server distribution planned, subject to Steamworks requirements and onboarding.
- Workshop support deferred until safe map/mod package format is established.

## Community extensibility
- Core simulation has stable, documented hooks; game rules are configurable without recompiling engine.
- Phase 1 extension capabilities: server config, map rotation, administrative commands.
- Later: versioned plugin API (Lua is a candidate, not a commitment), event hooks, map scripting, content packaging, dependency/version manifests.
- Never execute downloaded server plugin code on connecting clients; verify asset hashes and constrain client content to non-executable formats.
- Community plugin sandboxing is an explicit security design problem; Lua embedding alone does not guarantee isolation.
- Plugin APIs should expose capabilities rather than raw engine internals or unrestricted OS access.

## Security and abuse prevention
- SteamID bans for authenticated players; IP/CIDR bans, temporary bans, mutes, kick, rate limits, and admin role-based access.
- IP bans are supplemental: NAT, dynamic addresses, and VPNs make them unreliable as sole enforcement.
- Validate packet lengths, rates, sequence numbers, commands, movement envelopes, weapon cadence, inventory, and admin actions.
- Remote console requires strong authentication, audit logging, and encrypted management transport or restricted trusted network; never expose unauthenticated RCON.
- Protect servers from malformed content, malicious plugins, and excessive resource usage.
- Client anti-cheat remains a separate later evaluation; server-side validation is foundational but not a complete anti-cheat solution.

## Engineering and operations
- Monorepo candidate: `/client`, `/server`, `/shared`, `/platform/steam`, `/platform/standalone`, `/mods`, `/maps`, `/tests`, `/infra/docker`, `/infra/k8s`, `/docs`.
- Git version control from day one, CI for builds/unit tests, reproducible server packaging, versioned network protocol.
- Automated movement regression harness and reference recordings are release blockers for gameplay changes.
- Structured logs, metrics, crash capture, admin audit trail, and clear compatibility/version messages.
- No database required to host an ordinary match; optional services must fail gracefully.

## Decisions deferred to phase design
Networking library, serialization, ECS/object model, physics implementation, Steamworks binding, plugin sandbox, matchmaking, persistence schema, build pipeline specifics, release signing, and cloud provider.

## Architecture acceptance criteria
1. Same server gameplay executable runs natively and in Docker.
2. Two remote clients join a dedicated server and play a complete round.
3. Client cannot authoritatively alter movement/damage.
4. Private LAN/direct-IP match runs without central services.
5. Server config, admin controls, map rotation, and logs persist across restarts.
6. Network and movement benchmarks are reproducible and documented.
