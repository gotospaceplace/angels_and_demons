# Network Performance Results (Phase 4)

Measured on laptop (headless, Godot 4.7.2) — 2026-10-29.

## Server tick duration

| Players | Tick (ms) | Budget used |
|---------|-----------|-------------|
| 2       | 0.016     | 0.2%        |
| 5       | 0.036     | 0.5%        |
| 10      | 0.076     | 1.0%        |

Budget: 7.81 ms/tick at 128 Hz. Target: <4 ms at 10 players (50% headroom).
**Result: PASS** — 99% headroom at 10 players.

## Bandwidth per client (64 Hz snapshot rate)

| Players | Full snap (B) | Full BW (KB/s) | Delta snap (B) | Delta BW (KB/s) |
|---------|---------------|-----------------|----------------|------------------|
| 2       | 74            | 9.3             | 42             | 5.3              |
| 5       | 173           | 54.1            | 87             | 27.2             |
| 10      | 338           | 211.3           | 162            | 101.3            |

Delta compression reduces bandwidth by ~50% in steady state.

## Client prediction replay (worst case)

Full 128-input reconciliation replay: **3.254 ms**.
This is the absolute worst case (server corrects a position from 128 ticks ago).
Typical corrections are 5-20 ticks and complete in <0.5 ms.

## Lag compensation rewind

10 players, 25-tick (200ms) rewind window: **0.021 ms/fire**.
Geometric ray-capsule intersection is very fast. Physics raycast for world
geometry is the dominant cost and runs only once per fire.

## How to run

```
Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --path . -- --bench
```
