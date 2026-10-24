# Networking Library Evaluation
**Phase:** 1 | **Date:** 2026-10-24 | **Status:** Decision made

## Context
Angels and Demons requires server-authoritative multiplayer with competitive FPS netcode: 128-tick server, lag compensation, client-side prediction, server reconciliation, entity interpolation, and snapshot delta compression. This evaluation selects the transport layer for Phase 2+ development.

## Candidates evaluated

### 1. Godot built-in ENet (ENetMultiplayerPeer)
Godot 4's high-level multiplayer API wraps ENet, a reliable UDP library originally developed for FPS games (used by Cube, Sauerbraten).

**Strengths:**
- Zero external dependencies — ships with Godot
- Native editor integration: `@rpc` annotations, MultiplayerSpawner/Synchronizer nodes
- Handles connection lifecycle, channels, reliability modes out of the box
- Sufficient for authoritative server architecture — server can reject client state
- Proven in Phase 1: connection test worked immediately with ~15 lines of code

**Weaknesses:**
- High-level RPC API hides packet-level control (channel selection, sequencing, fragmentation)
- MultiplayerSynchronizer is designed for state replication, not the snapshot/delta model competitive FPS needs
- No built-in lag compensation or server-side hit registration framework
- Godot's `SceneMultiplayer` assumes peer-to-peer-style authority model; pure authoritative server requires discipline to avoid leaking client authority
- No NAT traversal or relay (direct IP/LAN only without external help)

**Verdict:** Good enough for transport. The weaknesses are in the _high-level API_, not the underlying ENet protocol. We can use `ENetMultiplayerPeer` for connection/transport while building our own authoritative game loop on top.

### 2. ENet via GDExtension (direct C binding)
Bypass Godot's multiplayer layer and call ENet's C API directly through a GDExtension.

**Strengths:**
- Full control over packet channels, sequencing, reliability flags
- Can implement custom serialization and snapshot format
- Same battle-tested ENet protocol underneath

**Weaknesses:**
- Requires building and maintaining a C++ GDExtension
- Loses all Godot multiplayer conveniences (RPC, spawner, synchronizer)
- Must reimplement connection lifecycle, peer management, disconnect handling
- Not significantly better than using ENetMultiplayerPeer at the low level — Godot exposes `ENetConnection` and `ENetPacketPeer` for direct access when needed

**Verdict:** Unnecessary complexity. Godot 4 already exposes `ENetConnection` for low-level access alongside the high-level API. A custom GDExtension adds build complexity for marginal gain.

### 3. Valve GameNetworkingSockets (GNS)
Valve's open-source networking library, extracted from Steam. Designed for competitive multiplayer games.

**Strengths:**
- Built specifically for game networking with competitive FPS in mind
- Steam Datagram Relay (SDR) integration for NAT traversal and DDoS protection
- Connection encryption, bandwidth estimation, packet pacing
- Detailed connection quality diagnostics
- Used in production by CS2, Dota 2, etc.

**Weaknesses:**
- C++ library requiring a GDExtension wrapper — no mature Godot 4 binding exists
- SDR only works with Steam; standalone mode uses raw UDP (same as ENet)
- Significant setup complexity: build GNS from source, write GDExtension, maintain compatibility
- Overkill for Phase 2-4 where we're testing on LAN with <10 players
- Steam integration (Phase 8) is far away; early adoption locks us in

**Verdict:** Best-in-class for a shipped Steam game, but premature for our stage. Revisit when Steam integration begins in Phase 8. The transport layer is an interface we can swap.

### 4. Raw UDP with custom reliability
Build a custom protocol from scratch using raw UDP sockets.

**Strengths:**
- Total control over every byte on the wire
- Can design packet format exactly for our snapshot/delta needs
- No external dependencies

**Weaknesses:**
- Massive engineering effort: must implement reliability, ordering, fragmentation, congestion control, connection lifecycle, encryption
- Every solved problem in ENet/GNS must be re-solved and debugged
- High risk of subtle bugs (packet reordering, MTU issues, congestion collapse)
- No benefit over ENet for our use case — ENet already provides tunable reliability/ordering per channel

**Verdict:** Not justified. The engineering cost far exceeds any benefit for a small-team project.

## Decision

**Use Godot's built-in ENet (`ENetMultiplayerPeer`) for transport.**

The high-level multiplayer API (`@rpc`, MultiplayerSpawner) will be used where appropriate but NOT for core game state. The authoritative game loop — tick simulation, input processing, snapshot generation, lag compensation, hit registration — is custom code that sends data over ENet channels, not Godot's replication system.

### Architecture approach for Phase 2+

```
Client                              Server
┌────────────────────┐              ┌────────────────────┐
│ Input sampling     │              │ Input queue        │
│ Client prediction  │  ─ ENet ──>  │ Authoritative sim  │
│ Server reconcile   │  <─ ENet ──  │ Snapshot generation │
│ Entity interpolate │              │ Lag compensation   │
└────────────────────┘              └────────────────────┘
         │                                    │
    ENetMultiplayerPeer               ENetMultiplayerPeer
    (transport only)                  (transport only)
```

- **Input commands:** Client sends timestamped input structs (unreliable, sequenced)
- **Snapshots:** Server sends delta-compressed world state (unreliable, sequenced)
- **Reliable channel:** Round state, economy, chat, admin commands
- **Hit registration:** Server-side with lag compensation using input timestamps

### Migration cost to GNS (Phase 8 estimate)
If we later switch to GameNetworkingSockets for Steam Datagram Relay:
- Write a GDExtension wrapper (~1-2 weeks)
- Replace `ENetMultiplayerPeer` with GNS connection object
- Packet send/receive interface stays the same (bytes over UDP)
- Game logic unchanged — it operates on input/snapshot abstractions, not transport details
- Estimated migration: **2-3 weeks** including testing

This is acceptable. Transport is an implementation detail behind the game's networking interface.

## Open questions for Phase 4
- Optimal snapshot rate vs. tick rate (128 tick server, 64 snapshot send rate?)
- Delta compression strategy (per-entity dirty flags vs. full-state diff)
- Input redundancy (send N recent inputs per packet to handle loss)
- Interpolation buffer size (tradeoff: smoothness vs. added latency)
- Lag compensation window maximum (how far back to rewind for hit checks)

These are design decisions that require implementation and measurement, not library selection.
