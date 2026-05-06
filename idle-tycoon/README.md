# Idle Tycoon

A single-player idle/clicker game for Roblox, built in Luau and modeled after
*AdVenture Capitalist*. Tap to earn, buy businesses for passive income, hire
managers to fully automate them, and let earnings accrue while offline.

## Quick start

This project syncs into Roblox Studio with [Rojo](https://rojo.space/).

```bash
# install rojo (one-time)
cargo install rojo
# or: aftman add rojo-rbx/rojo

# from this directory
rojo serve
```

Then in Roblox Studio:

1. Install the Rojo plugin (Plugins → Manage Plugins → search "Rojo").
2. Click the Rojo plugin button → **Connect**.
3. Press **F5** to playtest.

To enable persistence:

* Game Settings → **Security** → enable **Allow Studio Access to API Services**.
  Without this, the game still runs but uses an in-memory fallback (data is
  wiped on shutdown — useful for iteration).

## Project layout

```
default.project.json       Rojo project definition
src/
  shared/                  Replicated to ReplicatedStorage.Shared
    Config.lua             Businesses, milestones, tuning constants
    Economy.lua            Pure cost/revenue math (used on both sides)
    Format.lua             Idle-style number + duration formatting
    Remotes.lua            Lazy creation/access of RemoteEvent folder
  server/                  Lives in ServerScriptService.Server
    Main.server.lua        Entry: lifecycle + tick loop + remote handlers
    DataService.lua        DataStore wrapper with session locking + retry
    EconomyService.lua     Authoritative purchases/hires/ticking
  client/                  Lives in StarterPlayerScripts.Client
    Main.client.lua        Builds UI, applies snapshots, interpolates locally
    UI.lua                 ScreenGui builder + handle struct
```

Rojo file-suffix conventions:

* `Foo.server.lua` → `Script`
* `Foo.client.lua` → `LocalScript`
* `Foo.lua`        → `ModuleScript`

## Game design

### Core loop

1. **Tap** a business icon to start one production cycle.
2. After `cycleTime` seconds the cycle pays out into your wallet.
3. **Buy** more units — each unit linearly increases revenue but exponentially
   increases the next unit's cost (`baseCost * costMultiplier^owned`).
4. **Hire a manager** to make that business cycle automatically forever.
5. Hit **milestone** counts (25, 50, 100, 200, …) to triple revenue.

### Economy

All math lives in `shared/Economy.lua` so the client can preview costs without
a round-trip:

* `unitCost(def, ownedBefore)` — price of the next single unit.
* `bulkCost(def, owned, qty)` — closed-form geometric series for batch buys.
* `maxAffordable(def, owned, money)` — inverse of `bulkCost`, used by `BUY MAX`.
* `cyclePayout(def, owned, globalMult)` — revenue per completed cycle.
* `revenuePerSecond(def, owned, globalMult)` — used for offline accrual + RPS HUD.
* `milestoneMultiplier(owned)` — product of all triggered milestones.

Numbers are plain Lua doubles. Doubles cover up to ~1.7e308, well beyond
anything reachable in practice; precision degrades after 2^53 (~9e15) but in
idle-game terms that's a rounding error on a number nobody reads digit-by-digit.
`Format.short` renders K/M/B/T/Qa/Qi/… and then aa/ab/ac/… suffixes.

### Server authority

The server owns all state. Clients fire intent (`BuyBusiness`, `HireManager`,
`ManualCollect`) and the server validates against the player's profile before
mutating it. State snapshots are pushed back at ~5Hz; the client extrapolates
progress bars and money locally between snapshots so the UI stays smooth.

The local extrapolation **optimistically** credits cycle payouts to the wallet
between snapshots — the next server snapshot is the source of truth and will
overwrite any drift.

### Persistence

`DataService` wraps a single `DataStore` keyed per user. Key features:

* **Session locking**: `UpdateAsync` writes a `{ jobId, time }` lock; another
  server attempting to load while a live lock exists will fail and the player
  is kicked with a "rejoin in a moment" message. Locks auto-expire after
  `SESSION_LOCK_TTL` (10 min) to recover from crashed servers.
* **Schema versioning**: profiles carry a `version` field; `migrate()` is the
  hook for future format changes.
* **Retry with exponential backoff**: 4 tries, 200ms → 1.6s.
* **Triggers**:
  * On join (load + migrate).
  * Every `AUTOSAVE_INTERVAL` (60s).
  * After purchases, debounced by `PURCHASE_SAVE_COOLDOWN` (5s).
  * On `PlayerRemoving`.
  * On `BindToClose` (server shutdown).
* **Studio fallback**: if `GetDataStore` errors (no API access), an in-memory
  table is used. The game still runs; the warning surfaces in the output.

### Offline progress

Stored on the profile: `lastOnline = os.time()`. On rejoin:

```
elapsed = clamp(now - lastOnline, 0, MAX_OFFLINE_SECONDS)
amount  = sum(revenuePerSecond(b) for b in managed) * elapsed * OFFLINE_EARN_RATE
```

Defaults: 12-hour cap, 50% accrual rate. Only **managed** businesses earn
offline (you can't tap while away). On grant, the server fires `OfflineEarnings`
to the client and the UI shows a "Welcome back" modal.

## Tuning

Most balance lives in `src/shared/Config.lua`:

* `STARTING_MONEY` — first wallet seed.
* `MAX_OFFLINE_SECONDS` / `OFFLINE_EARN_RATE` — AFK economy.
* `TICK_INTERVAL` — server simulation step.
* `MILESTONES` — list of `{ level, multiplier }`.
* `BUSINESSES` — the ten-business roster with cost/revenue/cycle/manager fields.

Add a new business by appending an entry; it auto-appears in the UI. Keep the
order in the list — that's the display order.

## Adding features

| Want to add… | Touch… |
| --- | --- |
| New business | `Config.BUSINESSES` |
| New milestone | `Config.MILESTONES` |
| Prestige currency | New field on profile, new `EconomyService` API, new UI panel |
| Global revenue boost (gamepass / event) | Pass `globalMult` through `Economy.cyclePayout` calls in `EconomyService.tick` |
| Save schema change | Bump `CURRENT_VERSION` in `DataService`, add a branch to `migrate()` |
| New remote | Append to `REMOTE_EVENTS` / `REMOTE_FUNCTIONS` in `shared/Remotes.lua` |

## Testing in Studio

* **F5** for full playtest (server + client).
* Output panel shows server warnings (DataStore failures, session lock issues).
* Use the Command Bar to inspect state, e.g.:

  ```lua
  for _, p in ipairs(game.Players:GetPlayers()) do
    print(p.Name, require(game.ServerScriptService.Server.DataService).get(p))
  end
  ```

* To simulate offline progress: stop the playtest, wait, restart. Profile is
  preserved via DataStore (or the in-memory fallback within the same Studio
  session).

## Migration notes

This project is staged here for development; the user will migrate it to a new
repository. Everything required is self-contained in `idle-tycoon/`:

* No external dependencies.
* No Wally/`wally.toml` — pure Roblox standard library.
* No build step beyond `rojo serve` / `rojo build`.

To move it: copy the entire `idle-tycoon/` directory to the destination repo
and run `rojo serve` from inside it.
