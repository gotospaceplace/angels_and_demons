class_name NetConstants
extends RefCounted

# --- Tick rates ---
const TICK_RATE := 128          # Server simulation Hz
const TICK_INTERVAL := 1.0 / TICK_RATE  # ~7.8125 ms
const INPUT_SEND_RATE := 64     # Client sends input at 64 Hz (every 2nd tick)
const SNAPSHOT_SEND_RATE := 64  # Server sends snapshots at 64 Hz (every 2nd tick)

# --- Buffers ---
const INPUT_REDUNDANCY := 3     # Inputs carried per packet for loss tolerance
const INPUT_BUFFER_SIZE := 128  # Client-side ring buffer for reconciliation replay
const SNAPSHOT_BUFFER_SIZE := 32  # Per-client snapshot history for delta reference
const SERVER_INPUT_BUFFER := 16   # Per-player input queue on server

# --- Interpolation ---
const INTERP_DELAY_MS := 100.0    # Default interpolation buffer (ms)
const INTERP_DELAY_SEC := INTERP_DELAY_MS / 1000.0
const INTERP_MAX_EXTRAPOLATE_MS := 50.0  # Max extrapolation before freeze

# --- Reconciliation ---
const RECONCILE_THRESHOLD := 0.1   # Position error threshold in meters (~4 GoldSrc units)
const RECONCILE_SMOOTH_TIME := 0.2 # Visual correction smoothing (seconds)

# --- Lag compensation ---
const MAX_REWIND_MS := 200.0      # Maximum hitbox rewind window
const MAX_REWIND_TICKS := int(MAX_REWIND_MS / 1000.0 * TICK_RATE)  # ~26 ticks

# --- ENet channels ---
const CHANNEL_INPUT := 0      # Unreliable sequenced: client → server input commands
const CHANNEL_SNAPSHOT := 1   # Unreliable sequenced: server → client snapshots
const CHANNEL_EVENTS := 2     # Reliable ordered: game events (kill feed, spawn, chat)
const CHANNEL_ADMIN := 3      # Reliable ordered: admin/console commands

# --- Protocol ---
const PROTOCOL_VERSION := 1
const MAX_PLAYERS := 10

# --- Quantization precision ---
const POS_PRECISION := 0.01      # Meters (position quantization step)
const VEL_PRECISION := 0.1       # m/s (velocity quantization step)
const YAW_SCALE := 65535.0 / 360.0   # u16 → degrees
const PITCH_SCALE := 16384.0 / 90.0  # i16 → degrees

# --- Spawn / lifecycle ---
const RESPAWN_DELAY := 3.0       # Seconds before respawn after death
const DISCONNECT_TIMEOUT := 30.0 # Seconds to keep disconnected player state

# --- Tick drift ---
const TICK_DRIFT_TOLERANCE := 2  # Max ticks client can drift before adjustment
