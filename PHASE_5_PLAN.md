# PHASE 5 — Classic Competitive Rules
**Status:** Not started | **Version:** 1.0 | **Date:** 2026-11-02

## Scope
Implement the full competitive match ruleset: two-team structure, objective-based rounds (bomb plant/defuse), economy and buy system, freeze/buy period, round lifecycle and win conditions, spectator mode, walk mechanic (MP-002), and match management — producing a complete, configurable, playable 5v5 match on a single gray-box map using the networking and combat systems from Phases 2–4.

### In scope
- Two teams: Angels (defense) and Demons (attack), swappable per-map
- Team selection flow: join screen or auto-assign at connect
- MR12 format: first to 13 rounds, 12 per half, side switch at halftime
- Round lifecycle: freeze time → buy time → live round → round end → reset
- Bomb objective: plant site zones, plant/defuse interaction, bomb timer, detonation/defuse win
- Economy system: starting money, round win/loss rewards, loss bonus escalation, kill rewards
- Buy menu: weapon/grenade/armor purchasing during buy period within buy zone
- Spawn system: per-team spawn zones, freeze during freeze time
- **MP-002: Walk mechanic** — `+speed` key caps movement to ≤140 u/s for silent, accurate movement
- Spectator mode: free-cam and first-person follow after death (team-only in competitive)
- Win conditions: elimination, bomb detonation, bomb defuse, timer expiry
- Match lifecycle: warmup → half 1 → halftime → half 2 → overtime or match end
- Round timer with HUD display
- Kill rewards per weapon type (knife bonus, SMG bonus, AWP penalty)
- Configurable match parameters (round time, freeze time, starting money, all economy values)
- Team-based scoreboard (extending Phase 4 scoreboard with teams, money, rounds won)
- Chat system: team chat and all chat
- Match state synchronization: all clients see consistent round state, economy, timers
- Regression tests for round lifecycle, economy, buy rules, walk mechanic

### Not in scope
- Art models, character skins, buy menu UI polish (Phase 6)
- Lore-specific objective items per map (Phase 6 — use generic "bomb" placeholder)
- Full map roster (Phase 6+)
- Matchmaking, ELO, ranking (post-launch)
- Competitive spectator restrictions (anti-ghosting, observer delay) — basic spectating only
- Voice chat
- Vote system (vote kick, vote map)
- Overtime rules beyond simple extension (tournament configs deferred)
- Bot AI for filling empty slots
- Tournament/match server mode (GOTV equivalent)

---

## Key decisions

### Decision 1: Round lifecycle state machine

```
WARMUP → FREEZE_TIME → BUY_TIME → LIVE → ROUND_OVER → FREEZE_TIME → ...
                                                     → HALFTIME → FREEZE_TIME → ...
                                                     → MATCH_OVER
```

| State | Duration | Behavior |
|-------|----------|----------|
| WARMUP | Until enough players (configurable, default 2) | Free movement, infinite money, respawn on death, no score |
| FREEZE_TIME | 5s (configurable) | Players frozen at spawn, can buy, round timer not ticking |
| BUY_TIME | 15s from round start (configurable) | Players can move, buy zone active, round timer starts |
| LIVE | Round time 1:55 (configurable) | Normal gameplay, buy zone closed |
| ROUND_OVER | 5s (configurable) | Score awarded, kill reward/loss bonus calculated, short celebration |
| HALFTIME | 15s (configurable) | Teams swap sides, economy resets, swap spawns |
| MATCH_OVER | — | Final scoreboard, disconnect or new match |

All timers are server-authoritative and broadcast to clients each snapshot.

### Decision 2: Economy model — CS 1.6 inspired, tuned for MR12

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Starting money | $800 | Classic CS, forces pistol round |
| Max money | $16000 | CS 1.6 standard |
| Round win (elimination) | $3250 | Slightly above CS 1.6's $3250 — standard |
| Round win (bomb detonation) | $3500 | Attackers rewarded for completing objective |
| Round win (bomb defuse) | $3500 | Defenders rewarded for completing objective |
| Round win (time expiry) | $3250 | Defense wins on timer |
| Round loss (base) | $1400 | First consecutive loss |
| Loss bonus escalation | +$500 per consecutive loss | $1400, $1900, $2400, $2900, $3400 (max) |
| Loss bonus reset | On round win | Winning resets loss streak to 0 |
| Bomb plant bonus | $800 (attacker team, all alive) | Reward for site take even if round lost |
| Kill reward (rifle) | $300 | Standard |
| Kill reward (SMG) | $600 | Incentivizes eco-round SMG buys |
| Kill reward (sniper) | $100 | AWP economy penalty (CS-standard) |
| Kill reward (pistol) | $300 | Standard |
| Kill reward (knife) | $1500 | High risk, high reward |
| Kill reward (grenade) | $300 | Standard |

All values are server-configurable. MR12's shorter halves mean economy pressure starts faster — the escalating loss bonus prevents total snowballs while still rewarding winning streaks.

### Decision 3: Buy system

- Buy zone: defined area near each team's spawn (Area3D trigger)
- Buy period: first 15 seconds of each round (overlaps with freeze time)
- Buy menu: radial or grid UI (placeholder functional layout, no art)
- Cannot buy enemy team's exclusive weapons (attack rifle on defense, etc.)
- Cannot buy if insufficient funds
- Cannot buy duplicate weapons in same slot (replaces current)
- Dropped weapons can be picked up (use key on ground weapon)
- Weapons persist across rounds if player survives; reset to knife + starter pistol on death
- Armor persists across rounds if player survives; can "top up" armor in buy menu

### Decision 4: Bomb objective

- Two bomb sites per map (A and B), marked with Area3D trigger zones
- One attacker spawns with the bomb (random selection per round, configurable)
- Plant interaction: hold use key for 3.5s while in bomb site zone and on ground
- Cannot plant while jumping, on ladder, or in air
- Bomb timer: 40s from plant to detonation (configurable)
- Defuse interaction: hold use key for 10s (5s with defuse kit, configurable)
- Cannot defuse while jumping or in air
- Bomb dropped on carrier death — any attacker can pick it up
- If bomb is planted, round timer is paused — round ends on detonation or defuse
- Bomb visual: placeholder cube with blinking light
- Bomb audio: beeping that accelerates as timer approaches zero (placeholder)

### Decision 5: Walk mechanic (MP-002) — `+speed` as walk toggle

CS 1.6's `+speed` key (Shift) caps the player's movement input so they stay below the movement inaccuracy threshold (140 u/s / 3.556 m/s). This produces:
- **Silent movement:** footsteps suppressed when speed ≤ 140 u/s
- **Full accuracy:** weapon spread uses standing (accurate) values, not running penalty
- **Slower pace:** ~56% of knife maxspeed, ~63% of AK maxspeed

Implementation:
```
When walk key held:
  wish_speed = min(wish_speed, WALK_SPEED_CAP)

WALK_SPEED_CAP = 140 u/s × METERS_PER_UNIT = 3.556 m/s
```

This is intentionally simple — it caps `wish_speed` in the input processing, before acceleration. The result is that the player smoothly decelerates to walk speed when the key is pressed and accelerates back to run speed when released.

Walk speed varies by weapon because it caps at 140 u/s regardless of weapon maxspeed:
| Weapon | Run speed | Walk speed | Walk % |
|--------|-----------|------------|--------|
| Knife | 250 u/s | 140 u/s | 56% |
| Pistol | 250 u/s | 140 u/s | 56% |
| M4A1 | 230 u/s | 140 u/s | 61% |
| AK-47 | 221 u/s | 140 u/s | 63% |
| AWP | 210 u/s | 140 u/s | 67% |
| AWP scoped | 150 u/s | 140 u/s | 93% |

The 140 u/s threshold is already defined in `movement_constants.gd` as `INACCURACY_SPEED_THRESHOLD`. The walk cap reuses this constant — they are the same value by design, so walking always grants full accuracy.

Duck-walking already stays below 140 u/s (ducked = 0.333× maxspeed ≈ 83 u/s for knife). Walk and duck can be combined; the result is whichever cap is lower (always duck speed).

### Decision 6: Spectator mode

- On death: camera stays at death position for 2s, then enters spectator
- Spectator modes: first-person follow (cycle with mouse1/mouse2), free-cam (press space)
- In competitive: can only spectate own team (anti-ghosting)
- Spectator HUD: watched player's name, HP, armor, weapon, ammo
- Spectators hear only what the watched player would hear (no global audio)
- Press M to toggle minimap/radar (placeholder — Phase 6 art)

### Decision 7: Team management

- On connect: team selection screen (Angels / Demons / Auto-assign / Spectate)
- Auto-assign places player on team with fewer members
- Mid-match team switch: allowed during warmup, blocked during live match (configurable)
- Team balance enforcement: configurable max difference (default 1) — can't join team that's ahead by N players
- All-talk: configurable (off in competitive default — dead players can only hear dead teammates)

---

## Plugin Architecture

### Design goals

The core engine provides **primitives only**: movement, combat, networking, player lifecycle, and a plugin API. All game mode logic — deathmatch, competitive, PUG, custom modes — lives in server-side plugins. This means:

- **No hardcoded game modes** in the engine. The current deathmatch behavior in `server_game.gd` is extracted into `plugin_deathmatch.gd`.
- **Competitive rules** (rounds, economy, bomb, teams) are `plugin_competitive.gd`, not engine code.
- **Cross-cutting features** (voting, admin tools, chat moderation) are independent plugins that work with any mode.
- **Server operators** pick a mode plugin + optional feature plugins via config. Community can write custom plugins in GDScript.

### Analogy

Like CS 1.6's architecture: the HL engine provides physics/rendering/networking, `cstrike` is the game mode DLL, and AMX Mod X plugins hook into both. Here, the engine is the Godot project (Phases 1–4), game mode plugins replace the `cstrike` DLL, and feature plugins replace AMXX.

### Plugin base class

```gdscript
# shared/scripts/game_plugin.gd
class_name GamePlugin extends RefCounted

# --- Identity ---
func get_plugin_name() -> StringName: return &""
func get_plugin_version() -> String: return "1.0"
func get_description() -> String: return ""

# --- Lifecycle ---
func on_load(manager: PluginManager) -> void: pass
func on_unload() -> void: pass
func on_map_load(map_name: String) -> void: pass
func on_tick(tick: int, delta: float) -> void: pass

# --- Cvar registration (called once at load) ---
func register_cvars(cvar: CvarRegistry) -> void: pass

# --- Player lifecycle ---
func on_player_connect(peer_id: int) -> bool: return true       # false = deny
func on_player_disconnect(peer_id: int) -> void: pass
func on_player_pre_spawn(peer_id: int) -> bool: return true     # false = delay/block spawn
func on_player_spawn(peer_id: int, position: Vector3) -> void: pass
func can_player_respawn(peer_id: int) -> bool: return true      # competitive: false mid-round
func get_spawn_position(peer_id: int) -> Vector3: return Vector3.ZERO  # return ZERO = use default

# --- Combat ---
func on_player_damage(attacker_id: int, victim_id: int, damage: float,
        weapon_idx: int, hitgroup: String) -> float: return damage    # can modify damage
func on_player_kill(killer_id: int, victim_id: int, weapon_idx: int, headshot: bool) -> void: pass
func on_player_death(peer_id: int, killer_id: int) -> void: pass
func can_player_fire(peer_id: int) -> bool: return true          # freeze time: false

# --- Movement ---
func can_player_move(peer_id: int) -> bool: return true          # freeze time: false
func on_player_movement(peer_id: int, position: Vector3, velocity: Vector3) -> void: pass

# --- Economy (raised by economy-aware plugins) ---
func on_money_change(peer_id: int, old_amount: int, new_amount: int) -> void: pass
func can_purchase(peer_id: int, item: StringName, price: int) -> bool: return true
func on_purchase(peer_id: int, item: StringName, price: int) -> void: pass

# --- Bomb (raised by bomb-aware plugins) ---
func on_bomb_plant_start(peer_id: int, site: StringName) -> bool: return true  # false = block
func on_bomb_planted(peer_id: int, site: StringName, position: Vector3) -> void: pass
func on_bomb_defuse_start(peer_id: int) -> bool: return true
func on_bomb_defused(peer_id: int) -> void: pass
func on_bomb_detonated(position: Vector3) -> void: pass
func on_bomb_dropped(position: Vector3) -> void: pass
func on_bomb_picked_up(peer_id: int) -> void: pass

# --- Round lifecycle (raised by round-based plugins) ---
func on_round_start(round_number: int) -> void: pass
func on_round_end(winner_team: int, reason: StringName) -> void: pass
func on_freeze_start() -> void: pass
func on_freeze_end() -> void: pass
func on_match_start() -> void: pass
func on_match_end(winner_team: int) -> void: pass
func on_halftime() -> void: pass

# --- Teams ---
func on_team_assign(peer_id: int, team: int) -> bool: return true  # false = deny
func get_player_team(peer_id: int) -> int: return 0                # 0 = unassigned

# --- Chat / admin ---
func on_chat_message(peer_id: int, message: String, team_only: bool) -> String: return message  # empty = block
func on_console_command(cmd: String, args: String) -> bool: return false  # true = handled

# --- Client notification ---
func get_client_mode() -> StringName: return &""  # sent to clients on connect so they load correct UI
func get_client_state() -> Dictionary: return {}  # custom state broadcast to clients each snapshot
```

### Plugin manager

```gdscript
# server/scripts/plugin_manager.gd
class_name PluginManager extends Node

var plugins: Array[GamePlugin] = []
var cvar_registry: CvarRegistry

func load_plugin(plugin: GamePlugin) -> void:
    plugin.register_cvars(cvar_registry)
    plugin.on_load(self)
    plugins.append(plugin)

func unload_plugin(plugin: GamePlugin) -> void:
    plugin.on_unload()
    plugins.erase(plugin)
```

**Hook dispatch** uses direct method calls — every loaded plugin receives every hook. With 2–5 plugins at 128 Hz, the overhead of calling through empty base methods is negligible (<1 μs/tick). No signal registration or hook maps needed.

**Hook ordering and return values:**
- **Void hooks** (`on_player_kill`, `on_round_start`): all plugins called in load order.
- **Bool hooks** (`can_player_respawn`, `can_player_fire`): all plugins called; if ANY returns `false`, the action is blocked. This lets a vote plugin freeze a player independently from the competitive plugin.
- **Modifier hooks** (`on_player_damage` → returns damage): plugins chain — output of one feeds into the next. Load order matters here (mode plugin first, then modifiers).
- **Provider hooks** (`get_spawn_position`): first non-default return wins. Mode plugin should be first in load order.

### Cvar system

Server-configurable variables (like CS's `mp_roundtime`, `mp_freezetime`, etc.) that plugins register and the server operator overrides via config file or console.

```gdscript
# shared/scripts/cvar_registry.gd
class_name CvarRegistry extends RefCounted

var _cvars: Dictionary = {}   # name → {value, default, type, description, plugin}

func register(name: String, default_value: Variant, description: String, plugin: StringName) -> void:
    _cvars[name] = {
        "value": default_value,
        "default": default_value,
        "type": typeof(default_value),
        "description": description,
        "plugin": plugin,
    }

func get_value(name: String) -> Variant:
    if _cvars.has(name):
        return _cvars[name]["value"]
    return null

func get_int(name: String) -> int: return int(get_value(name))
func get_float(name: String) -> float: return float(get_value(name))
func get_bool(name: String) -> bool: return bool(get_value(name))

func set_value(name: String, value: Variant) -> bool:
    if not _cvars.has(name):
        return false
    _cvars[name]["value"] = value
    return true

func load_config(path: String) -> void:
    # Load from server.cfg: "mp_roundtime 115" per line
    var file := FileAccess.open(path, FileAccess.READ)
    if not file: return
    while not file.eof_reached():
        var line := file.get_line().strip_edges()
        if line.is_empty() or line.begins_with("#") or line.begins_with("//"):
            continue
        var parts := line.split(" ", false, 1)
        if parts.size() == 2 and _cvars.has(parts[0]):
            _apply_typed(parts[0], parts[1])

func list_cvars() -> Array[Dictionary]:
    # For console "cvarlist" command
    var result: Array[Dictionary] = []
    for name in _cvars:
        result.append({"name": name, "value": _cvars[name]["value"],
            "default": _cvars[name]["default"], "description": _cvars[name]["description"]})
    return result
```

**Server config file** (`server.cfg`):
```
# Game mode plugin (only one active)
game_plugin competitive

# Optional feature plugins (loaded in order after mode plugin)
plugin vote
plugin admin_tools

# Cvar overrides
mp_roundtime 115
mp_freezetime 5
mp_startmoney 800
mp_maxrounds 24
mp_buytime 15
```

### How server_game.gd changes

`server_game.gd` becomes a thin shell that drives the plugin hooks. Current hardcoded behavior moves to `plugin_deathmatch.gd`:

```
Before (hardcoded deathmatch):
  _process_respawns() → always respawn after timer

After (plugin-driven):
  _process_respawns() → for each dead player:
    if plugin_manager.can_player_respawn(peer_id):
      var pos = plugin_manager.get_spawn_position(peer_id)
      if pos == Vector3.ZERO: pos = default_spawn()
      sp.respawn(pos)

Before (hardcoded FFA):
  on_kill → sp.kills += 1, broadcast kill event

After (plugin-driven):
  on_kill → plugin_manager.on_player_kill(killer, victim, weapon, headshot)
    → deathmatch plugin: just counts kills
    → competitive plugin: awards kill money, checks elimination win
```

**Key refactoring points in `server_game.gd`:**

| Current code | Hook inserted | Plugin handles |
|---|---|---|
| `_spawn_new_player()` | `on_player_pre_spawn()`, `get_spawn_position()` | Team-based spawn selection |
| `_process_respawns()` | `can_player_respawn()` | Block respawn during live rounds |
| `_process_fire_commands()` → damage | `on_player_damage()` | Friendly fire rules, armor |
| `_process_fire_commands()` → kill | `on_player_kill()`, `on_player_death()` | Economy rewards, elimination check |
| `_physics_process()` tick | `on_tick()` | Round timer, freeze timer, bomb timer |
| `_on_console_command()` | `on_console_command()` | Mode-specific commands |

### Client-side mode loading

Clients don't run plugins — they load **UI modules** based on the mode the server reports. On connect, the server sends the active mode name (from `get_client_mode()`). The client uses this to load the appropriate UI:

```
Mode "deathmatch" → client loads:
  - Kill feed (existing)
  - Scoreboard (existing)
  - Frag counter HUD

Mode "competitive" → client loads:
  - Kill feed (existing)
  - Team scoreboard (extended)
  - Round timer HUD
  - Money display
  - Buy menu
  - Bomb status indicators
  - Spectator camera
  - Team selection screen
  - Freeze-time overlay
```

The server broadcasts custom match state (round number, timer, bomb state, team scores) via a new reliable event type (`EVT_MATCH_STATE`). Client UI modules read this — they don't need to know the plugin internals.

```gdscript
# New event subtype
const EVT_MATCH_STATE := 7

# Broadcast by competitive plugin every state change
# Format: match_state(u8) + round_number(u8) + round_timer(f32) +
#          angels_score(u8) + demons_score(u8) + bomb_state(u8) + bomb_timer(f32)
```

### Built-in plugins

**Shipped with the game (in `plugins/` directory):**

| Plugin | Type | Description |
|--------|------|-------------|
| `plugin_deathmatch.gd` | Mode | FFA respawn, frag limit, time limit — extracts current Phase 4 behavior |
| `plugin_competitive.gd` | Mode | MR12 rounds, teams, economy, bomb, freeze/buy, spectator |
| `plugin_pug.gd` | Mode | Extends competitive: ready-up, captain pick, map vote, knife round |
| `plugin_vote.gd` | Feature | Generic vote system (kick, map, restart, pause) — any mode |
| `plugin_admin.gd` | Feature | Admin commands (slap, slay, ban, team swap) — any mode |
| `plugin_chat.gd` | Feature | Team/all chat, dead chat rules, rate limiting |

**Only one mode plugin active at a time.** Feature plugins stack on top of any mode.

### Plugin-to-plugin communication

Plugins can find and call each other through the manager:

```gdscript
# In plugin_vote.gd — needs to know teams for vote counting
var comp = manager.get_plugin(&"competitive")
if comp:
    var team = comp.get_player_team(peer_id)
```

For decoupled communication, plugins can emit custom events through the manager's event bus:

```gdscript
# PluginManager provides:
signal plugin_event(event_name: StringName, data: Dictionary)

# Competitive plugin emits:
manager.plugin_event.emit(&"round_start", {"round": 5, "half": 1})

# Vote plugin listens:
func on_load(manager: PluginManager) -> void:
    manager.plugin_event.connect(_on_plugin_event)
```

### Plugin file structure

```
plugins/
├── game_plugin.gd             # Base class (shared/scripts/)
├── plugin_manager.gd          # Manager (server/scripts/)
├── cvar_registry.gd           # Cvar system (shared/scripts/)
├── modes/
│   ├── plugin_deathmatch.gd   # FFA deathmatch (extracted from server_game.gd)
│   └── plugin_competitive.gd  # Competitive MR12
│       ├── competitive_economy.gd    # Economy calculations (internal module)
│       ├── competitive_rounds.gd     # Round state machine (internal module)
│       ├── competitive_bomb.gd       # Bomb logic (internal module)
│       ├── competitive_teams.gd      # Team management (internal module)
│       └── competitive_spawns.gd     # Team-based spawning (internal module)
└── features/
    ├── plugin_vote.gd          # Vote system
    ├── plugin_admin.gd         # Admin tools
    └── plugin_chat.gd          # Chat system
```

The competitive plugin uses **internal modules** for organization, but they are not independent plugins — they're helper classes that `plugin_competitive.gd` owns and orchestrates. This keeps the competitive ruleset cohesive while the code stays navigable.

### Cvar reference (competitive plugin)

| Cvar | Default | Description |
|------|---------|-------------|
| `mp_roundtime` | 115 | Round time in seconds (1:55) |
| `mp_freezetime` | 5 | Freeze time in seconds |
| `mp_buytime` | 15 | Buy period in seconds from round start |
| `mp_startmoney` | 800 | Starting money |
| `mp_maxmoney` | 16000 | Maximum money cap |
| `mp_maxrounds` | 24 | Total rounds (MR12 = 24) |
| `mp_halftime` | 12 | Round to trigger halftime |
| `mp_win_reward_elimination` | 3250 | Reward for elimination win |
| `mp_win_reward_bomb` | 3500 | Reward for bomb detonation/defuse win |
| `mp_win_reward_time` | 3250 | Reward for timer expiry win |
| `mp_loss_base` | 1400 | First consecutive loss reward |
| `mp_loss_escalation` | 500 | Per-loss bonus increase |
| `mp_loss_max` | 3400 | Maximum loss bonus |
| `mp_bomb_timer` | 40 | Bomb detonation timer in seconds |
| `mp_plant_time` | 3.5 | Plant interaction time in seconds |
| `mp_defuse_time` | 10.0 | Defuse time without kit |
| `mp_defuse_time_kit` | 5.0 | Defuse time with kit |
| `mp_bomb_plant_reward` | 800 | Plant bonus for surviving attackers |
| `mp_friendlyfire` | 0 | Friendly fire enabled (0/1) |
| `mp_autoteambalance` | 1 | Auto team balance (0/1) |
| `mp_warmup_time` | 60 | Warmup duration in seconds |
| `mp_min_players` | 2 | Minimum players to start match |

| Cvar | Default | Description |
|------|---------|-------------|
| `mp_kill_reward_rifle` | 300 | Kill reward: rifle |
| `mp_kill_reward_smg` | 600 | Kill reward: SMG |
| `mp_kill_reward_sniper` | 100 | Kill reward: sniper |
| `mp_kill_reward_pistol` | 300 | Kill reward: pistol |
| `mp_kill_reward_knife` | 1500 | Kill reward: knife |
| `mp_kill_reward_grenade` | 300 | Kill reward: grenade |

| Cvar (deathmatch) | Default | Description |
|------|---------|-------------|
| `dm_fraglimit` | 50 | Frag limit to win |
| `dm_timelimit` | 600 | Time limit in seconds |
| `dm_respawn_delay` | 3.0 | Respawn delay in seconds |

---

## Architecture

### Match state machine

```
Server (server_match.gd):
  match_state: enum {WARMUP, FREEZE, LIVE, ROUND_OVER, HALFTIME, MATCH_OVER}
  round_number: int
  rounds_won: {team_angels: int, team_demons: int}
  round_timer: float
  bomb_state: enum {CARRIED, DROPPED, PLANTING, PLANTED, DEFUSING, DETONATED, DEFUSED}
  bomb_timer: float
  economy: Dictionary[int, PlayerEconomy]  # peer_id → money, loss_streak

  _physics_process(delta):
    match match_state:
      WARMUP: check player count, transition to FREEZE when ready
      FREEZE: tick freeze timer, allow buying
      LIVE: tick round timer, process bomb state, check win conditions
      ROUND_OVER: tick celebration timer, compute economy, transition
      HALFTIME: swap teams, reset economy, transition to FREEZE
      MATCH_OVER: broadcast final scores
```

### Module structure (plugin-based)

```
shared/scripts/
├── game_plugin.gd             # Base class for all server plugins
├── cvar_registry.gd           # Server-configurable variable system
├── team.gd                    # Team enum, team utilities
└── bomb.gd                    # Bomb entity (plant/defuse interaction, timer)

server/scripts/
├── plugin_manager.gd          # Loads plugins, dispatches hooks, manages cvars
├── server_game.gd             # Thin shell: drives plugin hooks at each decision point (refactored)
└── server_console.gd          # Console I/O (existing, extended with cvarlist/plugin cmds)

plugins/modes/
├── plugin_deathmatch.gd       # FFA deathmatch (extracted from current server_game.gd)
└── plugin_competitive.gd      # MR12 competitive mode — orchestrates internal modules:
    ├── competitive_economy.gd     # Economy: money, rewards, loss bonus, purchase validation
    ├── competitive_rounds.gd      # Round state machine: freeze/live/over/halftime/match
    ├── competitive_bomb.gd        # Bomb plant/defuse, timer, win conditions
    ├── competitive_teams.gd       # Team assignment, balance, halftime swap
    └── competitive_spawns.gd      # Per-team spawn zones, equipment persistence

plugins/features/
├── plugin_vote.gd             # Vote system (kick, map, restart, pause)
├── plugin_admin.gd            # Admin commands (slap, slay, ban, team swap)
└── plugin_chat.gd             # Team/all chat, dead chat rules, rate limiting

client/scripts/
├── client_mode_loader.gd      # Reads mode from server, loads correct UI modules
├── client_buy_menu.gd         # Buy menu UI (functional placeholder)
├── client_spectator.gd        # Spectator camera, follow mode, free-cam
├── client_match_hud.gd        # Round timer, team scores, money display, bomb status
├── client_team_select.gd      # Team selection screen
└── client_chat.gd             # Team and all chat input/display
```

### Walk mechanic integration (MP-002)

```
movement_constants.gd:
  + const WALK_SPEED_CAP := INACCURACY_SPEED_THRESHOLD  # 140 u/s = 3.556 m/s

player_movement.gd:
  + var wants_walk := false

  _read_input():
    + wants_walk = Input.is_action_pressed("walk")

  simulate_tick():
    (after wish_speed calculation, before ducking multiplier)
    + if wants_walk:
    +     wish_speed = minf(wish_speed, MC.WALK_SPEED_CAP)

  apply_network_input():
    + add walk: bool parameter
    + wants_walk = walk

net_input.gd (Phase 4):
  InputCommand.buttons:
    + add WALK bit to button flags

SoundManager:
  update_footsteps():
    + suppress footsteps when h_speed <= MC.WALK_SPEED_CAP
    (already partially handled — footstep volume/interval may need threshold check)
```

### Snapshot extensions

```
PlayerState (Phase 4 format, extended):
  + team:         u8   (0=unassigned, 1=angels, 2=demons, 3=spectator)
  + money:        u16  (0–16000)
  + is_walking:   1 bit (flag)
  + has_bomb:     1 bit (flag)
  + has_defuse_kit: 1 bit (flag)

MatchState (new, broadcast reliable on state change):
  match_state:    u8
  round_number:   u8
  round_timer:    f32
  angels_score:   u8
  demons_score:   u8
  bomb_state:     u8
  bomb_timer:     f32  (only when planted)
  bomb_position:  Vector3 (only when dropped/planted)
```

### Buy menu weapon/equipment pricing

| Item | Price | Slot | Side |
|------|-------|------|------|
| Starter Pistol (Offense) | Free (spawn) | Pistol | Attack |
| Starter Pistol (Defense) | Free (spawn) | Pistol | Defense |
| Heavy Pistol | $700 | Pistol | Both |
| Assault Rifle (AK arch.) | $2700 | Primary | Attack |
| Carbine (M4 arch.) | $3100 | Primary | Defense |
| Scout | $2750 | Primary | Both |
| Heavy Sniper (AWP arch.) | $4750 | Primary | Both |
| Fast SMG | $1250 | Primary | Both |
| Heavy SMG | $1500 | Primary | Both |
| Kevlar vest | $650 | Armor | Both |
| Kevlar + helmet | $1000 | Armor | Both |
| Defuse kit | $400 | Equipment | Defense |
| HE grenade | $300 | Grenade | Both |
| Flashbang | $200 | Grenade | Both |
| Smoke grenade | $300 | Grenade | Both |

Prices are server-configurable. The 10-weapon roster from the GDD may not be fully implemented in Phase 5 (only the 4+knife from Phase 3 are code-complete); additional weapons get placeholder stats and are wired into the buy menu so the economy and slot system works.

---

## Work breakdown

### WB1: Walk mechanic — MP-002 (laptop)
- [ ] Add `WALK_SPEED_CAP` to `movement_constants.gd` (reuse `INACCURACY_SPEED_THRESHOLD`)
- [ ] Add `walk` input action to InputMap (default: Shift)
- [ ] Add `wants_walk` state to `player_movement.gd`
- [ ] In `_read_input()`: read walk key state
- [ ] In `simulate_tick()`: cap `wish_speed` to `WALK_SPEED_CAP` when walking
- [ ] In `apply_network_input()`: add `walk` parameter, set `wants_walk`
- [ ] In Phase 4 `net_input.gd`: add WALK bit to InputCommand buttons
- [ ] Footstep suppression: update `SoundManager.update_footsteps()` to suppress when `h_speed ≤ WALK_SPEED_CAP`
- [ ] Verify weapon accuracy system reads speed correctly (walk speed stays below 140 u/s → full accuracy)
- [ ] Test: walk + AK gives standing accuracy, run + AK gives moving accuracy
- [ ] Test: walk speed is exactly 140 u/s regardless of weapon
- [ ] Test: walk + duck = duck speed (lower cap wins)
- [ ] Test: walk key in air has no effect (air movement unchanged)
- **Owner:** laptop

### WB2: Plugin system foundation + team utilities (laptop)
- [ ] Create `shared/scripts/game_plugin.gd`: base class with all virtual hook methods
- [ ] Create `shared/scripts/cvar_registry.gd`: server-configurable variable system
  - `register()`, `get_value()`, `set_value()`, `load_config()`, `list_cvars()`
  - Type-safe getters: `get_int()`, `get_float()`, `get_bool()`
  - Load from `server.cfg` format: `cvar_name value` per line
- [ ] Create `server/scripts/plugin_manager.gd`: plugin loading, hook dispatch, cvar ownership
  - `load_plugin()`, `unload_plugin()`, `get_plugin(name)`
  - Hook dispatch: iterate plugins in load order, handle bool/modifier/provider return types
  - `plugin_event` signal for decoupled plugin-to-plugin communication
- [ ] Create `shared/scripts/team.gd`: team utility functions
  - Team enum: UNASSIGNED, ANGELS, DEMONS, SPECTATOR
  - Opposing team lookup
  - Team color constants (blue, red)
  - Team name strings
- [ ] Refactor `server_game.gd`: insert plugin hooks at all decision points
  - Player spawn → `on_player_pre_spawn()`, `get_spawn_position()`
  - Respawn → `can_player_respawn()`
  - Damage → `on_player_damage()`
  - Kill → `on_player_kill()`, `on_player_death()`
  - Tick → `on_tick()`
  - Console → `on_console_command()`
  - Add `cvarlist` and `plugin` console commands
- [ ] Create `plugins/modes/plugin_deathmatch.gd`: extract current FFA behavior
  - `can_player_respawn()` → true (after delay)
  - `get_spawn_position()` → random from map spawns
  - Register cvars: `dm_fraglimit`, `dm_timelimit`, `dm_respawn_delay`
  - `get_client_mode()` → `&"deathmatch"`
- [ ] Server loads plugin from config (`game_plugin` line in `server.cfg`)
- [ ] Add `EVT_MATCH_STATE` event type to `net_protocol.gd`
- [ ] Client `client_mode_loader.gd`: read mode from server, load appropriate UI modules
- [ ] Test: server starts with deathmatch plugin, existing gameplay unchanged (regression)
- [ ] Test: cvar system loads config, console can query/change values
- **Owner:** laptop

### WB3: Competitive economy module (laptop)
- [ ] Create `plugins/modes/competitive_economy.gd` (internal module of competitive plugin):
  - Per-player money tracking (Dictionary[peer_id, int])
  - `award_round_win(team)`: distribute win reward (reads cvars)
  - `award_round_loss(team)`: distribute loss reward with streak bonus
  - `award_kill(killer_id, weapon_type)`: per-weapon kill reward (reads cvars)
  - `award_bomb_plant(team)`: plant bonus to surviving attackers
  - `purchase(peer_id, item, price)`: validate and deduct money
  - `reset_economy()`: halftime reset (all to starting money)
  - Loss streak tracking per team
  - All values read from cvar_registry (no hardcoded constants)
- [ ] Create `shared/scripts/economy_helpers.gd`:
  - Shared economy calculation helpers (for client-side buy menu validation)
  - Client reads own money from snapshot; helpers validate "can I afford this?"
- [ ] Test: loss bonus escalation ($1400 → $1900 → $2400 → $2900 → $3400 cap)
- [ ] Test: win resets loss streak
- [ ] Test: bomb plant awards $800 to all surviving attackers
- [ ] Test: cannot spend more money than available
- [ ] Test: changing cvars at runtime changes economy behavior
- **Owner:** laptop

### WB4: Competitive plugin — round lifecycle (laptop + vm-prime)
- [ ] Create `plugins/modes/plugin_competitive.gd`:
  - Orchestrates internal modules (economy, rounds, bomb, teams, spawns)
  - Implements `GamePlugin` hooks: all combat, player, tick, team hooks
  - Register all competitive cvars (see Plugin Architecture → Cvar reference)
  - `get_client_mode()` → `&"competitive"`
  - `get_client_state()` → match state dict for client HUD
- [ ] Create `plugins/modes/competitive_rounds.gd` (internal module):
  - State machine: WARMUP, FREEZE, LIVE, ROUND_OVER, HALFTIME, MATCH_OVER
  - Round timer (server-authoritative, counts down during LIVE)
  - Freeze timer (counts down during FREEZE)
  - Round start: reset player positions to team spawns, restore weapons/armor for survivors
  - Round end: determine winner, trigger economy rewards, broadcast round result
  - Halftime: swap team sides, reset economy, swap spawn zones
  - Match end: check win condition (first to 13), broadcast final result
  - Warmup: free respawn, infinite money, waiting for player count
  - Emits `plugin_event` signals: `round_start`, `round_end`, `halftime`, etc.
- [ ] Plugin hooks wired:
  - `can_player_respawn()` → false during LIVE/ROUND_OVER
  - `can_player_fire()` → false during FREEZE
  - `can_player_move()` → false during FREEZE
  - `on_tick()` → advance round state machine
  - `on_player_kill()` → check elimination win, award kill money
- [ ] Broadcast MatchState (`EVT_MATCH_STATE`) on every state transition (reliable channel)
- [ ] Broadcast round timer in snapshot metadata
- [ ] Handle player disconnect during match (hold slot for reconnect — uses existing Phase 4 system)
- [ ] Test: server loads competitive plugin, round cycle WARMUP → FREEZE → LIVE → ROUND_OVER
- [ ] Test: halftime triggers at round 12, teams swap
- [ ] Test: match ends when one team reaches 13 wins
- [ ] Test: switching `game_plugin` from competitive to deathmatch works
- **Owner:** laptop + vm-prime

### WB5: Competitive plugin — spawn system (laptop)
- [ ] Create `plugins/modes/competitive_spawns.gd` (internal module):
  - Per-team spawn zones (reads Area3D markers from map)
  - Spawn point selection: distribute players across team's available points
  - `get_spawn_position(peer_id)` → returns position from correct team's spawn zone
  - Freeze-time spawn: teleport all alive players to team spawns
  - Equipment persistence: alive players keep weapons/armor from previous round
  - Dead players respawn with knife + starter pistol + starting armor (none)
  - Halftime swap: swap which spawn zone each team uses
- [ ] Plugin hooks wired:
  - `get_spawn_position()` → team-based spawn selection
  - `can_player_move()` → false during freeze time (handled by rounds module)
  - `on_round_start()` → teleport, restore equipment
  - `on_player_death()` → mark for spectator, no respawn
- [ ] Deathmatch plugin already handles its own spawning (random from map spawns)
- [ ] Update test map: add two team spawn areas (A-side, B-side) as named Node3D groups
- **Owner:** laptop

### WB6: Competitive plugin — bomb objective (laptop)
- [ ] Create `shared/scripts/bomb.gd`:
  - Bomb entity: RigidBody3D (placeholder cube)
  - States: CARRIED, DROPPED, PLANTING, PLANTED, DEFUSING, DETONATED, DEFUSED
  - Bomb timer: countdown from configurable value (reads `mp_bomb_timer` cvar)
  - Visual: blinking light, increasing blink rate
  - Audio: beep timer (placeholder sound)
- [ ] Create `plugins/modes/competitive_bomb.gd` (internal module):
  - Plant validation: player in bomb site, on ground, not moving, hold use for `mp_plant_time`
  - Defuse validation: player in bomb radius, on ground, hold use for `mp_defuse_time` / `mp_defuse_time_kit`
  - Plant interrupted: taking damage or moving cancels plant
  - Defuse interrupted: taking damage, moving, or dying cancels defuse
  - Bomb drop: spawns at death position, any attacker can pick up
  - Bomb detonation: instant kill in lethal radius, calls `on_round_end(attacker, &"bomb_detonated")`
  - Defuse success: calls `on_round_end(defender, &"bomb_defused")`
  - All timers read from cvars, not hardcoded
- [ ] Plugin hooks wired:
  - `on_bomb_plant_start()`, `on_bomb_planted()`, `on_bomb_defused()`, `on_bomb_detonated()`
  - Other plugins (vote, admin) can hook into bomb events
- [ ] Create two bomb site zones in test map (Area3D)
- [ ] HUD indicators: bomb carrier icon, bomb site markers (client-side, reads EVT_MATCH_STATE)
- **Owner:** laptop

### WB7: Buy menu (laptop)
- [ ] Create `client/scripts/client_buy_menu.gd`:
  - Functional placeholder UI (simple grid/list layout, no art)
  - Opens with B key during buy period in buy zone
  - Shows: weapon name, price, current money
  - Category tabs: Pistols, Rifles, SMGs, Equipment, Grenades
  - Greyed out: insufficient funds, wrong team, already own same slot
  - Purchase sends buy request to server (reliable channel, new `MSG_BUY` or admin subtype)
  - Keyboard shortcuts: number keys for quick-buy (B → 4 → 2 = AK, etc.)
  - Only loaded when `client_mode_loader` receives `&"competitive"` mode
- [ ] Competitive plugin buy validation (via `can_purchase()` hook):
  - Check: buy period active, player in buy zone, sufficient funds, valid item
  - On success: deduct money via economy module, spawn weapon/equipment on player
  - On fail: deny message to client
- [ ] Buy zone: Area3D near each team's spawn (read by competitive_spawns module)
- [ ] Ground weapon pickup: use key on dropped weapon (engine-level, works in any mode)
- [ ] Equipment persistence: handled by competitive_spawns module (survivors keep gear)
- **Owner:** laptop

### WB8: Spectator system (laptop)
- [ ] Create `client/scripts/client_spectator.gd`:
  - Enter spectator on death (after 2s death-cam delay)
  - First-person follow mode: see through a teammate's camera
  - Cycle targets: mouse1 (next), mouse2 (previous)
  - Free-cam mode: toggle with space, WASD movement, faster with shift
  - Team-only restriction: can only follow alive teammates (competitive default)
  - HUD: watched player's name, HP, armor, weapon, ammo
- [ ] Spectator slot: players can join as spectator from team select
- [ ] Dead player spectating ends when new round starts (auto-respawn)
- [ ] Server validates spectator targets (no spectating enemy team)
- **Owner:** laptop

### WB9: Team selection and management (laptop)
- [ ] Create `client/scripts/client_team_select.gd`:
  - Team selection screen on connect: Angels / Demons / Auto / Spectate
  - Show current team sizes
  - Locked during live match if balance would be violated
  - Only loaded when `client_mode_loader` receives a team-based mode
- [ ] Create `plugins/modes/competitive_teams.gd` (internal module):
  - Team assignment validation via `on_team_assign()` hook
  - Auto-assign: place on team with fewer players
  - Balance enforcement: configurable max difference (reads `mp_autoteambalance` cvar)
  - Halftime swap: all players swap team assignment
  - `get_player_team(peer_id)` → returns team for any plugin to query
- [ ] Team-colored player indicators (placeholder: colored capsule tint)
- [ ] Team assignment request: new admin subtype `ADMIN_TEAM_SELECT`, server validates via plugin
- **Owner:** laptop

### WB10: Match HUD (laptop)
- [ ] Create `client/scripts/client_match_hud.gd`:
  - Top: round timer (mm:ss), team scores (Angels | X — Y | Demons)
  - Bottom: money display, buy period indicator
  - Center: round start announcement ("Round 5"), win announcement
  - Bomb status: "BOMB HAS BEEN PLANTED" with timer
  - Kill feed: extends Phase 4 with team colors
  - Freeze-time overlay: "FREEZE TIME — Buy weapons"
  - Match over screen: "ANGELS WIN" / "DEMONS WIN" with final score
- [ ] Extend Phase 4 scoreboard:
  - Two team sections (Angels / Demons)
  - Columns: player name, kills, assists, deaths, money (team-only), ping
  - Sorted by kills within each team
  - Round wins displayed at top
- **Owner:** laptop

### WB11: Chat plugin (laptop)
- [ ] Create `plugins/features/plugin_chat.gd` (feature plugin):
  - Implements `on_chat_message()` hook: team filtering, dead chat rules
  - Register cvars: `sv_alltalk` (0/1), `sv_deadtalk` (0/1), `sv_chat_rate` (msgs/sec)
  - Dead players: all-chat only when `sv_deadtalk` is 0 (cannot team-chat to alive teammates)
  - Rate limiting: configurable max messages per second (anti-spam)
  - Team filtering: queries `get_player_team()` from mode plugin
  - Works with any mode plugin — in deathmatch, all chat is "all chat"
- [ ] Create `client/scripts/client_chat.gd`:
  - All chat: Enter key, visible to all
  - Team chat: Y key (configurable), visible to team only
  - Chat box: text input at bottom of screen, last 8 messages displayed
  - Server messages: round announcements, admin notices
- [ ] Chat messages sent via reliable channel (existing `EVT_CHAT`)
- [ ] Server relays through plugin_chat's `on_chat_message()` for filtering
- **Owner:** laptop

### WB12: Competitive test map update (laptop)
- [ ] Extend `mp_testmap.tscn` for competitive play:
  - Two team spawn areas (Angels spawn, Demons spawn)
  - Two bomb sites (A, B) with Area3D zones and visible markers
  - Buy zones near each spawn
  - Basic competitive geometry: mid, long, short, site approaches
  - Remain gray-box (CSGBox3D) — no art needed
  - 5 spawn points per team (10 total)
  - Cover and sightlines appropriate for competitive play
- [ ] Add bomb site markers (floating text labels or simple icons)
- [ ] Add buy zone boundary indicators (visible area edges)
- **Owner:** laptop

### WB13: Regression tests (laptop + vm-prime)
- [ ] Create `tests/match_tests.gd`:
  - test_walk_speed_cap: walk key caps speed to 140 u/s
  - test_walk_accuracy: walking speed gives standing accuracy (below threshold)
  - test_walk_footstep_silent: no footstep sound when walking
  - test_walk_duck_combo: walk + duck = duck speed (lower)
  - test_walk_air_no_effect: walk key does not affect air movement
  - test_walk_network_bit: walk state serialized in InputCommand
  - test_economy_loss_bonus: escalating loss bonus up to cap
  - test_economy_win_resets_streak: win zeroes loss counter
  - test_economy_kill_rewards: correct per-weapon rewards
  - test_economy_max_money: cannot exceed $16000
  - test_buy_validation: cannot buy without funds or outside buy zone/period
  - test_round_lifecycle: FREEZE → LIVE → ROUND_OVER transitions correctly
  - test_round_timer_expiry: defense wins when timer runs out
  - test_halftime_swap: teams swap sides at round 12
  - test_match_end: match ends at 13 round wins
  - test_bomb_plant_time: planting takes 3.5s
  - test_bomb_defuse_time: defusing takes 10s (5s with kit)
  - test_bomb_interrupt: moving during plant cancels it
  - test_bomb_timer: detonation at 40s after plant
  - test_team_balance: cannot join team that exceeds balance limit
  - test_equipment_persistence: alive player keeps weapons next round
  - test_dead_player_resets: dead player spawns with default loadout
- [ ] All tests runnable headless: `godot --headless --path . -- --test`
- [ ] CI: add match test step to build.yml
- **Owner:** laptop + vm-prime

---

## Test plan

### Walk mechanic tests (MP-002)

| Test | Method | Pass condition |
|------|--------|---------------|
| Walk speed cap | Walk + knife, measure speed | Speed ≤ 3.556 m/s (140 u/s) steady-state |
| Walk + any weapon | Walk + AK/AWP/M4, measure speed | All cap at 140 u/s |
| Walk accuracy | Walk + fire AK, read spread | Spread uses standing value (not moving penalty) |
| Run accuracy | Run + fire AK, read spread | Spread uses moving value (penalty applied) |
| Walk footsteps | Walk forward, monitor audio | No footstep sounds |
| Run footsteps | Run forward, monitor audio | Footstep sounds play |
| Walk + duck | Walk + duck + knife, measure speed | Speed = duck speed (~83 u/s), not walk speed |
| Walk release | Walk → release shift, measure speed | Accelerates back to weapon maxspeed |
| Walk in air | Jump + hold walk, measure air speed | Air movement unchanged (no cap) |
| Walk network sync | Walk on client, verify server state | Server processes walk bit, caps speed identically |

### Economy tests

| Test | Method | Pass condition |
|------|--------|---------------|
| Starting money | New match, check money | $800 for all players |
| Round win reward | Win round, check money | +$3250–$3500 depending on method |
| Loss bonus escalation | Lose 5 rounds, check money | $1400, $1900, $2400, $2900, $3400 |
| Loss bonus cap | Lose 6+ rounds | Stays at $3400 |
| Win resets streak | Win after 3 losses, lose again | Next loss gives $1400 (reset) |
| Kill rewards | Kill with rifle/SMG/sniper/knife | $300/$600/$100/$1500 |
| Bomb plant bonus | Plant bomb, lose round | All surviving attackers get +$800 |
| Max money | Win repeatedly | Caps at $16000 |
| Buy validation | Try to buy with $0 | Purchase denied |

### Round lifecycle tests

| Test | Method | Pass condition |
|------|--------|---------------|
| Freeze time | Round starts, try to move | Players frozen for 5s |
| Buy period | Buy during first 15s, try after | Buy works in period, denied after |
| Buy zone | Buy inside/outside zone | Only works inside zone |
| Round timer | Wait full round time | Defense wins on expiry |
| Elimination win | Kill all enemies | Round ends immediately |
| Bomb plant win | Plant, wait 40s | Attackers win on detonation |
| Bomb defuse win | Plant, defuse | Defenders win on defuse |
| Halftime | Complete 12 rounds | Teams swap, economy resets |
| Match end | One team reaches 13 | Match over screen |
| Equipment persist | Survive round with AK | Have AK next round |
| Death reset | Die with AK | Spawn with knife + starter pistol |

### Manual play tests (LAN, two machines)

| Scenario | Expected behavior |
|----------|-------------------|
| Full 5v5 match (recruit testers) | Match completes all rounds without manual intervention |
| Economy flow | Pistol round → eco → full buy cycle feels natural |
| Walk peek | Hold shift, peek corner — no footsteps, accurate first shot |
| Bomb plant + defuse | Full objective cycle works end to end |
| Clutch round | 1vN scenario, spectate teammates, execute play |
| Disconnect mid-round | Reconnect preserves team/money, dead until next round |
| Halftime swap | Teams swap cleanly, money resets, spawns swap |

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Round state desync between clients | High | High | Single server-authoritative state machine; broadcast all transitions reliably; clients only display what server tells them |
| Economy edge cases (overtime, ties) | Medium | Medium | Keep economy logic simple and tested; overtime rules minimal (extend by 3 rounds) |
| Buy menu UX too clunky without art | Medium | Low | Focus on keyboard shortcuts for fast buying; art is Phase 6 |
| Bomb interaction conflicts with movement/shooting input | Medium | Medium | Use separate "use" action; plant requires hold, not toggle; interrupt on any other action |
| Spectator camera through walls | Medium | Medium | Use camera collision (simple raycast clamp); accept minor clipping for Phase 5 |
| Walk mechanic feels too slow or useless | Low | Medium | 140 u/s is the CS 1.6 verified threshold; tune if play-feel differs |
| Team balance with small player count | Medium | Low | Auto-assign; allow override in warmup; competitive mode requires minimum players |
| Round timer synchronization drift | Low | Medium | Server is authoritative; clients display server's timer value, not local countdown |

---

## Dependencies
- Phase 2 movement system — **done** (signed off 2026-10-25)
- Phase 3 gunplay and grenades — **done** (signed off 2026-10-28)
- Phase 4 multiplayer networking — **required** (in progress)
  - Server game loop, snapshots, prediction, reconciliation, lag compensation
  - Input command protocol and serialization
  - Player lifecycle (spawn/death/respawn — will be refactored for round-based)
  - Scoreboard (will be extended with teams)
- Movement inaccuracy threshold (Phase 3) — **done** (140 u/s wired to spread)
- SoundManager footstep system — **done** (needs walk threshold check)
- Godot 4.7.2 on laptop and vm-prime — **done**

---

## Rollback
Each WB is committed independently. If Phase 5 needs to be paused:
- WB1 (walk) landed independently — movement feature with no match system dependency ✓
- WB2 (plugin system) is safe — deathmatch plugin preserves all existing behavior; server_game.gd refactoring is backward-compatible because deathmatch plugin replicates the original logic
- WB3 (economy module) is data-only — no gameplay impact until wired to WB4's competitive plugin
- WB4 (competitive plugin) is the critical integration point — this is where the game becomes round-based, but only when `game_plugin competitive` is set; `game_plugin deathmatch` always works
- The plugin system itself is the safety net: reverting to deathmatch mode is a one-line config change

---

## Owner training exercises

### E1: Economy mental math
Before implementing:
1. Trace a losing team's economy over 5 rounds:
   - Round 1: $800 → lose → +$1400 = $2200
   - Round 2: $2200 → lose → +$1900 = $4100
   - Round 3: $4100 → eco (save) → lose → +$2400 = $6500
   - Round 4: $6500 → full buy (AK $2700 + vest+helm $1000 + nades $800) = $2000 → lose → +$2900 = $4900
   - Round 5: $4900 → force buy → lose → +$3400 = $8300
2. At what round can the losing team first full buy? (Round 4: $6500 available)
3. What happens if they win round 3 instead? (Win reward $3250, loss streak resets)
- **Goal:** understand economy pacing before implementing

### E2: Walk timing feel
After WB1 is working:
1. Hold shift and walk toward a corner — count the silence
2. Release shift and run — hear footsteps immediately
3. Walk with AK, fire at a wall — note first-shot accuracy
4. Run with AK, fire at same wall — note spread difference
5. Walk peek a corner, counter-strafe, fire — this is the competitive pattern
- **Goal:** feel why walk is a core competitive mechanic

### E3: Bomb round flow
After WB4 + WB6 are working:
1. Play a full round as attacker: buy → execute → plant → defend plant → win
2. Play as defender: hold site → retake → defuse → win
3. Try planting while moving (should fail)
4. Try defusing — get killed mid-defuse — observe interrupt
5. Let bomb timer run out — observe detonation win
- **Goal:** feel the tension of the bomb timer and objective pressure

### E4: Full match pacing
After all WBs complete:
1. Play a 5v5 match (recruit friends or use multiple local clients)
2. Track economy decisions: when to eco, when to force, when to full buy
3. Note: does halftime reset feel fair? Does loss bonus prevent snowball?
4. Time the match: should be roughly 30-45 minutes for a full MR12
- **Goal:** validate that MR12 pacing works with these economy numbers

---

## Acceptance checklist (gate criteria)

### Plugin architecture
- [ ] Plugin base class, plugin manager, and cvar registry are implemented and tested
- [ ] Server loads game mode from `server.cfg` (`game_plugin competitive` or `game_plugin deathmatch`)
- [ ] Deathmatch plugin reproduces all Phase 4 gameplay with zero regressions
- [ ] Competitive plugin runs a full match with all rules enforced
- [ ] Feature plugins (chat, vote) load alongside any mode plugin
- [ ] Cvars are readable/writable via server console (`cvarlist`, `set mp_roundtime 120`)
- [ ] Switching `game_plugin` between deathmatch and competitive works without restart
- [ ] Client loads correct UI modules based on server-reported mode

### Gameplay (via competitive plugin)
- [x] Walk mechanic works: shift caps speed to 140 u/s, silent footsteps, full accuracy
- [x] Walk key syncs over network (Phase 4 input command includes walk bit)
- [ ] Two teams (Angels/Demons) with team selection and auto-assign
- [ ] MR12 format: 12 rounds per half, first to 13, halftime swap
- [ ] Round lifecycle: freeze → buy → live → round over, all timers correct
- [ ] Economy: starting money, win/loss rewards, loss bonus escalation, kill rewards all correct
- [ ] Buy menu: functional weapon/equipment purchasing during buy period in buy zone
- [ ] Bomb objective: plant, defuse, detonation timer, drop on death, all win conditions
- [ ] Spectator mode: first-person follow and free-cam after death
- [ ] Match HUD: round timer, team scores, money, bomb status, announcements
- [ ] Scoreboard: team-sorted, kills/deaths/money/ping
- [ ] Chat: team and all chat functional (via chat plugin)
- [ ] Equipment persistence: survivors keep gear, dead players reset
- [ ] A full 5v5 session completes without manual intervention
- [ ] All gameplay rules are server-configurable via cvars
- [ ] All Phase 2 movement + Phase 3 combat + Phase 4 network + Phase 5 match tests pass in CI
- [ ] No regression in movement, combat, or networking feel
- [ ] Deathmatch mode from Phase 4 is preserved as a plugin

---

## Suggested work order
1. **WB1** (walk mechanic / MP-002) — **DONE** ✓ standalone movement feature, landed in PR #4
2. **WB2** (plugin system + deathmatch extraction) — the foundation: base class, cvar system, plugin manager, refactor server_game.gd, extract deathmatch plugin. Must land before any other WB. Proves the architecture by running existing gameplay through the plugin layer with zero regressions.
3. **WB3** (competitive economy module) — standalone calculation logic, testable without round system. Internal module of the competitive plugin.
4. **WB4** (competitive plugin + round lifecycle) — core integration: this is where the game becomes round-based. Wires economy, teams, and rounds together.
5. **WB5** (competitive spawn system) — per-team spawns, freeze time, equipment persistence
6. **WB6** (bomb objective) — adds primary win condition
7. **WB12** (test map update) — needed for bomb sites and team spawns (can start as a shell early)
8. **WB7** (buy menu) — economy integrated into gameplay
9. **WB9** (team selection) — player-facing team management
10. **WB10** (match HUD) — visibility into match state (extend incrementally alongside features)
11. **WB8** (spectator) — after death flow is in place
12. **WB11** (chat plugin) — communication layer, works with any mode
13. **WB13** (regression tests) — write tests alongside features, final pass here

---

## Immediate next steps
1. **Laptop:** ~~WB1 (walk mechanic)~~ — **DONE** ✓ PR #4
2. **Laptop:** WB2 (plugin system foundation) — the critical path. Establishes the architecture that every subsequent WB depends on. Key deliverable: existing deathmatch gameplay runs through the plugin layer with zero regressions.
3. **Laptop:** WB3 (economy module) — pure logic, fully testable in isolation against the cvar system
4. **Phase 4 dependency:** WB4+ requires Phase 4 networking to be functional — plan accordingly
5. **Key milestone:** Two teams buying weapons, playing a round with bomb objective, spectating after death — this validates the entire competitive ruleset AND the plugin architecture
