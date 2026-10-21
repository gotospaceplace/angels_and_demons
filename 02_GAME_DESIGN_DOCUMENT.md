# ANGELS AND DEMONS — Game Design Document
**Status:** Directional requirements, not detailed balancing | **Version:** 0.1

## 1. Core loop
Join server → select Angels or Demons → buy equipment during freeze/buy period → coordinate and execute objective → resolve round → award economy → repeat. Spectate after death in standard competitive mode. Prioritize readable, fast rounds and strong player skill expression.

## 2. Default competitive mode
- Team-based, initially 5v5, no supernatural powers or classes.
- CS 1.6-inspired objective round rules, including an attack/defense objective equivalent to bomb plant/defuse; exact naming and fiction TBD.
- Friendly fire, team collision, round time, freeze time, buy time, starting money, economy rewards, and side switching are configurable; initial defaults are to be researched and explicitly chosen.
- Round wins arise from objective completion, elimination, or timer rules, as appropriate to the selected mode.
- No respawn within standard rounds. Separate community modes may change this.

## 3. Movement — highest fidelity requirement
- Walking, running, acceleration, friction, stopping, counter-strafing, jump, crouch, duck-jump, air-strafe, bunny-hop, ladder, steps, slopes, and collision.
- Research and document GoldSrc/CS-specific update order, time step, player hulls, movement modes, edge cases, and configuration dependence.
- No sprint meter, slide, mantle, wall run, double jump, dash, or flight in base mode.
- Baseline movement is immutable in official classic rules; modded servers may advertise deviations.
- Visual character animation must follow gameplay collision state, never determine it.

## 4. Gunplay
- Launch design: recognizable classic conventional gun archetypes (pistols, SMGs, rifles, sniper rifles, shotguns, machine guns) with original legally usable models.
- Recoil, spread, accuracy recovery, firing cadence, magazine/reload, penetration, damage falloff, armor interaction, movement inaccuracy, headshot multiplier, and switching timing are reference-driven.
- Prioritize representative pistol, rifle, and sniper weapon prototypes before full arsenal.
- No skins initially. Clear silhouettes and sound identity by weapon class.
- Authoritative server resolves hits and damage; clients predict permissible presentation only.

## 5. Grenades
- Base equipment: HE, flashbang, smoke. Research throw velocity, arc, bounce, fuse, detonation, radius, flash exposure, smoke lifetime, and purchase limits.
- **Holy Hand Grenade** is a humorous presentation concept, not a supernatural damage ability: classic grenade function with halo/glow, heavenly sound cue, and comedic effects. Exact grenade slot and naming TBD.
- Grenade physics and effects must be tested for repeatability across client/server; avoid graphics effects changing damage or visibility fairness.
- Incendiary grenades are not part of the locked CS 1.6 base mode; possible future mod/arcade feature.

## 6. Factions and character design
**Angels:** playful celestial infantry, imperfect halos, feather accents, exaggerated faces. Primary team color: blue.
**Demons:** mischievous infernal infantry, expressive horns, tails, embers. Primary team color: red.
- Comparable visibility, silhouettes, collision hulls, and animation timing for both factions.
- No faction-specific gameplay advantages or abilities.
- Original character models; faction differences are visual/audio only.
- Faction readability must work through shape and silhouette, not color alone (see section 9, colorblind modes).

## 7. Combat presentation and gore
- Stylized blood impact particles and surface decals, expressive death animations, physics ragdolls, optional detachable elements.
- Comedy cues: halo falls off, feathers scatter, horns bounce, theatrical overreactions.
- Gore intensity and blood persistence adjustable locally; provide lower-effects setting for visibility/performance.
- Cosmetic effects do not modify collision, hitboxes, server damage, or player input.
- Avoid gore particles obscuring critical player visibility in official competitive settings.

## 8. Maps and level design
- Start with a small gray-box mechanics range, then one original competitive map with readable callouts, routes, cover, timing, objective locations, and lighting.
- Heaven/Hell motifs are visual themes, not mandatory traversal gimmicks.
- Map packaging, spawn definitions, objective entities, navigation hooks, and version compatibility documented for community creators.
- Later community archetypes: surf, deathmatch, gun game, obstacle/deathrun, infection/survival.

## 9. UX and accessibility
- Fast launch, keyboard/mouse-first controls, rebindable keys, sensitivity, crosshair settings, audio sliders, color/contrast settings, configurable gore, basic subtitles for essential cues.
- Colorblind modes: protanopia, deuteranopia, and tritanopia presets that shift team colors while preserving contrast. Red/blue default is favorable for the most common deficiencies (deuteranomaly, ~5% of males), but protanopia can darken reds — presets must be validated. Consider user-customizable team highlight colors as an additional option.
- Server browser with favorites, ping, player count, map, mods/rules indicator, and direct connect.
- Buy menu, scoreboard, spectator UI, kill feed, admin notices, and console.

## 10. Server/community rules
- Public and private community servers, password support, configurable rules, map rotation, administrator roles, kick/mute/ban, persistent audit logs.
- SteamID bans where authenticated, IPv4/IPv6 address/CIDR bans as additional controls; IP-only bans are not robust identity controls.
- Community ban lists stay local by default; cross-server lists require opt-in and provenance.
- Servers clearly mark modifications to movement/weapon baseline.

## 11. Quality bar
- Mechanical tests pass against reference tolerances.
- No client-authoritative damage or position acceptance.
- Reliable 5v5 match on a headless dedicated server.
- Competitive visuals remain legible at low settings.
- Community deployment and direct-IP joining work without official matchmaking.

## 12. Not decided yet
Final economy defaults, exact weapon roster, objective naming, hitbox model, grenade naming, ranking, spectator restrictions, and art production pipeline are phase-level decisions.
