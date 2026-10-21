# ANGELS AND DEMONS — Design Overview
**Status:** Working concept | **Version:** 0.1 | **Audience:** Project owner, Claude Code, collaborators

## Elevator pitch
A community-first, round-based tactical FPS with the mechanical feel of Counter-Strike 1.6, lightly modernized cartoon/low-poly visuals, and a mischievous Angels-versus-Demons theme. Recognizable conventional firearms, grenades, exaggerated stylized gore, and irreverent humor. The base mode has **no supernatural abilities**.

## Non-negotiable pillars
1. **CS 1.6 movement fidelity:** acceleration, stopping, air movement, jumping, crouching, collision, and weapon movement penalties must be measured and validated against a defined reference build and configuration.
2. **Competitive readability:** gameplay rules and hit registration remain predictable even when effects are extravagant.
3. **Community ownership:** players can host native or containerized dedicated servers, use direct IP/LAN, create maps and plugins, and administer their communities.
4. **Lightweight fun:** responsive performance, modest hardware demands, cartoon violence, clear silhouettes, humorous audio/animation.
5. **Independence:** Steam adds identity/discovery/distribution but does not become a runtime dependency for private standalone servers.

## Art direction
- Stylized, expressive, slightly updated early-2000s 3D: clean geometry, deliberately low-to-mid poly models, hand-painted/cel-shaded materials, sharp readable silhouettes.
- Angels: radiant but scrappy; blues, whites, golds; halos and feather motifs. Primary team color: blue.
- Demons: impish, mischievous, horned; reds, charcoal, ember accents. Primary team color: red.
- Colorblind accessibility: team identity must not rely solely on color. Provide configurable colorblind modes (protanopia, deuteranopia, tritanopia) and support distinct silhouettes, icons, and outlines as redundant team identifiers.
- Avoid photorealism, visual clutter, excessive particle occlusion, and realism-first horror.
- Gore is exaggerated and comedic: expressive reactions, blood decals, ragdolls, occasional stylized dismemberment; user-adjustable effects intensity.
- Recognizable classic-style firearms with original models, sounds and animations. No skins at launch.
- Original names, environments, character designs, branding, music, and assets; avoid reproducing Valve/id Software protected material.

## Experience goals
- In the first 30 seconds, movement should feel immediately familiar to a veteran CS 1.6 player.
- In the first match, players understand team identity, objective, weapon purchases, and deaths without reading a manual.
- In the first hour, players can find community servers and experience different maps or modes.
- In the first week, a community admin can deploy a server and modify its configuration without touching source code.

## Initial product boundary
**In scope:** PC client; 5v5 objective rounds; recognizable classic firearm archetypes; HE, flash, smoke grenades; one original competitive map; local/dedicated multiplayer; basic server browser/direct connect; admin commands; mod-friendly foundations.

**Later:** full map roster, Lua or other plugin sandbox, Workshop publishing, more modes, bots, matchmaking, cosmetic progression, advanced anti-cheat.

**Explicitly excluded from base competitive mode:** classes, hero abilities, flying, dashes, magic attacks, gameplay-affecting cosmetics, pay-to-win items.

## Business and distribution
- Target Steam price: **USD $9.99**, subject to commercial review.
- Free dedicated-server distribution for community hosts.
- Official sessions require Steam identity; community server policies may differ.
- No launch requirement for microtransactions, skins, or battle passes.

## Open decisions
- Final title, branding, and art references.
- Exact reference CS 1.6 build, settings, and acceptable mechanical tolerances.
- Original objective terminology and map themes.
- Final scripting language and plugin isolation model.
- Public playtest scale and launch requirements.

## Project rule
Any feature that compromises baseline movement fidelity, authoritative gameplay, or community server ownership requires explicit approval and documentation.
