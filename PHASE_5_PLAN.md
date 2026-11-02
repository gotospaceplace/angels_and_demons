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

### Module structure

```
shared/scripts/
├── match_constants.gd         # Round times, economy values, MR12 rules
├── economy.gd                 # Economy calculations (shared for client prediction)
├── bomb.gd                    # Bomb entity (plant/defuse interaction, timer)
└── team.gd                    # Team enum, team utilities

server/scripts/
├── server_match.gd            # Match state machine, round lifecycle, win conditions
├── server_economy.gd          # Authoritative economy: money, rewards, loss bonus
├── server_spawn.gd            # Per-team spawn zones, bomb carrier selection
├── server_bomb.gd             # Bomb plant/defuse validation, bomb timer
└── server_teams.gd            # Team assignment, balance enforcement

client/scripts/
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

### WB2: Match constants and team system (laptop)
- [ ] Create `shared/scripts/match_constants.gd`:
  - Round time (1:55), freeze time (5s), buy time (15s), warmup time
  - MR12 settings (rounds per half, max rounds)
  - Economy values (all from Decision 2)
  - Bomb timer (40s), plant time (3.5s), defuse time (10s/5s)
  - Team enum: UNASSIGNED, ANGELS, DEMONS, SPECTATOR
- [ ] Create `shared/scripts/team.gd`: team utility functions
  - Opposing team lookup
  - Team color constants (blue, red)
  - Team name strings
- [ ] All values configurable via server cvars/config
- **Owner:** laptop

### WB3: Economy system (laptop)
- [ ] Create `server/scripts/server_economy.gd`:
  - Per-player money tracking (Dictionary[peer_id, int])
  - `award_round_win(team)`: distribute win reward
  - `award_round_loss(team)`: distribute loss reward with streak bonus
  - `award_kill(killer_id, weapon_type)`: per-weapon kill reward
  - `award_bomb_plant(team)`: $800 to surviving attackers
  - `purchase(peer_id, item, price)`: validate and deduct money
  - `reset_economy()`: halftime reset (all to starting money)
  - Loss streak tracking per team
- [ ] Create `shared/scripts/economy.gd`:
  - Shared economy constants and calculation helpers
  - Client-side money prediction (for buy menu validation)
- [ ] Test: loss bonus escalation ($1400 → $1900 → $2400 → $2900 → $3400 cap)
- [ ] Test: win resets loss streak
- [ ] Test: bomb plant awards $800 to all surviving attackers
- [ ] Test: cannot spend more money than available
- **Owner:** laptop

### WB4: Round lifecycle state machine (laptop + vm-prime)
- [ ] Create `server/scripts/server_match.gd`:
  - State machine: WARMUP, FREEZE, LIVE, ROUND_OVER, HALFTIME, MATCH_OVER
  - Round timer (server-authoritative, counts down during LIVE)
  - Freeze timer (counts down during FREEZE)
  - Round start: reset player positions to team spawns, restore weapons/armor for survivors
  - Round end: determine winner, trigger economy rewards, broadcast round result
  - Halftime: swap team sides, reset economy, swap spawn zones
  - Match end: check win condition (first to 13), broadcast final result
  - Warmup: free respawn, infinite money, waiting for player count
- [ ] Broadcast MatchState to all clients on every state transition (reliable channel)
- [ ] Broadcast round timer to clients at 1 Hz (or in snapshot metadata)
- [ ] Handle player disconnect during match (hold slot for reconnect)
- [ ] Test: full round cycle WARMUP → FREEZE → LIVE → ROUND_OVER
- [ ] Test: halftime triggers at round 12, teams swap
- [ ] Test: match ends when one team reaches 13 wins
- **Owner:** laptop + vm-prime

### WB5: Spawn system (laptop)
- [ ] Create `server/scripts/server_spawn.gd`:
  - Per-team spawn zones (Area3D markers in map)
  - Spawn point selection: distribute players across available points
  - Freeze-time spawn: teleport all alive players to team spawns, freeze movement
  - Death handling: dead players enter spectator, do not respawn until next round
  - Equipment persistence: alive players keep weapons/armor from previous round
  - Dead players respawn with knife + starter pistol + starting armor (none)
- [ ] Integrate with existing `server_spawner.gd` from Phase 4:
  - Refactor: round-based spawning replaces deathmatch respawn
  - Keep deathmatch mode as a separate mode option
- [ ] Update test map: add two team spawn areas (A-side, B-side)
- **Owner:** laptop

### WB6: Bomb objective (laptop)
- [ ] Create `shared/scripts/bomb.gd`:
  - Bomb entity: RigidBody3D (placeholder cube)
  - States: CARRIED, DROPPED, PLANTING, PLANTED, DEFUSING, DETONATED, DEFUSED
  - Bomb timer: countdown from 40s on plant
  - Visual: blinking light, increasing blink rate
  - Audio: beep timer (placeholder sound)
- [ ] Create `server/scripts/server_bomb.gd`:
  - Plant validation: player in bomb site, on ground, not moving, hold use 3.5s
  - Defuse validation: player in bomb radius, on ground, hold use 10s (5s with kit)
  - Plant interrupted: taking damage or moving cancels plant
  - Defuse interrupted: taking damage, moving, or dying cancels defuse
  - Bomb drop: spawns at death position, any attacker can pick up
  - Bomb detonation: instant kill to all players in lethal radius (~500u), round end
  - Defuse success: round end, defuser bonus reward
- [ ] Create two bomb site zones in test map (Area3D)
- [ ] HUD indicators: bomb carrier icon, bomb site markers on minimap/compass
- [ ] Win condition integration with server_match.gd
- **Owner:** laptop

### WB7: Buy menu (laptop)
- [ ] Create `client/scripts/client_buy_menu.gd`:
  - Functional placeholder UI (simple grid/list layout, no art)
  - Opens with B key during buy period in buy zone
  - Shows: weapon name, price, current money
  - Category tabs: Pistols, Rifles, SMGs, Equipment, Grenades
  - Greyed out: insufficient funds, wrong team, already own same slot
  - Purchase sends buy request to server (reliable channel)
  - Keyboard shortcuts: number keys for quick-buy (B → 4 → 2 = AK, etc.)
- [ ] Server buy validation (server_economy.gd):
  - Check: buy period active, player in buy zone, sufficient funds, valid item
  - On success: deduct money, spawn weapon/equipment on player
  - On fail: deny message to client
- [ ] Buy zone: Area3D near each team's spawn
- [ ] Ground weapon pickup: use key on dropped weapon
- [ ] Equipment persistence: armor/weapons carry across rounds for survivors
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
- [ ] Create `server/scripts/server_teams.gd`:
  - Team assignment validation
  - Auto-assign: place on team with fewer players
  - Balance enforcement: configurable max difference (default 1)
  - Halftime swap: all players swap team assignment
- [ ] Team-colored player indicators (placeholder: colored capsule tint)
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

### WB11: Chat system (laptop)
- [ ] Create `client/scripts/client_chat.gd`:
  - All chat: Enter key, visible to all
  - Team chat: Y key (configurable), visible to team only
  - Chat box: text input at bottom of screen, last 8 messages displayed
  - Server messages: round announcements, admin notices
  - Dead players: all-chat only (cannot team-chat to alive teammates, configurable)
- [ ] Chat messages sent via reliable channel
- [ ] Server relays with team filtering
- [ ] Rate limiting: configurable max messages per second (anti-spam)
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
- WB1 (walk) can land independently — it's a movement feature with no match system dependency
- WB2-3 (constants, economy) are data-only — no gameplay impact until wired to WB4
- WB4 (round lifecycle) is the critical integration point — this is where deathmatch becomes round-based
- The deathmatch mode from Phase 4 is preserved as a separate mode, not deleted

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

- [ ] Walk mechanic works: shift caps speed to 140 u/s, silent footsteps, full accuracy
- [ ] Walk key syncs over network (Phase 4 input command includes walk bit)
- [ ] Two teams (Angels/Demons) with team selection and auto-assign
- [ ] MR12 format: 12 rounds per half, first to 13, halftime swap
- [ ] Round lifecycle: freeze → buy → live → round over, all timers correct
- [ ] Economy: starting money, win/loss rewards, loss bonus escalation, kill rewards all correct
- [ ] Buy menu: functional weapon/equipment purchasing during buy period in buy zone
- [ ] Bomb objective: plant, defuse, detonation timer, drop on death, all win conditions
- [ ] Spectator mode: first-person follow and free-cam after death
- [ ] Match HUD: round timer, team scores, money, bomb status, announcements
- [ ] Scoreboard: team-sorted, kills/deaths/money/ping
- [ ] Chat: team and all chat functional
- [ ] Equipment persistence: survivors keep gear, dead players reset
- [ ] A full 5v5 session completes without manual intervention
- [ ] All gameplay rules are server-configurable
- [ ] All Phase 2 movement + Phase 3 combat + Phase 4 network + Phase 5 match tests pass in CI
- [ ] No regression in movement, combat, or networking feel
- [ ] Deathmatch mode from Phase 4 is preserved as an alternative mode

---

## Suggested work order
1. **WB1** (walk mechanic / MP-002) — standalone movement feature, no dependencies on other Phase 5 work; can land immediately
2. **WB2** (match constants + teams) — data foundation for everything else
3. **WB3** (economy) — standalone calculation logic, testable without round system
4. **WB4** (round lifecycle) — core integration: this is where the game becomes round-based
5. **WB5** (spawn system) — per-team spawns, freeze time, equipment persistence
6. **WB6** (bomb objective) — adds primary win condition
7. **WB12** (test map update) — needed for bomb sites and team spawns (can start as a shell early)
8. **WB7** (buy menu) — economy integrated into gameplay
9. **WB9** (team selection) — player-facing team management
10. **WB10** (match HUD) — visibility into match state (extend incrementally alongside features)
11. **WB8** (spectator) — after death flow is in place
12. **WB11** (chat) — communication layer
13. **WB13** (regression tests) — write tests alongside features, final pass here

---

## Immediate next steps
1. **Laptop:** Start with WB1 (walk mechanic) — smallest, most self-contained work item; can be implemented and tested against Phase 3's accuracy system immediately
2. **Laptop:** WB2 + WB3 (constants + economy) — pure data and logic, fully testable in isolation
3. **Phase 4 dependency:** WB4+ requires Phase 4 networking to be functional — plan accordingly
4. **Key milestone:** Two teams buying weapons, playing a round with bomb objective, spectating after death — this validates the entire competitive ruleset
