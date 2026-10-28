# PHASE 4 — Dedicated Multiplayer Vertical Slice
**Status:** Not started | **Version:** 1.0 | **Date:** 2026-10-28

## Scope
Build a server-authoritative multiplayer game loop with client-side prediction, server reconciliation, entity interpolation, lag compensation for hitscan hit registration, and basic match lifecycle — playable as a 2-to-10 player LAN/remote match on a single gray-box map using the movement and combat systems from Phases 2–3.

### In scope
- Authoritative 128-tick dedicated server simulation (headless Linux)
- Client-side input sampling and timestamped input command protocol
- Client-side movement prediction (reuse Phase 2 movement code)
- Server reconciliation: client replays unacknowledged inputs on correction
- Entity interpolation for remote players (configurable buffer, default ~100ms)
- Server-side lag compensation for hitscan: rewind hitboxes to shooter's timestamp
- Snapshot generation and delta-compressed state broadcast
- Input redundancy: each packet carries N recent input frames to tolerate loss
- Player spawning, death, respawn cycle (deathmatch — no rounds yet)
- Remote player model (placeholder capsule with head, weapon indicator)
- Basic scoreboard (kills, deaths, ping)
- Disconnect/reconnect handling (rejoin within timeout window)
- Server console: kick, status, map change
- Network telemetry HUD: RTT, packet loss, interp delay, correction count, snapshot rate
- Automated regression tests for prediction, reconciliation, and damage authority
- CI: headless server + simulated client test

### Not in scope
- Teams, round system, economy, buy menu (Phase 5)
- Art models, animations, VFX, sound (Phase 6 — continue using placeholder geometry)
- NAT traversal, relay servers, matchmaking (Phase 7–8)
- Steam authentication or server browser (Phase 8)
- Anti-cheat beyond server-side validation (Phase 10)
- Voice chat (future)
- Map loading or level streaming (single compiled scene)
- Spectator mode (Phase 5)

---

## Key decisions

### Decision 1: Tick architecture — 128/64/64

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Server simulation tick | 128 Hz | Matches Phase 2–3 physics tick; GoldSrc reference fidelity |
| Client input send rate | 64 Hz | Every other tick — halves upstream bandwidth; server interpolates between input samples |
| Snapshot send rate | 64 Hz | Standard for competitive FPS (CS 1.6 uses 20–100 depending on config); 64 balances fidelity and bandwidth |

The server simulates at 128 Hz internally but sends snapshots at 64 Hz. Clients send input at 64 Hz with redundancy (last 3 inputs per packet). This matches or exceeds CS 1.6's `cl_updaterate 100 / cl_cmdrate 100` in practice.

### Decision 2: Authority model — server is law

The server is the single source of truth for all game state. Clients predict movement locally for responsiveness but never determine hit outcomes, damage, health, armor, ammo, or position authoritatively.

```
Client sends:     input_cmd { tick, move_dir, wish_speed, jump, duck, fire, weapon_action }
Server sends:     snapshot  { tick, player_states[], projectile_states[], events[] }
                  correction{ tick, position, velocity, hp, armor, ammo }
```

Clients display interpolated remote players and predicted local movement. On correction, the client replays unacknowledged inputs from the corrected state.

### Decision 3: Lag compensation — server-side rewind

When the server processes a fire input, it rewinds all player hitboxes to the shooter's perceived time (input timestamp minus half-RTT minus interpolation delay), traces the hitscan ray, then restores hitboxes. Maximum rewind window: 200ms (configurable). Beyond this window, shots use current-time hitboxes.

This is the standard model used by GoldSrc/Source and avoids client-authoritative hits entirely.

### Decision 4: Interpolation — fixed buffer with adaptive fallback

Remote entities render at `server_time - interp_delay` (default 100ms = ~6.4 snapshots at 64 Hz). The client interpolates between the two bracketing snapshots. If a snapshot is missing (packet loss), extrapolate briefly then freeze. Adaptive mode can shrink the buffer on LAN (lower latency) or grow it under jitter.

### Decision 5: Transport — ENet channels

Per the Phase 1 networking evaluation, use `ENetMultiplayerPeer` with custom channels:

| Channel | Mode | Content |
|---------|------|---------|
| 0 | Unreliable sequenced | Input commands (client→server) |
| 1 | Unreliable sequenced | Snapshots (server→client) |
| 2 | Reliable ordered | Game events: kill feed, spawn, round state, chat |
| 3 | Reliable ordered | Admin/console commands |

### Decision 6: Serialization — PackedByteArray with manual packing

No Godot `@rpc` for game state. Input commands and snapshots are manually serialized to `PackedByteArray` for bandwidth control and delta compression. This keeps the protocol independent of Godot's internals and makes it measurable.

### Decision 7: Reconciliation — replay from correction

When the client receives a snapshot where the server's authoritative position differs from the client's predicted position by more than a threshold (0.05m / ~2 GoldSrc units), the client:
1. Snaps to the server state at the corrected tick
2. Replays all unacknowledged input commands forward to the current tick
3. Smooths the visual correction over 100ms to avoid jarring teleports

This is the standard Quake/Source prediction-reconciliation model.

---

## Architecture

### Network game loop

```
SERVER (128 Hz):
  for each tick:
    1. Receive input commands from all clients (dequeue per-client input buffer)
    2. For each client with a fire command:
       a. Save all player hitbox positions
       b. Rewind hitboxes to shooter's perceived time
       c. Trace hitscan ray, compute damage
       d. Restore hitboxes
    3. Apply movement for each player using their input (same physics as client)
    4. Apply damage, update HP/armor/ammo
    5. Check death/respawn
    6. Every other tick (64 Hz): generate snapshot, delta-compress, broadcast

CLIENT (128 Hz local, 64 Hz net):
  for each tick:
    1. Sample input
    2. Predict local movement (same physics code as server)
    3. Store prediction in circular buffer [tick → state]
    4. Every other tick: send input command (with last 3 inputs)
  on snapshot received:
    1. Update server time estimate
    2. For local player: compare server state to predicted state at that tick
       - If within threshold: no correction needed
       - If diverged: snap to server state, replay inputs forward
    3. For remote players: insert into interpolation buffer
  on render:
    1. Local player: show predicted position
    2. Remote players: interpolate between two bracketing snapshots
```

### Module structure

```
shared/scripts/
├── net_constants.gd           # Tick rates, buffer sizes, thresholds
├── net_input.gd               # InputCommand struct, serialization
├── net_snapshot.gd            # Snapshot struct, delta compression
├── net_protocol.gd            # Channel IDs, message types, packet format
├── player_movement.gd         # (existing) shared movement simulation
├── weapon_system.gd           # (existing) shared weapon logic
└── weapon_constants.gd        # (existing) shared constants

server/scripts/
├── server_game.gd             # Server game loop: tick, input processing, snapshots
├── server_player.gd           # Per-player server state: input buffer, last ack
├── server_lag_comp.gd         # Hitbox rewind and restore
├── server_spawner.gd          # Spawn points, respawn timer
└── server_admin.gd            # Kick, status, map commands

client/scripts/
├── client_game.gd             # Client game loop: prediction, reconciliation
├── client_prediction.gd       # Input buffer, state replay
├── client_interpolation.gd    # Remote entity interpolation
├── client_net_hud.gd          # Network telemetry overlay
├── client_scoreboard.gd       # Kill/death/ping display
└── remote_player.gd           # Visual representation of other players
```

### Snapshot format (per player, delta-compressed)

```
PlayerState {
  peer_id:     u16
  tick:        u32
  position:    Vector3 (quantized to 0.01m precision = ~0.4 GoldSrc units)
  velocity:    Vector3 (quantized to 0.1 m/s)
  yaw:         u16 (0–65535 → 0°–360°)
  pitch:       i16 (-16384–16384 → -90°–90°)
  flags:       u8 (on_ground, is_ducked, is_scoped, is_dead)
  hp:          u8
  armor:       u8
  weapon_idx:  u8
  ammo_mag:    u8
}
```

Full player state: ~30 bytes. Delta: typically 6–12 bytes (position + flags changed). 10-player snapshot at 64 Hz: ~3–7 KB/s per client.

### Input command format

```
InputCommand {
  tick:         u32
  buttons:      u16 (forward, back, left, right, jump, duck, fire, fire2, reload, weapon1-4, use)
  yaw:          u16 (quantized)
  pitch:        i16 (quantized)
}
```

~10 bytes per command. With 3-input redundancy at 64 Hz: ~1.9 KB/s upstream.

---

## Work breakdown

### WB1: Network protocol and serialization (laptop)
- [ ] Create `shared/scripts/net_constants.gd`: tick rates, buffer sizes, channel IDs
- [ ] Create `shared/scripts/net_input.gd`: InputCommand struct with `to_bytes()` / `from_bytes()`
- [ ] Create `shared/scripts/net_snapshot.gd`: PlayerState struct, full + delta serialization
- [ ] Create `shared/scripts/net_protocol.gd`: message types, packet header, version byte
- [ ] Unit test: round-trip serialize/deserialize with known values
- [ ] Measure: packed size per player state, per input command
- **Owner:** laptop

### WB2: Server game loop (laptop + vm-prime)
- [ ] Create `server/scripts/server_game.gd`:
  - 128 Hz `_physics_process` tick loop
  - Accept connections via `NetworkManager`
  - Maintain `Dictionary[int, ServerPlayer]` for connected peers
  - Input queue per player (buffered, ordered by tick)
  - Process inputs in tick order, run shared movement + weapon physics
  - Track server tick counter (monotonic u32)
- [ ] Create `server/scripts/server_player.gd`:
  - Server-side player state: position, velocity, HP, armor, ammo, weapon
  - Input buffer (ring buffer, last 16 inputs)
  - Last acknowledged client tick
  - CharacterBody3D instance with hitbox areas (reuse Phase 3 target_dummy hitbox pattern)
- [ ] Server spawns player entities on connect, removes on disconnect
- [ ] Test: server runs headless, accepts connection, prints tick count
- **Owner:** laptop + vm-prime

### WB3: Snapshot generation and broadcast (laptop)
- [ ] Server generates full snapshot every 2nd tick (64 Hz)
- [ ] Delta compression: compare to last-acked snapshot per client, send only changed fields
- [ ] Broadcast via ENet channel 1 (unreliable sequenced)
- [ ] Include server tick number in every snapshot
- [ ] Per-client snapshot buffer (last 32 snapshots for delta reference)
- [ ] Measure: bytes per snapshot at 2, 5, 10 players
- **Owner:** laptop

### WB4: Client input sampling and sending (laptop)
- [ ] Create `client/scripts/client_game.gd`:
  - Sample input every tick from existing player_movement input system
  - Package as InputCommand with current client tick
  - Send every 2nd tick (64 Hz) via ENet channel 0 (unreliable sequenced)
  - Include last 3 inputs per packet for redundancy
  - Maintain sent-input ring buffer (last 128 inputs for reconciliation)
- [ ] Client tick counter synchronized to server tick on first snapshot
- [ ] Handle tick drift: if client tick drifts >2 ticks from server, adjust gradually
- **Owner:** laptop

### WB5: Client-side prediction (laptop)
- [ ] Client runs local movement simulation using same `player_movement.gd` physics
- [ ] Store predicted state per tick in circular buffer (tick → {position, velocity, on_ground, is_ducked})
- [ ] Prediction runs at 128 Hz locally (full tick rate)
- [ ] Local player sees predicted position immediately (no input delay)
- [ ] Weapon system runs locally for fire timing, spread display, viewpunch (cosmetic prediction)
- **Owner:** laptop

### WB6: Server reconciliation (laptop)
- [ ] On snapshot received, extract local player's authoritative state
- [ ] Compare server position at server_tick to predicted position at same tick
- [ ] If position error > 0.05m (2 GoldSrc units):
  - Snap internal state to server values (position, velocity, on_ground, is_ducked, HP, armor, ammo)
  - Replay all unacknowledged inputs from corrected tick to current tick
  - Smooth visual position over 100ms (lerp between corrected and predicted)
- [ ] Log correction events for telemetry
- [ ] Test: artificially corrupt client position, verify correction + replay
- **Owner:** laptop

### WB7: Entity interpolation (laptop)
- [ ] Create `client/scripts/client_interpolation.gd`:
  - Per-remote-player snapshot buffer (last 32 states)
  - Render time = server_time - interp_delay (default 100ms)
  - Find two bracketing snapshots, lerp position/rotation
  - Extrapolate briefly if missing snapshot (max 50ms, then freeze)
- [ ] Create `client/scripts/remote_player.gd`:
  - Capsule visual (matching player dimensions)
  - Head node that rotates with pitch/yaw
  - Weapon indicator (colored block for current weapon slot)
  - Name label above head
  - Smooth ducking transition
- [ ] Interpolation buffer auto-adjusts on LAN (lower delay) vs WAN (higher)
- **Owner:** laptop

### WB8: Lag compensation — hitscan rewind (laptop + vm-prime)
- [ ] Create `server/scripts/server_lag_comp.gd`:
  - Server stores hitbox positions for all players for last 200ms (~26 ticks at 128 Hz)
  - History buffer: ring buffer of `{tick, player_id → Transform3D}` per hitbox
  - On fire command: compute shooter's perceived time:
    `rewind_tick = input_tick - (half_rtt_ticks + interp_ticks)`
  - Rewind all non-shooter hitboxes to `rewind_tick` position
  - Run hitscan ray using server's weapon_system damage formula
  - Restore hitboxes to current positions
- [ ] Clamp rewind to maximum window (200ms / ~26 ticks)
- [ ] Server applies damage authoritatively, broadcasts kill/hit events
- [ ] Test: two players, one stationary — shooter at various simulated RTTs, verify hit registration
- **Owner:** laptop + vm-prime

### WB9: Player lifecycle — spawn, death, respawn (laptop)
- [ ] Spawn points: 4–8 predefined positions in the test map
- [ ] On death: freeze player, broadcast kill event, start respawn timer (3s)
- [ ] On respawn: teleport to random spawn point, reset HP/armor/ammo
- [ ] Death state: player drops to ground (no ragdoll — placeholder), becomes non-solid
- [ ] Kill feed: last 5 kills displayed (killer weapon victim)
- [ ] Server tracks kills/deaths per player
- **Owner:** laptop

### WB10: Scoreboard and HUD (laptop)
- [ ] Create `client/scripts/client_scoreboard.gd`:
  - Toggle with Tab key
  - Display: player name, kills, deaths, ping
  - Sorted by kills descending
- [ ] Create `client/scripts/client_net_hud.gd`:
  - Extend telemetry HUD with network section:
  - RTT (ms), packet loss (%), interp delay (ms)
  - Correction count (last 10s), snapshot rate (Hz)
  - Server tick vs client tick delta
  - Input queue depth on server (reported in snapshot)
- [ ] Ammo/HP/armor HUD displays server-authoritative values (corrected on snapshot)
- **Owner:** laptop

### WB11: Disconnect and reconnect (laptop)
- [ ] Server keeps disconnected player state for 30s timeout
- [ ] If same peer_id reconnects within timeout: restore state, resume
- [ ] If timeout expires: remove player, free slot
- [ ] Client detects disconnect: show "Reconnecting..." overlay, retry connection
- [ ] Handle mid-match join: spawn as new player with default loadout
- **Owner:** laptop

### WB12: Server admin console (laptop + vm-prime)
- [ ] Server accepts console commands from stdin (headless mode):
  - `status` — list connected players with IDs, pings
  - `kick <id>` — disconnect player
  - `say <message>` — server broadcast message
  - `quit` — graceful shutdown
- [ ] Admin commands sent via ENet channel 3 (reliable)
- [ ] Log all admin actions to stdout
- **Owner:** laptop + vm-prime

### WB13: Multiplayer test map (laptop)
- [ ] Create `shared/scenes/mp_testmap.tscn`:
  - Simple symmetric arena: ~40×40m box
  - Cover: crates, walls, pillars (CSGBox3D with collision)
  - Two elevated platforms with ramps
  - One narrow corridor/chokepoint
  - 8 spawn points (spread around map)
  - Lighting: directional + ambient (readable, no dark corners)
  - Weapon rack at center (refill ammo/grenades)
- [ ] Add to entry_point.gd: `--host` starts server + local player, `--join <ip>` connects as client
- **Owner:** laptop

### WB14: Regression tests (laptop + vm-prime)
- [ ] Create `tests/network_tests.gd`:
  - test_input_serialization: round-trip InputCommand
  - test_snapshot_serialization: round-trip PlayerState
  - test_delta_compression: verify delta is smaller than full
  - test_damage_server_authority: client cannot set own HP
  - test_weapon_maxspeed_enforced: server clamps speed to weapon max
  - test_movement_prediction_matches: client and server agree on position (no lag)
  - test_rewind_window_clamped: shots beyond 200ms use current hitboxes
- [ ] Create `tests/network_test_scene.tscn` with server + simulated client
- [ ] Add `--test-network` to entry_point.gd
- [ ] CI: add network test step to build.yml
- **Owner:** laptop + vm-prime

### WB15: Performance profiling (laptop + vm-prime)
- [ ] Measure server tick duration at 2, 5, 10 players
- [ ] Measure bandwidth per client at 64 Hz snapshot rate
- [ ] Measure client prediction replay cost (worst case: full 128-input replay)
- [ ] Measure lag compensation rewind cost (10 players, 200ms window)
- [ ] Profile with Godot's built-in profiler + custom tick timing
- [ ] Document results in `docs/network_performance.md`
- [ ] Target: server tick completes in <4ms at 10 players (50% headroom at 128 Hz = 7.8ms/tick)
- **Owner:** laptop + vm-prime

---

## Test plan

### Automated tests

| Test | Method | Pass condition |
|------|--------|---------------|
| Input serialize round-trip | Pack/unpack known values | Bit-exact match |
| Snapshot serialize round-trip | Pack/unpack 10-player state | All fields match |
| Delta smaller than full | Compare byte counts | Delta < full for 1-field change |
| Server authority: HP | Client sets HP=999, verify server ignores | Server HP unchanged |
| Server authority: position | Client teleports, verify server corrects | Correction within 2 ticks |
| Server authority: maxspeed | Client sends speed > weapon max | Server clamps to weapon max |
| Prediction accuracy | Zero-lag local, compare states | Position match within 0.01m |
| Rewind window clamp | Fire with timestamp 500ms old | Server uses current hitboxes |
| Kill/death cycle | Kill a player, wait respawn | Player respawns with full HP |

### Manual play tests (LAN, two machines)

| Scenario | Expected behavior |
|----------|-------------------|
| Walk around, see other player moving | Smooth interpolated movement, no teleporting |
| Shoot stationary target at 0ms ping | Hit registers instantly, damage matches Phase 3 |
| Shoot moving target at 50ms ping | Hit registers if crosshair was on target at fire time |
| Shoot moving target at 150ms ping | Same — lag comp rewinds hitboxes correctly |
| Both players fire simultaneously | Server resolves both hits; mutual kills possible |
| Player disconnects mid-match | Other players see them freeze then disappear |
| Player reconnects within 30s | Resumes with previous state |
| Run headless server on vm-prime, play from laptop | Full match works over network |
| 5+ players (recruit testers) | Server maintains 128 tick, no desync |
| Counter-strafe + tap on LAN | Feels identical to single-player Phase 3 |

### Latency simulation tests

| Simulated RTT | Test | Pass condition |
|---------------|------|---------------|
| 0ms (localhost) | Prediction matches server | Zero corrections |
| 50ms | Normal gameplay | <2 corrections per minute, responsive |
| 100ms | Typical internet | Hits register, movement fluid |
| 200ms | Edge of acceptable | Hits register, minor visual correction |
| 300ms+ | Degraded | Frequent corrections, still playable |

Use Godot's ENet `set_transfer_channel` or OS-level `tc` (Linux) to simulate latency.

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Prediction/reconciliation desync from floating-point divergence | High | High | Use identical code paths client/server; quantize state in snapshots; test round-trip extensively |
| Lag compensation "shot around a corner" frustration | Medium | Medium | Cap rewind window at 200ms; display attacker's ping to victim; document tradeoff |
| ENet packet loss under stress causes interpolation stutter | Medium | Medium | Input redundancy (3x), adaptive interp buffer, graceful extrapolation |
| Server tick overrun at 10 players | Low | High | Profile early (WB15); 128 Hz at 10 players is well within Godot's capability |
| Physics non-determinism between platforms (Windows vs Linux) | Medium | High | Run identical physics code; use Godot's fixed-step physics; test cross-platform |
| Snapshot bandwidth exceeds reasonable limits | Low | Medium | Delta compression; quantization; measure early; reduce snapshot rate if needed |
| Reconciliation visual correction feels jarring | Medium | Medium | Smooth corrections over 100ms; only correct above threshold; tune threshold by feel |
| Hitbox rewind buffer memory at 10 players × 200ms | Low | Low | 26 ticks × 10 players × ~50 bytes = ~13 KB — negligible |

---

## Dependencies
- Phase 2 movement system — **done** (signed off 2026-10-25)
- Phase 3 gunplay and grenades — **done** (signed off 2026-10-28)
- NetworkManager (ENet connection lifecycle) — **done** (Phase 1)
- Networking evaluation — **done** (ENet selected, Phase 1)
- Godot 4.7.2 on laptop with editor — **done**
- Godot 4.7.2 headless on vm-prime — **done**
- Two machines on same network for LAN testing — **required**

---

## Owner training exercises

### E1: Packet capture
After WB1–WB3 are working:
1. Start server on vm-prime, connect from laptop
2. Run Wireshark/tcpdump on vm-prime filtering port 27050
3. Identify input packets (client→server) and snapshot packets (server→client)
4. Count packet rate, measure average packet size
5. Compare to predicted bandwidth calculations
- **Goal:** understand what's actually on the wire; verify serialization efficiency

### E2: Artificial lag and correction
After WB5–WB6 are working:
1. Add 100ms artificial delay to client (modify send timing or use `tc`)
2. Walk forward, stop suddenly — observe any position snap-back
3. Watch correction count on network HUD
4. Increase to 200ms — feel the difference
5. Try counter-strafe shooting at each latency
- **Goal:** understand how prediction masks latency and where it breaks down

### E3: Lag compensation verification
After WB8 is working:
1. Two players: one stands still, other has 100ms artificial lag
2. Lagged player aims at stationary player's head, fires
3. Verify hit registers as headshot (not miss due to lag)
4. Now the target strafes — repeat. Verify hits register when crosshair was on target at fire time
5. Increase lag to 250ms — observe shots failing beyond rewind window
- **Goal:** feel the difference between lag compensation and no compensation; understand the 200ms window

### E4: Server authority test
After WB2 is working:
1. Modify client code to set local HP to 999
2. Get shot by another player — verify you still die (server HP is authoritative)
3. Modify client to teleport forward — verify server corrects you back
- **Goal:** understand why server authority matters and how correction works

---

## Acceptance checklist (gate criteria)

- [ ] Dedicated headless server runs at stable 128 Hz with 10 connected players
- [ ] Two players on separate machines can see and shoot each other
- [ ] Movement feels identical to single-player Phase 2/3 (prediction masks latency)
- [ ] Hits register correctly at ≤200ms RTT (lag compensation working)
- [ ] Client cannot authoritatively alter HP, position, damage, or ammo
- [ ] Server corrects client position when prediction diverges
- [ ] Remote players render smoothly (interpolation, no teleporting)
- [ ] Kill/death/respawn cycle works
- [ ] Scoreboard displays kills, deaths, ping for all players
- [ ] Network HUD shows RTT, packet loss, correction count, snapshot rate
- [ ] Disconnect/reconnect within 30s restores player state
- [ ] Server admin can kick players and view status from console
- [ ] Snapshot bandwidth is reasonable (<10 KB/s per client at 10 players)
- [ ] Server tick stays under 4ms at 10 players
- [ ] All Phase 2 movement + Phase 3 combat + Phase 4 network tests pass in CI
- [ ] All weapon/grenade constants remain configurable
- [ ] No regression in single-player movement or combat feel

---

## Demo instructions
1. **vm-prime:** Start headless server:
   ```
   godot --headless --path . -- --host
   ```
2. **Laptop:** Connect as client:
   ```
   godot --path . -- --join 192.168.30.11
   ```
3. Toggle network HUD (F1) — verify RTT, snapshot rate, tick delta
4. Walk around — movement should feel identical to Phase 3 single-player
5. Open second client (another machine or localhost): see remote player capsule moving smoothly
6. Shoot the other player:
   - Observe damage numbers (same as Phase 3 combat range)
   - Kill them — see kill feed, scoreboard updates
   - They respawn after 3s
7. Test lag compensation:
   - Add artificial latency (100ms) on client
   - Shoot a strafing target — verify hits register correctly
   - Check correction count on HUD (should be near zero on LAN)
8. Test server authority:
   - Verify HP/armor display matches server state after taking damage
   - Verify no client-side position teleport survives a server tick
9. Test disconnect:
   - Kill client process, reconnect within 30s — state restored
   - Wait >30s — spawns as new player
10. **vm-prime console:** `status` (list players), `kick 2` (boot player 2)
11. Run CI: both movement, combat, and network tests pass

---

## Suggested work order
1. **WB1** (protocol/serialization) — foundation, no networking needed yet
2. **WB2** (server game loop) + **WB4** (client input) — get a connection with input flowing
3. **WB3** (snapshots) — server sends state, client receives it
4. **WB5** (prediction) — client moves locally without waiting for server
5. **WB6** (reconciliation) — client corrects on server disagreement
6. **WB7** (interpolation) — remote players render smoothly
7. **WB8** (lag compensation) — hitscan works across latency
8. **WB9** (spawn/death/respawn) — complete game loop
9. **WB13** (test map) — playable arena (can start as a shell early)
10. **WB10** (scoreboard/HUD) — visibility into match state
11. **WB11** (disconnect/reconnect) — robustness
12. **WB12** (server console) — administration
13. **WB14** (regression tests) — automated validation
14. **WB15** (performance) — verify scalability targets

---

## Immediate next steps
1. **Laptop:** Start with WB1 (protocol) — get input and snapshot serialization tested with round-trips before any networking code
2. **Laptop:** WB2 + WB4 — minimal server accepting a client connection and processing input
3. **vm-prime:** Test headless server early — run WB2 on vm-prime as soon as it compiles
4. **Key milestone:** Two capsules on screen, one controlled locally (predicted), one remote (interpolated), shooting each other with correct Phase 3 damage — this validates the entire networking stack
