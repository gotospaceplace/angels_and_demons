# PHASE 6 — Competitive Polish & UI
**Status:** Not started | **Version:** 1.0 | **Date:** 2026-11-04

## Scope
Polish the competitive loop for meaningful playtesting: headshot geometry upgrade, knife attack types, death report card, kill feed enhancements, round history icons, mode-specific scoreboards, and key bindings UI. This phase makes the existing systems feel complete enough for serious competitive playtesting — it does not add new weapons, new maps, or new game modes.

### In scope
- Headshot geometry v3: AABB head hitbox with pose-following blend (approved design)
- Knife mechanics: backstab detection, slash/stab attack types (replacing 40dmg placeholder)
- Death report card: damage given/taken recap shown on death
- Kill feed enhancements: team-colored names, wallbang/flash/smoke kill tags
- Round history icons: skull (elimination), portal (opened/sealed), hourglass (time) replacing E/P/R/T letters
- FFA Deathmatch scoreboard layout (TODO in code)
- Team Deathmatch scoreboard layout (TODO in code)
- Casual 10v10 scoreboard layout (TODO in code)
- Key bindings UI: rebindable controls menu
- Regression tests for new systems

### Not in scope (deferred to Phase 7 — Launch Prep)
- Remaining 6 weapons beyond the current 5 (knife/USP/AK-47/M4A1/AWP)
- Grenade throw/bounce tuning, volumetric smoke fog, bullet decals
- Portal objective competitive tuning (needs 5v5 playtesting first)
- Combat balance tuning (WB6/7 deferred items — needs playtesting data)
- Art models, character skins, lore-specific faction items
- Full map roster beyond test map
- Matchmaking, ELO, ranking system
- Voice chat
- Bot AI

---

## Key decisions

### Decision 1: Headshot geometry v3

Approved design from earlier review. Replaces the current hitbox with a tighter, more competitive-friendly head AABB that follows player pose.

| Component | Current | v3 |
|-----------|---------|-----|
| Head hitbox | Basic capsule region | Axis-aligned bounding box (AABB), sized to visible head mesh |
| Duck transition | Instant snap | Blends using `duck_fraction` from `player_movement.gd` |
| Neck gap | Not addressed | Deferred — accept minor gap between head AABB and body capsule |

The lag compensation system (`server_lag_comp.gd`) already stores `duck_fraction` per snapshot frame. v3 uses this to interpolate the head AABB position during duck transitions, preventing headshots on the old head position while ducking.

### Decision 2: Knife attack types

CS 1.6 knife has two attacks: slash (left click, 40dmg front / 65dmg back) and stab (right click, 55dmg front / 180dmg back). Backstab is determined by the angle between attacker's forward vector and victim's forward vector — if the attacker is behind (dot product > 0), backstab multiplier applies.

| Attack | Input | Front damage | Backstab damage | Range | Cycle time |
|--------|-------|-------------|----------------|-------|-----------|
| Slash | Mouse1 | 40 | 65 | 2.0m | 0.4s |
| Stab | Mouse2 | 55 | 180 (lethal) | 1.3m | 1.0s |

Current state: knife has a single 40dmg attack on mouse1 only. The registry (`weapon_registry.gd`) sets `base_damage = 40.0`, `cycle_time = 0.4`, `melee_range = 2.0`.

Backstab detection:
```
attacker_forward = -attacker.global_transform.basis.z
victim_forward = -victim.global_transform.basis.z
is_backstab = attacker_forward.dot(victim_forward) > 0.0
```

### Decision 3: Death report card

After dying, show a brief recap of the fight: damage dealt to each opponent and damage taken from each. Helps players understand what happened in close calls. Displayed during the deathcam (2s) before entering spectator.

| Column | Content |
|--------|---------|
| Damage Given | Who you hurt, how much, what weapon, how many hits |
| Damage Taken | Who hurt you, how much, what weapon, how many hits |

Server tracks per-round damage events: `{attacker, victim, damage, weapon_idx, hitgroup}`. On death, the relevant entries are bundled and sent to the dead player via reliable channel. Display clears on respawn or new round.

### Decision 4: Kill feed tags

Enhance kill feed entries with context tags:

| Tag | Condition | Display |
|-----|-----------|---------|
| Team color | Always | Killer/victim names in their team color (blue Angels, red Demons; gold for local player) |
| Headshot | `headshot == true` | ☠ icon (already present) |
| Wallbang | Bullet penetrated a surface | ▮ icon after weapon name |
| Through smoke | Killer or victim inside smoke cloud | ☁ icon |
| Flashed | Victim was flash-blinded at time of death | ✦ icon |

Current kill feed uses white names for everyone except local player (gold). Team colors require knowing each player's team from the client state.

### Decision 5: Round history icons

Replace text codes in the competitive scoreboard's round history strip:

| Current | Replacement | Meaning |
|---------|------------|---------|
| E | 💀 or skull icon | Elimination win |
| P | 🌀 or portal icon | Portal opened (attack win) |
| R | 📖 or book/seal icon | Portal sealed (defense win) |
| T | ⏳ or hourglass icon | Time expired (defense win) |

Implementation: draw simple icons using `draw_*` primitives or small texture atlases rather than emoji, for consistent cross-platform rendering. Each icon is 16x16 within the existing round marker boxes.

### Decision 6: Scoreboard layouts per mode

Three mode-specific layouts replacing the TODOs in `client_scoreboard.gd`:

| Mode | Layout | Columns |
|------|--------|---------|
| FFA Deathmatch | Single sorted list | Rank, Name, Kills, Deaths, Assists, KDR, HS%, DMG, Score |
| Team Deathmatch | Two teams, no economy | Team header, Name, Kills, Deaths, Assists, KDR, HS%, DMG |
| Casual 10v10 | Two teams, scrollable | Team header, Name, Kills, Deaths, Assists, Score (compact rows, scroll for >10 per team) |

The competitive scoreboard already works (2-team, economy columns, loss bonus). These three layouts share the same `client_scoreboard.gd` class, switching layout based on `mode`.

### Decision 7: Key bindings UI

A settings menu screen (accessible from main menu and pause menu) listing all bindable actions with their current key. Click an action → "Press a key" prompt → captures next input → saves to config file. Reset to defaults button per action and for all.

Actions to expose:
- Movement: Forward, Back, Left, Right, Jump, Duck, Walk
- Combat: Fire, Alt-fire, Reload, Switch weapon (scroll/keys), Knife quick-switch
- Interaction: Use (catalyst/relic/pickup)
- Communication: All chat, Team chat
- UI: Scoreboard, Buy menu, Team select
- Spectator: Next player, Previous player, Free-cam toggle

Bindings saved to `user://keybindings.cfg` and applied at startup via `InputMap.action_erase_events()` / `InputMap.action_add_event()`.

---

## Work breakdown

### WB1: Headshot geometry v3 (laptop)
- [ ] Define head AABB dimensions in a constant (sized to match visible head mesh)
- [ ] Update `server_lag_comp.gd` hitgroup detection to use AABB for head region
- [ ] Blend head AABB position using stored `duck_fraction` during duck transitions
- [ ] Verify standing headshot still registers at expected crosshair height
- [ ] Verify ducking headshot tracks the ducked head position, not the standing position
- [ ] Verify mid-transition (`duck_fraction=0.5`) hits resolve correctly (test 6.9 in lag_comp_tests already covers this — update expected values if AABB changes them)
- [ ] Update/add lag_comp_tests for new AABB geometry
- [ ] Test: neck gap area — shots between head AABB bottom and body top are body hits, not misses
- **Owner:** laptop

### WB2: Knife mechanics — backstab and attack types (laptop)
- [ ] Add `stab_damage`, `stab_range`, `stab_cycle_time`, `backstab_slash_damage`, `backstab_stab_damage` fields to `weapon_data.gd`
- [ ] Update `weapon_registry.gd` knife entry with slash/stab values (40/65 slash, 55/180 stab)
- [ ] Add secondary fire (mouse2) handling for melee weapons in `weapon_system.gd`
- [ ] Stab attack: shorter range (1.3m), longer cycle (1.0s), higher damage
- [ ] Backstab detection in `weapon_system.gd` or `server_game.gd` damage path:
  - Compute dot product of attacker forward and victim forward vectors
  - If dot > 0.0 → backstab multiplier applies
- [ ] Network: secondary fire bit in `net_input.gd` (or reuse existing alt-fire bit)
- [ ] Client: knife viewmodel shows different animation/timing for stab (placeholder — just different cycle time)
- [ ] Sound: add knife_stab sound (placeholder or reuse slash with pitch shift)
- [ ] Test: slash front = 40, slash back = 65, stab front = 55, stab back = 180
- [ ] Test: backstab detection angle threshold
- [ ] Test: stab range shorter than slash range
- [ ] Test: stab cycle time longer than slash cycle time
- **Owner:** laptop

### WB3: Death report card (laptop)
- [ ] Server: track per-round damage events in competitive plugin
  - Array of `{attacker_id, victim_id, damage, weapon_idx, hitgroup, tick}` per round
  - Clear on round start
- [ ] Server: on player death, filter damage log for entries involving the dead player
  - Bundle "damage given" (dead player was attacker) and "damage taken" (dead player was victim)
  - Send via reliable channel as new event type `EVT_DEATH_REPORT`
- [ ] Client: `client_death_report.gd` — receives and displays the report
  - Two columns: "Damage Given" (left) and "Damage Taken" (right)
  - Each row: player name, total damage, hit count, weapon icon
  - Highlight lethal damage source
  - Display during deathcam duration (2s), fade into spectator
  - Clear on new round or respawn
- [ ] Integrate with spectator system: report shows before spectator camera activates
- [ ] Works in deathmatch too (simpler version — just last death)
- [ ] Test: damage tracking records correct values for multi-hit engagement
- [ ] Test: report only shows damage from current round, not previous rounds
- **Owner:** laptop

### WB4: Kill feed enhancements (laptop)
- [ ] Team-colored names in kill feed:
  - Look up killer/victim team from client game state
  - Use `Team.get_color()` for team coloring (blue Angels, red Demons)
  - Keep gold highlight for local player (overrides team color)
- [ ] Wallbang tag:
  - Server: flag kills where bullet penetrated a surface before hitting (penetration_level > 0 and surface was hit)
  - Add `wallbang: bool` to kill event data
  - Client: show ▮ icon in kill feed entry
- [ ] Through-smoke tag:
  - Server: check if killer or victim position overlaps any active `smoke_cloud.gd` at time of kill
  - Add `through_smoke: bool` to kill event data
  - Client: show ☁ icon in kill feed entry
- [ ] Flash-kill tag:
  - Server: check if victim had active flash-blind effect at time of death
  - Add `victim_flashed: bool` to kill event data
  - Client: show ✦ icon in kill feed entry
- [ ] Update kill event protocol to include new flag bits (wallbang, smoke, flash)
- [ ] Test: team colors render correctly for all team combinations
- [ ] Test: wallbang flag set correctly when bullet penetrates surface
- **Owner:** laptop

### WB5: Round history icons (laptop)
- [ ] Create simple icon set (drawn with `draw_*` or small texture atlas):
  - Skull (elimination), Portal swirl (portal opened), Book/seal (portal sealed), Hourglass (time expired)
  - 16x16 pixel icons, monochrome with team color tint
- [ ] Update `_refresh_round_history()` in `client_scoreboard.gd`:
  - Replace text labels ("E", "P", "R", "T") with icon draws
  - Keep team-colored background tint on each marker
- [ ] Test: icons render at correct positions in round history strip
- [ ] Test: icons match the correct reason for each round outcome
- **Owner:** laptop

### WB6: FFA Deathmatch scoreboard (laptop)
- [ ] Add deathmatch layout to `client_scoreboard.gd`:
  - Single list, all players, sorted by kills descending
  - Columns: Rank (#), Name, Kills, Deaths, Assists, KDR, HS%, DMG, Score
  - Local player row highlighted
  - No team sections, no economy columns
- [ ] Mode-switch logic: when `mode == &"deathmatch"`, use FFA layout
- [ ] Update existing HUD tests to cover FFA layout
- **Owner:** laptop

### WB7: Team Deathmatch scoreboard (laptop)
- [ ] Add TDM layout to `client_scoreboard.gd`:
  - Two team sections (like competitive), sorted by kills within each team
  - Columns: Name, Kills, Deaths, Assists, KDR, HS%, DMG
  - No economy columns (no money, no loss bonus)
  - Team score headers (sum of team kills)
- [ ] Mode-switch logic: when `mode == &"tdm"`, use TDM layout
- [ ] Note: TDM mode plugin does not exist yet — scoreboard layout is prepared for it
- **Owner:** laptop

### WB8: Casual 10v10 scoreboard (laptop)
- [ ] Add Casual layout to `client_scoreboard.gd`:
  - Two team sections, compact rows (smaller font, tighter spacing)
  - `MAX_ROWS` increased from 5 to 10 per team, with scroll if more
  - Columns: Name, Kills, Deaths, Assists, Score (minimal columns to fit width)
  - No economy columns
- [ ] Mode-switch logic: when `mode == &"casual"`, use Casual layout
- [ ] Note: Casual mode plugin does not exist yet — scoreboard layout is prepared for it
- **Owner:** laptop

### WB9: Key bindings UI (laptop)
- [ ] Create `client/scripts/client_keybindings.gd`:
  - Settings panel accessible from main menu and pause menu (Escape → Settings → Controls)
  - List all bindable actions grouped by category (Movement, Combat, Interaction, Communication, UI, Spectator)
  - Each row: action name, current key binding, click-to-rebind button
  - Rebind flow: click → "Press a key..." prompt → capture `InputEventKey` → save
  - Duplicate key detection: warn if key already bound to another action
  - "Reset to Default" per action and "Reset All" button
- [ ] Save/load bindings:
  - Save to `user://keybindings.cfg` (ConfigFile)
  - Load at startup, apply via `InputMap.action_erase_events()` / `InputMap.action_add_event()`
  - If no config file exists, use Godot project defaults
- [ ] Wire into main menu scene and pause menu
- [ ] Test: rebinding a key persists across restart
- [ ] Test: duplicate key warning fires correctly
- **Owner:** laptop

### WB10: Phase 6 regression tests (laptop + vm-prime)
- [ ] Add headshot geometry v3 tests to `lag_comp_tests.gd` (or new file if needed):
  - AABB head hit at forehead corners
  - Miss above AABB top
  - Mid-duck transition hit with duck_fraction blend
  - Neck gap → body hit, not miss
- [ ] Add knife tests to `combat_tests.gd` (or new `knife_tests.gd`):
  - Slash front/back damage
  - Stab front/back damage
  - Backstab angle detection (dot product threshold)
  - Stab range < slash range
  - Stab cycle time > slash cycle time
- [ ] Add death report tests:
  - Damage tracking records multi-hit engagement
  - Report filtered to current round only
  - Report includes correct given/taken split
- [ ] Add kill feed tests:
  - Team colors applied correctly
  - Wallbang/smoke/flash flags propagated
- [ ] CI: all new test steps added to `build.yml`
- **Owner:** laptop + vm-prime

---

## Test plan

### Headshot geometry v3 tests

| Test | Method | Pass condition |
|------|--------|---------------|
| Standing headshot | Fire at head-height standing target | Head AABB hit registers as headshot |
| Ducking headshot | Fire at ducked target's head position | Hit registers at lowered head position |
| Mid-duck headshot | Fire during duck transition (duck_fraction=0.5) | Head AABB interpolated correctly |
| Above head miss | Fire 5cm above standing head AABB top | Miss (no hit) |
| Neck gap body hit | Fire at neck area between head and body | Body hit, not miss or headshot |
| Lag-compensated headshot | Fire at where head was N ticks ago | Lag comp uses stored duck_fraction |

### Knife mechanics tests

| Test | Method | Pass condition |
|------|--------|---------------|
| Slash front damage | Mouse1 attack from front | 40 damage |
| Slash backstab damage | Mouse1 attack from behind | 65 damage |
| Stab front damage | Mouse2 attack from front | 55 damage |
| Stab backstab damage | Mouse2 attack from behind | 180 damage (lethal at 100hp) |
| Backstab angle | Attack at various angles | Dot product > 0.0 = backstab |
| Stab range | Stab at 1.3m and 1.5m | Hit at 1.3m, miss at 1.5m |
| Slash range | Slash at 2.0m and 2.2m | Hit at 2.0m, miss at 2.2m |
| Stab cycle | Fire stab, measure cooldown | 1.0s between attacks |

### Death report card tests

| Test | Method | Pass condition |
|------|--------|---------------|
| Damage tracking | Hit player 3 times, kill, check report | All 3 hits recorded with correct damage |
| Given vs taken | Two players shoot each other | Each side's report shows correct given/taken |
| Round isolation | Damage in round 1, die in round 2 | Round 2 report has no round 1 data |
| Multi-attacker | Two players damage victim | Report shows both attackers with individual damage |

### Kill feed tests

| Test | Method | Pass condition |
|------|--------|---------------|
| Team colors | Kill between teams | Killer name in team color, victim in team color |
| Local player gold | Local player kills or dies | Local player name in gold |
| Wallbang tag | Kill through wall | ▮ icon appears in feed |
| Smoke tag | Kill through smoke | ☁ icon appears in feed |
| Flash tag | Kill flashed player | ✦ icon appears in feed |

### Manual play tests

| Scenario | Expected behavior |
|----------|-------------------|
| Knife duel | Slash/stab feel distinct; backstab is rewarding and lethal |
| Headshot while ducking | Headshots track the actual head position through duck transitions |
| Death analysis | Death report shows useful info — "I almost had him" moments visible |
| Kill feed readability | Team colors and tags make the feed more informative without clutter |
| Round history at a glance | Icons convey round outcome faster than letters |
| Key rebinding | Change a key, restart game, binding persists |

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Head AABB too small → frustrating headshots | Medium | High | Size to visible head mesh; test extensively; can enlarge later |
| Head AABB too large → too easy headshots | Medium | High | Start with tight AABB matching mesh; playtest data drives adjustments |
| Backstab detection feels inconsistent | Medium | Medium | Use generous angle (dot > 0.0 is full 180° behind); visual feedback on backstab |
| Death report clutters screen during deathcam | Low | Low | Keep it compact; auto-fade; position doesn't overlap spectator UI |
| Kill feed too busy with many tags | Medium | Low | Tags are small icons, not text; max 2-3 per entry; subtle colors |
| Key binding conflicts with Godot built-ins | Low | Medium | Filter out reserved keys (Escape, F1-F12 if needed); test edge cases |
| TDM/Casual scoreboard layouts untestable without mode plugin | Medium | Low | Test with mock data; mode plugins come in Phase 7 |

---

## Dependencies
- Phase 5 competitive loop — **done** (all 13 WBs merged)
- Lag compensation with `duck_fraction` snapshots — **done** (`server_lag_comp.gd` line 30)
- Smoke cloud system — **done** (`shared/scripts/smoke_cloud.gd`)
- Flash-blind effect — **done** (needs verification of flash state tracking)
- Kill feed system — **done** (`client/scripts/kill_feed.gd`)
- Scoreboard framework — **done** (`client/scripts/client_scoreboard.gd`)
- Spectator system — **done** (`client/scripts/client_spectator.gd`, deathcam timing)
- `weapon_data.gd` resource class — **done** (needs new fields for stab values)
- `weapon_registry.gd` knife definition — **done** (needs stab/backstab values)

---

## Rollback
Each WB is committed independently:
- WB1 (headshot v3) is isolated to lag comp hit detection — revert restores old hitbox
- WB2 (knife) adds new attack type — revert keeps existing 40dmg slash
- WB3 (death report) is purely additive UI — remove without affecting gameplay
- WB4 (kill feed) enhances existing display — revert to white names, no tags
- WB5 (round icons) is cosmetic only
- WB6–WB8 (scoreboards) add layouts for modes that don't exist yet — safe to defer or revert
- WB9 (key bindings) is standalone settings UI — revert to hardcoded defaults

---

## Suggested work order
1. **WB1** (headshot geometry v3) — core competitive feel, affects all combat
2. **WB2** (knife mechanics) — core weapon gap, changes economy math (knife kill $1500 with real risk/reward)
3. **WB3** (death report card) — playtest feedback tool, useful for all subsequent testing
4. **WB4** (kill feed enhancements) — builds on existing feed, needs server-side kill context
5. **WB5** (round history icons) — small, self-contained scoreboard improvement
6. **WB6** (FFA deathmatch scoreboard) — fills existing TODO
7. **WB7** (TDM scoreboard) — fills existing TODO, layout only
8. **WB8** (Casual 10v10 scoreboard) — fills existing TODO, layout only
9. **WB9** (key bindings UI) — standalone, no gameplay dependency
10. **WB10** (regression tests) — consolidate after all WBs

---

## Deferred to Phase 7 — Launch Prep

These items need playtesting data from Phase 6's improved competitive loop, or are content additions rather than system polish:

| Item | Reason for deferral |
|------|-------------------|
| Remaining 6 weapons (scout, heavy pistol, SMGs, etc.) | Content addition; current 5 weapons test the full economy and combat loop |
| Grenade throw/bounce tuning | Needs competitive playtesting to identify specific problems |
| Volumetric smoke fog | Visual polish; current `smoke_cloud.gd` is functional |
| Bullet decals | Visual polish; no gameplay impact |
| Portal objective competitive tuning | Needs 5v5 playtesting data (activation/seal times, site balance) |
| Combat balance tuning (WB6/7 deferred) | Needs playtesting data; premature without real matches |
| Art models, character skins | Visual polish; gray-box is fine for competitive testing |
| Lore-specific faction catalyst/relic models | Visual polish |
| Full map roster | Content; test map works for competitive loop validation |
| TDM and Casual mode plugins | Scoreboards are prepared (WB7/WB8), but mode logic comes later |
| Matchmaking / ELO / ranking | Post-launch; hosted lobby model enables this when ready |

---

## Immediate next steps
1. **WB1** (headshot geometry v3) — review approved AABB dimensions, implement in lag comp
2. Read `server_lag_comp.gd` hitgroup detection to understand current head hit logic before starting
