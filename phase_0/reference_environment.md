# Reference Environment — CS 1.6 Dedicated Server Setup
**Status:** Draft | **Phase:** 0, Week 1

## Host selection

CS 1.6 HLDS is extremely lightweight:
- **RAM:** ~60–100 MB for a single instance
- **CPU:** negligible on any modern hardware
- **Disk:** ~1 GB for HLDS + CS 1.6 game files
- **Network:** UDP port 27015 (default), minimal bandwidth for a test instance

Any homelab machine with Linux and network access from your gaming PC will work. Pick a host that's convenient and stable — this isn't a production workload.

**Chosen host:** vm-prime (192.168.30.11) — Ubuntu 24.04, 4 cores, 3.8 GB RAM.

---

## Step 1 — Install dependencies

HLDS is a 32-bit binary. Modern 64-bit Ubuntu/Debian needs the 32-bit compatibility libraries.

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y lib32gcc-s1 lib32stdc++6 libc6-i386
```

## Step 2 — Install SteamCMD

```bash
# Create a dedicated directory
mkdir -p ~/steamcmd && cd ~/steamcmd

# Download and extract SteamCMD
curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar xzf -
```

## Step 3 — Download HLDS with CS 1.6

The HLDS app ID is **90**. It supports anonymous login (no Steam account credentials needed for the server download). CS 1.6 (cstrike) is included as a mod within app 90.

```bash
cd ~/steamcmd
./steamcmd.sh \
  +force_install_dir ~/hlds \
  +login anonymous \
  +app_update 90 validate \
  +quit
```

**Note:** The first download may require running `+app_update 90` multiple times — HLDS download has a known quirk where it doesn't complete in one pass. Re-run the command until it reports "fully installed."

After installation, verify the cstrike directory exists:
```bash
ls ~/hlds/cstrike/
```

You should see `maps/`, `models/`, `sound/`, `dlls/`, and config files.

## Step 4 — Server configuration

### 4.1 Base server.cfg

Create/edit `~/hlds/cstrike/server.cfg`:

```
// === Angels & Demons — Phase 0 Research Server ===
// Stock CS 1.6 defaults unless noted

hostname "A&D Research Server"
sv_password "research"

// Core gameplay — STOCK DEFAULTS (document these)
mp_autoteambalance 1
mp_friendlyfire 0
mp_freezetime 6
mp_buytime 0.25
mp_roundtime 5
mp_startmoney 800
mp_c4timer 35
mp_maxrounds 0
mp_winlimit 0
mp_timelimit 30

// Movement — STOCK DEFAULTS (critical for research)
sv_maxspeed 320
sv_gravity 800
sv_friction 4
sv_stopspeed 75
sv_accelerate 10
sv_airaccelerate 10
sv_stepsize 18
sv_maxrate 25000
sv_minrate 0

// Research aids
sv_cheats 1
```

### 4.2 Research CVAR reference

These are the stock default values to document. Record the actual running values with `cvarlist` in the server console to confirm.

| CVAR | Stock Default | Notes |
|------|--------------|-------|
| `sv_maxspeed` | 320 | Per-weapon maxspeed overrides this |
| `sv_gravity` | 800 | Units/s² |
| `sv_friction` | 4 | Ground friction multiplier |
| `sv_stopspeed` | 75 | Below this speed, friction increases |
| `sv_accelerate` | 10 | Ground acceleration |
| `sv_airaccelerate` | 10 | Air acceleration (competitive servers often use 10; some use 12) |
| `sv_stepsize` | 18 | Max step-up height in units |
| `sv_maxrate` | 25000 | Max client data rate |
| `sys_ticrate` | 1000 | Internal server tick (but gameplay sim is framerate-bound) |

**Important:** `sv_airaccelerate 10` is the stock default, which also happens to be the competitive standard. Some public servers change this — we baseline on stock.

### 4.3 Competitive config (secondary reference)

After documenting stock behavior, test with common competitive settings to note differences:

```
// Competitive overrides to test separately
sv_airaccelerate 10
mp_freezetime 15
mp_roundtime 1.75
mp_buytime 0.25
mp_startmoney 800
mp_c4timer 35
mp_friendlyfire 1
```

The main competitive difference affecting movement feel is often the server's effective tick rate (via `sys_ticrate` and the actual FPS the server process achieves). Document the server's actual FPS with `stats` in console.

## Step 5 — Launch the server

```bash
cd ~/hlds
./hlds_run -game cstrike +map de_dust2 +maxplayers 10 +port 27015
```

Key launch parameters:
| Parameter | Purpose |
|-----------|---------|
| `-game cstrike` | Run Counter-Strike mod |
| `+map de_dust2` | Starting map |
| `+maxplayers 10` | Max player slots |
| `+port 27015` | UDP listen port |
| `-pingboost 3` | Optional: improves timing accuracy (test with and without) |
| `+sys_ticrate 1000` | Server internal tick rate (default) |

To run in the background:
```bash
screen -S cs16 -d -m ~/hlds/hlds_run -game cstrike +map de_dust2 +maxplayers 10 +port 27015
```

Reattach with `screen -r cs16`.

## Step 6 — Connect from your client

1. Launch CS 1.6 on Steam.
2. Open console (`~` key, enable in Options → Keyboard → Advanced if needed).
3. Connect: `connect <server_ip>:27015; password research`
4. Enable telemetry:
   ```
   net_graph 3
   developer 1
   ```
   The Research HUD plugin (AMX Mod X) automatically displays speed (horizontal/vertical/3D) and position on screen. `cl_showpos` does not exist in GoldSrc.

## Step 7 — Verify research readiness

Run through this checklist once connected:

- [ ] Server is running and client connects successfully
- [ ] Research HUD shows speed (horizontal/vertical/3D) and position on screen
- [ ] `net_graph 3` shows fps, ping, cmdrate, updaterate, interp
- [ ] `sv_cheats 1` is active (test with `noclip` command)
- [ ] AMX Mod X loaded (type `amxx plugins` in server console to verify)
- [ ] `status` in server console shows correct server settings
- [ ] `cvarlist` output saved for baseline documentation
- [ ] Demo recording works: `record test_demo` / `stop`
- [ ] Map change works: `changelevel de_dust2`

## Step 8 — Document the reference build

Once verified, fill in these values in this document:

- **CS 1.6 Steam App ID:** 10
- **HLDS App ID (SteamCMD):** 90
- **Client build/version:** TBD (record from client `version` command)
- **Server build/version:** Protocol 48, Exe version 1.1.2.7/Stdio (cstrike), build 01:34:04 Oct 8 2024 (10211)
- **Server binary hash:** `00740520c04a9bd76c2eaa3f6d6744ab74da93577a919018741045c7665e0497`
- **Host machine:** vm-prime, Ubuntu 24.04.4 LTS, 4 cores, 3.8 GB RAM, 192.168.30.11
- **Server actual FPS:** ~90.87 (from `stats`)
- **Server listen address:** 0.0.0.0:27015 (UDP)
- **Verified connected player:** spaced (STEAM_0:1:6017110), 12ms ping, 0% loss
- **Date documented:** 2026-10-21
- **Steam SDK workaround:** symlink `~/.steam/sdk32/steamclient.so` → `~/steamcmd/linux32/steamclient.so`

---

## Firewall notes

If the host runs a firewall, open UDP 27015:

```bash
# ufw
sudo ufw allow 27015/udp

# iptables
sudo iptables -A INPUT -p udp --dport 27015 -j ACCEPT
```

If the server is on a different VLAN from your gaming PC, ensure routing allows UDP traffic on port 27015 between them.

## Troubleshooting

**"Unable to load engine" or segfault on start:**
Missing 32-bit libraries. Reinstall: `sudo apt install -y lib32gcc-s1 lib32stdc++6`

**SteamCMD download never completes:**
Run `+app_update 90 validate` multiple times. This is a known HLDS issue — it may take 3–5 attempts.

**Client can't connect:**
Check: firewall, correct IP, correct port, VLAN routing, password matches.

**`cl_showpos` shows nothing:**
May need `developer 1` first, or check that the console variable is not restricted.
