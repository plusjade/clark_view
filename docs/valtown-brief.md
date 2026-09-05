# Clark View ↔ Val Town orientation

Read this before inspecting or changing the Val Town backend. It is a local map of the parts of `plusjade/sports-today` that matter to this repository, updated on 2026-09-05, so routine iOS work should not require rediscovering the remote project through repeated MCP calls.

## One-minute mental model

Clark View is a widget-first iOS product. The containing app is intentionally small: it registers for push, enrolls an install as a device with a bunch code, exposes prototype diagnostics, and can request a widget reload. The widget is the primary user experience.

`plusjade/sports-today` is the product brain. It stores device-to-source assignments, fetches sports data, chooses the next relevant slate, creates the display-ready JSON contract, hosts the browser administration views, and sends best-effort silent pushes when a device source changes.

This brief is the local orientation source; inspect a named remote module only when the task needs implementation detail beyond what is cached here.

```text
Helper's browser ── /bunches, /devices, /sources ──> Val Town SQLite
                                      │
iOS app ── /pair, /device/token ──────┤
                                      │
Widget ── /config/resolve ──> ordered device feed ──┬──> Games handler
                                                    └──> Messages handler
                                                              │
                                                              └──> WidgetPayload v2
                                      │
                                      ├── Sleeper sports data
                                      └── APNs silent refreshes
```

Keep the boundary simple:

- The server owns filtering, ordering, matchup/broadcast/status copy, configuration, pairing state, and push fan-out.
- The widget owns layout, widget-family limits, local date/time formatting, empty-state presentation, and refresh scheduling.
- Do not move server-owned sports logic into Swift merely to avoid a backend change. Do not make the server infer device-local presentation details that Swift can represent correctly.

## Stable identifiers and the endpoint invariant

| Item | Current value |
| --- | --- |
| Val | `plusjade/sports-today` |
| Branch | `main` |
| Code visibility / app access | public / public |
| HTTP entry file | `main.ts` |
| HTTP file id | `f0eeffb8-9a93-11f1-9bb6-1607ee4eb77e` |
| Endpoint | `https://plusjade--f0eeffb89a9311f19bb61607ee4eb77e.web.val.run/` |
| iOS owner of the base URL | `Shared/GameDataURL.swift` |

The endpoint is derived from the HTTP file id, not from the file path. **Update `main.ts` in place; never delete, recreate, or rename it.** Doing so would mint a new endpoint while the widget continued calling the old one.

Never construct a Val Town URL from the val or file name. When an endpoint check is actually needed, read `links.endpoint` from one `val_town_list_files` call and compare it with `GameDataURL.baseURL`. The exact file id above must remain present.

The iOS machine calls intentionally use the `val.run` endpoint. As of this snapshot, the human-facing `jade.beer` domain is stale for `/config/status/:deviceId` and `/device/token`; keep it out of `GameDataURL` unless that routing issue is separately verified as fixed.

## iOS-side map

| File | Role in the boundary |
| --- | --- |
| `Shared/GameDataURL.swift` | Owns the single backend base URL and builds `/config/resolve?device=&d=<pixels>&tz=<seconds>`. |
| `ClarkViewWidget/ClarkViewWidget.swift` | Fetches the resolved JSON, decodes it, and renders small/medium/large widgets. Medium shows one item; large shows up to three. Its timeline normally refreshes hourly. |
| `Shared/WidgetPayload.swift` | Mirrors JSON schema version 2. This is a display contract, not a raw sports-data model. |
| `Shared/DeviceIdentity.swift` | Creates the per-install UUID and shares it with the widget through the App Group. Local `isPaired` affects copy only; server state remains authoritative. |
| `Shared/PairingClient.swift` | Sends `POST /pair` with `{code, device}`. |
| `Shared/PushTokenClient.swift` | Sends `POST /device/token` with `{device, token}` whenever APNs registers or rotates the token. |
| `Shared/DeviceStatusClient.swift` | Reads `GET /config/status/:deviceId` for diagnostics; it is not the widget data path. |
| `clark_view/AppDelegate.swift` | Registers for silent push and asks WidgetKit to reload when one arrives. |
| `clark_view/ContentView.swift` and `PairingView.swift` | Keep the containing app limited to pairing, status, and manual reload. Team/sport selection stays in the browser configurator. |

`RefreshWidgetIntent` and the app's refresh buttons only ask WidgetKit for a new timeline. They do not bypass WidgetKit's scheduling guarantees or call a separate refresh endpoint.

## Server-side map

The remote val has one stable HTTP entrypoint plus namespaced transport, domain, and rendering modules:

| Remote path | Responsibility |
| --- | --- |
| `main.ts` | Stable Hono assembly point. Preserve this file's identity; route implementations live under `http/`. |
| `http/routes/*.ts` | Hono route groups for the root/data endpoint, stable widget compatibility URLs, and browser administration APIs. |
| `http/handlers/games.ts` | Shared sports query pipeline for widget JSON, PNG diagnostics, and config previews. Gathers candidates from both sources (`cached_games` for Sleeper, `source_cache` for fiba) and hands them to one selection function. |
| `http/handlers/messages.ts` | Shared Messages-source pipeline for widget JSON and config previews. |
| `http/handlers/deviceFeed.ts` | Stateful device-feed composition. Runs every ordered source assignment concurrently through the existing stateless handlers, then concatenates their schema-v2 items in assignment priority order. |
| `lib/catalog.ts` | Known sports, teams, and channel tables. |
| `lib/params.ts`, `lib/games.ts`, `lib/dates.ts`, `lib/teams.ts`, `lib/channels.ts` | Pure request validation, slate selection, date handling, and display enrichment. `games.ts`'s selection entry point is `pickNextPerTeam(candidates, teams)` — a flat candidate list in, each favorite's next game out; it replaced the date-walking `pickNextSlate`. |
| `lib/resolver.ts` | Pure translation from one source assignment's settings into the existing stateless games/messages request parameters. |
| `lib/deviceStore.ts` | Device-centric projections and writes for device names and `device_sources` assignments. Device views deliberately omit bunch membership; assignment writes validate ownership and rely on SQLite's JSON, priority, foreign-key, and uniqueness constraints. |
| `lib/deviceSourceStore.ts` | Widget-facing read seam that resolves an install id to all its sources by `(priority ASC, device_sources.id ASC)`. |
| `lib/deviceTokenStore.ts` | APNs token persistence and device/source token projections keyed by `devices.install_id`. Token uploads may precede device registration. |
| `lib/sourceStore.ts` | Read-only projections of source definitions, JSON settings schemas, and their device assignments for the browser explorer. |
| `lib/bunchStore.ts` | Bunch administration, reusable 30-minute bunch codes, and new-model device registration. A valid code is the only write path that creates or moves a device into a bunch. |
| `lib/messageStore.ts` | Val-scoped SQLite for the shared Messages feed, including same-day range reads and timestamp-indexed ordering. |
| `lib/sleeper.ts` | Outbound Sleeper data access. No longer on the request path — reached only from `lib/sleeperIngest.ts` since `cached_games` landed. |
| `lib/cachedGames.ts` | The `cached_games` table: one row per game, indexed by (sport, team code, start instant). Read seam is `nextGamesForTeams(teams, fromMs)` — one indexed seek per team, no date window. `cachedGamesCoverage()` answers "is this empty because nothing is scheduled, or because nothing was ingested?". |
| `lib/sleeperIngest.ts` | The write side: fetch Sleeper per Eastern date, reconcile the per-sport shape hazard once via `teamCode`/`teamScore`, upsert rows. Importable with no side effects so a future interval can call it directly. |
| `tools/ingestSleeper.ts` | Manual runner for the above. Run it to populate/refresh; prints an ingest report and coverage summary. |
| `lib/sourceCache.ts` | Generic `source_cache` SQLite table (source, date_key, payload, fetched_at) for source payloads this val can't fetch live at request time — see the FIBA section below. |
| `lib/fiba.ts` | FIBA's read-side seam: `fibaGamesForDate(dateKey)` reads `sourceCache` instead of the network (shaped like `sleeper.ts`'s `fetchScores`) and `mapEventToGame` reconciles ESPN's raw shape into `Game`. `listFutureFibaDateKeys` backs the source's own (uncapped) date window. |
| `lib/moonPhases.ts` | Moon's read-side seam, same `sourceCache` plumbing as `fiba.ts` but no live fetch behind it at all: `nextFullMoon(fromDateKey)` returns the next seeded full moon at or after that date, or `null` once the seeded year runs out. No reconciliation step — the cached payload is already this project's own `{peakTime, name, isBlueMoon}` shape, not a third party's. |
| `lib/push.ts` | Best-effort APNs silent push delivery to one device or every device attached to a selected source. |
| `render/json.ts` | The native widget's schema-versioned response. |
| `render/messageJson.ts` | Maps stored messages into the same schema-versioned widget item contract. |
| `render/moonJson.ts` | Maps the next full moon into the same schema-versioned widget item contract — `mainText: "Full Moon"`, `subText` the traditional name (e.g. "Harvest Moon"), `caption: null`. Mirrors `messageJson.ts`'s shape; no `Game`-typed intermediate. |
| `render/pageShell.ts` | Shared browser shell owning typography, colors, resource tables/navigation, forms, breadcrumbs, and timestamp localization. |
| `render/deviceHtml.tsx` | React-rendered device index, source-assignment forms, and resolver-backed preview composed through the shared config `pageShell`. |
| `render/sourceHtml.tsx` | React-rendered source index/show and source-owned Messages form composed through `pageShell`, including human-readable JSON Schema fields and linked device assignments. |
| `render/bunchHtml.tsx` | React-rendered bunch index/detail and pairing-code pages. Bunches appear only in enrollment/access administration, not device feed rendering. |
| Other `render/*` files | PNG rendering and its pure layout helpers; not the native widget's rendering path. |

Prefer changing pure helpers and their tests over adding policy directly to an I/O module. Keep `main.ts` as route wiring and edge behavior.

## HTTP surface and callers

| Method and route | Caller | Contract / caution |
| --- | --- | --- |
| `GET /` | Browser, widget redirect target, diagnostics | Plain requests render a centered nav to `/bunches`, `/devices`, and `/sources`. Explicit `format=json` remains the widget contract and `format=png` remains available for diagnostics. Repeated `teams[]` parameters are validated without turning drift into a fatal widget error. `sports[]` was removed on 2026-09-05: a value sent by a stale client is echoed into `x-effective-rejected` as `sports:<value>` and otherwise ignored, so no request can widen itself back into a whole-league slate. |
| `GET /messages` | Widget/source diagnostics | Accepts `tz=<seconds east of GMT>` and returns schema-version-2 widget JSON containing every message whose ISO timestamp falls on the current calendar day at that fixed offset. It has no config or device parameter; `/config/resolve` includes it only when the requesting device has the Messages source attached. |
| `GET /moon` | Widget/source diagnostics | Accepts `tz=<seconds east of GMT>` (used only to resolve the client's "today" for the forward scan, not to adjust the returned instant) and returns schema-version-2 widget JSON containing a single item for the next full moon from today onward, or an empty `items` array once the seeded year is exhausted. `/config/resolve` includes it only when the requesting device has the Moon source attached. |
| `GET /config/resolve` | Widget | Stable compatibility URL over the device model. Accepts `device`, `d=<pixelWidth>x<pixelHeight>`, and `tz=<seconds east of GMT>`, looks up `devices.install_id`, and loads every `device_sources` row by `(priority ASC, id ASC)`. It executes each source concurrently through the same handlers used by the stateless endpoints, concatenates each source's already-ordered `items` in assignment order, and returns the combined schema-v2 JSON directly with `cache-control: no-store`. An unknown device, or a registered device without a source, gets the starter-team default. `x-effective-source-count` and `x-effective-sources` expose composition diagnostics without changing the body contract. |
| `POST /pair` | Containing app | Stable compatibility URL over bunch enrollment. JSON `{code, device}` redeems a `bunch_codes` row, registers or moves `devices.install_id`, and returns `{ok: true, deviceId}` (200). An unknown code is `{ok: false}` (404); an expired code is `{ok: false, message: "expired"}` (422). Codes are six characters and reusable until their 30-minute expiry. The app intentionally requires only `ok`, because the internal integer id is not part of its data path. |
| `POST /devices/register` | Browser/new-model API | JSON `{code, device, name?}`. Performs the same bunch registration as `/pair`, with an optional device name. Unknown and expired codes use the same 404/422 split. |
| `POST /device/token` | Containing app | JSON `{device, token}`. Upserts the APNs token independently of pairing. |
| `GET /config/status/:deviceId` | Containing app diagnostics | Stable compatibility URL over the device model. Always returns 200 for a syntactically valid request; an unknown install is `{deviceId, paired: false}`. A registered install returns `paired`, its device name, `activeSource`, and the primary Games source's `teams` (an empty array for Messages, Moon, or no source). `sports` left this body on 2026-09-05; `DeviceStatusClient` decodes optionally, so an un-updated build shows no Teams data rather than failing to decode. No config id is exposed. |
| `GET /devices/resolve` | New-model alias | Accepts the same `device`, `d`, and `tz` parameters and returns the same ordered, combined response as `/config/resolve`. The iOS widget remains on the stable config-named URL until route renaming is coordinated. |
| `GET /devices/status/:installId` | New-model diagnostics | Returns registration state, device name, active source, and ordered source settings without exposing bunch membership. The iOS app remains on the stable config-named URL until route renaming is coordinated. |
| `GET /devices` | Helper's browser | Index of every new-model device, with install id, source count, and a link to the internal integer-id show route. Bunch membership remains intentionally absent. |
| `GET/POST /devices/:id` | Helper's browser | Device detail and direct name edit. Lists assignments in deterministic `(priority ASC, id ASC)` order and expands settings. |
| `GET /devices/:id/sources/new`, `POST /devices/:id/sources` | Helper's browser | Two-step source attachment: choose one singleton source not already attached, then set its positive integer priority and source-specific settings. Games accepts catalog-filtered `teams` plus `intradayFilter`; Messages stores `{}`. |
| `GET/POST /devices/:id/sources/:assignmentId` | Helper's browser | Reads or edits one assignment owned by the device. This is the device-centric replacement for config Settings plus Personalization; feed choice is assignment presence/order rather than `dataFeed`. Saving sends a best-effort silent push only to that device. |
| `POST /devices/:id/sources/:assignmentId/delete` | Helper's browser | Removes only the device/source edge, leaving the singleton source and source-owned data intact. |
| `GET /devices/:id/preview` | Helper's browser | Runs the same concurrent, ordered composition as the device resolver and renders both item rows and raw schema-v2 JSON. A device without assignments previews the same starter-team fallback used by the resolver. |
| `GET /sources` | Helper's browser | Read-only index of singleton source definitions with schema-field and attached-device counts. |
| `GET /sources/:id` | Helper's browser | Read-only source detail using the internal integer id. Expands the available JSON Schema, shows source timestamps, and lists attached devices with priorities and human-readable assignment settings. |
| `GET/POST /sources/:id/messages` | Helper's browser | Source-owned replacement for the transitional config Messages page. It is available only for the singleton Messages source, lists/adds the shared feed, normalizes browser-local time to UTC ISO, and refreshes every attached device best-effort. |
| `GET /bunches`, `GET /bunches/new`, `POST /bunches` | Helper's browser | Parallel new-model replacement for the config collection/create intention at the access boundary. Lists or creates enrollment scopes; feed settings are not stored here. |
| `GET/POST /bunches/:id` | Helper's browser | Shows/renames a bunch and lists its devices. This is access/enrollment administration and is intentionally separate from `/devices/:id` rendering configuration. |
| `GET /bunches/:id/pair`, `POST /bunches/:id/codes` | Helper's browser | Lists bunch-code history and creates reusable 30-minute enrollment codes. There is deliberately no direct cross-bunch “link existing device” form; moving a device across the ACL boundary requires a valid code through `/devices/register`. |
| `POST /ingest/:source/:dateKey` | External ingest process only — never the widget, app, or configurator | Bearer-gated (`INGEST_TOKEN` env var, value not recorded here) write into `source_cache`. Body is stored verbatim as JSON. See the FIBA section below for why this exists. |

Only `/config/resolve` and `/config/status/:deviceId` remain under the config-named prefix; these names are stable iOS compatibility contracts, not config resources. `GET /config` and all former id-scoped browser routes return 404.

Current fallback behavior matters: an unknown or unpaired device is resolved with the `fever` + `sparks` starter-team configuration (`dodgers` was dropped from it when mlb left the catalog on 2026-09-05 — see the mlb section below). There is no longer any all-sports fallback anywhere: with `sports[]` gone, a device with no resolvable teams renders an empty feed rather than every game.

The retired `configs`, `device_configs`, and `pairing_codes` tables were dropped after the device cutover. Canonical enrollment and rendering state now lives in `bunches`, `bunch_codes`, `devices`, `sources`, and `device_sources`; `device_tokens`, `messages`, `source_cache`, and `cached_games` retain their focused supporting roles.

## Widget JSON contract

The response is `schemaVersion: 2` with server-ordered `items`. `render/json.ts` also emits a deprecated top-level `eyebrow`; Swift deliberately ignores unknown keys and derives each item's day label from its timestamp.

```json
{
  "schemaVersion": 2,
  "items": [
    {
      "id": "stable-game-id",
      "mainText": "Away @ Home",
      "subText": "Network · availability",
      "caption": null,
      "emphasized": false,
      "timestamp": 1788044400
    }
  ]
}
```

Contract rules:

- `mainText`, `subText`, `caption`, item order, and `emphasized` are server-owned view decisions.
- `caption: null` tells Swift to format `timestamp` as the device-local start time. Live is currently `caption: "LIVE"` with `emphasized: true`; final is `"END"` without emphasis.
- `timestamp` is Unix **seconds**, decoded with `.secondsSince1970`; milliseconds would silently produce a date thousands of years in the future.
- Swift derives `TODAY`, `TMRW`, or a localized month/day from each timestamp.
- The product intentionally displays no scores or live game clock.
- Preserve or add fields compatibly. Removing or repurposing a field requires a schema-version bump and coordinated server, Swift model, preview fixture, and decoding changes.

`render/json.ts` returns `cache-control: public, max-age=60` and `x-effective-*` headers describing the resolved sports, teams, rejected values, UTC offset, and resolved date. `x-effective-mode` was removed with `sports[]` — only one mode was left — and `x-effective-sports` now reports what the resolved teams implied, not what the caller asked for. Use those headers for drift diagnosis instead of expanding the Swift body contract.

`render/messageJson.ts` uses that same body contract and cache policy. Stored `main`, `sub`, and ISO `timestamp` values become `mainText`, `subText`, and Unix seconds; message items use `caption: null` and `emphasized: false`. The `messages` table has only `main`, `sub`, and `timestamp`; SQLite `rowid` remains the stable widget item id, and `messages_timestamp` supports same-day range reads. Messages are shared by every device attached to the singleton Messages source, whose schema and assignments have no settings. Devices without that source do not include messages in their combined feed. No source schema or assignment retains `legacyConfigId` or `sports`; Games assignments contain only the live `teams` and `intradayFilter` values.

The device feed is a source-ordered concatenation, not a global timestamp sort: assignment priority determines the source blocks, equal priorities use assignment id as the deterministic tie-breaker, and each source retains its own internal item ordering. `Promise.all` makes source execution concurrent without changing result order. A source failure currently fails the whole composition; partial-feed degradation has not been introduced.

## FIBA women's basketball — live, second source wired into the widget pipeline

Sleeper's `/scores` has no FIBA competitions. Phased deliberately: Phase 1 validated a source and shape; Phase 2 (this section) is the reconciliation service that normalizes it into `Game` and wires it into the real request path. `catalog.ts`'s `SPORTS`, `games.ts`'s pipeline, and `render/json.ts` are all touched now — this is live, not a spike.

- **Source**: ESPN's unofficial `site.api.espn.com/apis/site/v2/sports/basketball/fiba/scoreboard`. Currently the FIBA Women's Basketball World Cup 2026 (Berlin, Sep 4-14). This ESPN league (id 53, name literally "FIBA World Cup") is a single flagship-tournament bucket ESPN re-points per cycle, not a durable "women's basketball" feed — it returned zero events for the Aug 2024 Olympics window, and there's real risk it repoints to the *Men's* World Cup in 2027. Re-validate before trusting it for any window beyond the current one.
- **Why this val doesn't fetch it live**: `site.api.espn.com` returns `403 Forbidden` (Akamai edge rule against Val Town's shared egress IPs, confirmed ESPN-wide not FIBA-specific, not fixable with headers) from this val's own runtime — repro in `tools/fiba-source-check.ts`. Worked around with an ingest/serve split: `lib/sourceCache.ts`'s `source_cache` table is seeded by `POST /ingest/:source/:dateKey` (bearer-gated by `INGEST_TOKEN`) from an unblocked network — an agent session's `curl`, or a script run locally — and `lib/fiba.ts` reads from it instead of calling out live.
- **Reconciliation** (`lib/fiba.ts`'s `mapEventToGame`): translates ESPN's raw event shape into this project's existing `Game` type — targeting the flat/string variant (`away_team`/`home_team` as plain code strings, scores as flat `metadata` fields) that `games.ts`'s `teamCode`/`teamScore` already read for nfl, so `enrichGames`/`filterByTeams`/`groupBySport`/`pickNextSlate` needed **zero changes**. ESPN's `status.type.state` (`pre`/`in`/`post`) is exact and maps directly into `render/json.ts`'s `STATUS_MAP`, unlike Sleeper's noisier vocabulary. Every field is treated as a progressive enhancement, not a guarantee — a missing team code, score, or broadcast degrades to the same "TBD"/blank the pipeline already shows for an incomplete Sleeper game (verified live: ESPN's `TNT`/`truTV` broadcasts aren't in `catalog.ts`'s channel dictionaries and fall through cleanly to the existing "regional" fallback instead of breaking; `HBO Max` got an explicit `STREAMING_CHANNELS` entry since it's confirmed and recurring).
- **Date window**: `http/handlers/games.ts`'s `fetchGamesByDate` routes each requested sport to its source via `catalog.ts`'s new `SPORT_SOURCE` map, and gives each source its own window instead of one shared constant. Sleeper keeps `windowDatesFor`'s fixed few-day scan (justified by its one-request-per-date cost). `fiba` uses `lib/sourceCache.ts`'s `listFutureDateKeys` — every date `source_cache` actually has from today forward, uncapped, since a local table scan has no per-date cost to bound. The two window's dates are unioned before `pickNextSlate` runs, which needed no changes since it already just walks whatever `dates`/`gamesByDate` arrays it's handed. This is deliberate: the old 3-day cap was a Sleeper-specific constraint that had leaked into shared date logic, not a real limit on how far out "next" should look.
- **Verified live against the deployed endpoint** (2026-09-02, server "today" resolved to 2026-09-01 in the default Pacific client offset): `?teams[]=united-states` correctly surfaced the USA-China group game on **2026-09-04** — a date outside Sleeper's own `[09-01, 09-02, 09-03]` window, proving the union actually reaches past it rather than coincidentally landing inside it. `?sports[]=fiba&day=today` returned all 8 real Sep-4 games, correctly sorted, with real team names and per-game channels (that `sports[]` form stopped working on 2026-09-05 — the equivalent check today enumerates the tournament's `teams[]`). Mixed requests (`teams[]=fever&teams[]=united-states`, one empty source + one populated) and `format=png` both still work. No regression on existing wnba-only requests.
- **Team slugs**: full country names (`united-states`, `puerto-rico`, `south-korea`, `turkey` — not ESPN's `Türkiye` — etc.), not ESPN's 3-letter codes, because `teamLabel` derives the display string from the slug via `titleCase`, which has no acronym handling (`usa` → "Usa"). 16 teams, the current group stage; see `catalog.ts`'s `TEAMS` for the full list.
- **Still open**: knockout-round dates (Sep 8-14) were ingested empty since ESPN hadn't published that schedule yet as of 2026-09-02 — re-ingest closer to those dates. Nothing re-ingests `source_cache` automatically; live/final status accuracy for fiba depends entirely on how recently someone re-ran the ingest loop. That's an accepted trade per this phase's own scope: presence (a game is on the slate at all) is the source's real contract, not intraday freshness.

## Moon — lunar full moons, a third static source

Added 2026-09-04 as the third row in `sources` (`id=3`, `kind='moon'`), alongside Games and Messages. Devices attach to it the same way as any other singleton source.

- **Schema change**: `sources.kind` was `CHECK (kind IN ('games', 'messages'))`. SQLite can't alter a `CHECK` in place, so the table was recreated (same `id`s, same `ux_sources_kind` unique index) with `moon` added to the constraint. `device_sources.source_id`'s FK survives this untouched — SQLite doesn't enforce FK constraints against DDL, only DML, so dropping/recreating the parent table mid-transaction never orphans the child rows.
- **No live-fetch problem, unlike FIBA**: full-moon instants are public, deterministic astronomical data with no Akamai-style block, so there was no need for `POST /ingest/:source/:dateKey`. `source_cache` (`source='moon'`) is reused anyway, on purpose: a calendar year's full moons are a small, fixed, known-in-advance set (13 for 2026), so seeding the whole year once is simpler and cheaper than a live per-request fetch, and `lib/sourceCache.ts`'s `listFutureDateKeys`/`getSourcePayload` already do exactly the "next date on or after X" query this needs — reused unchanged from `fiba.ts`.
- **Dataset**: 13 full moons for calendar year 2026, UTC peak instants sourced from Astropixels (Fred Espenak's ephemeris tables) and cross-checked against timeanddate.com's Central-Time table converted through 2026's US DST boundaries (Mar 8 / Nov 1) — independent sources agreed to the minute. One calendar Blue Moon (May 31, the second full moon in May). Payload shape per row: `{peakTime: "2026-01-03T10:03:00Z", name: "Wolf Moon", isBlueMoon: false}`, `date_key` = the UTC calendar date of the peak.
- **Serving shape mirrors Messages, not Games**: a full moon has no teams or score, so it skips `games.ts`'s `Game`-typed pipeline entirely (`enrichGames`/`filterByTeams`/`groupBySport`/`pickNextSlate` never touch it) in favor of the simpler pattern `messages.ts`/`messageJson.ts` already established — a handler resolves client-local "today", a pure `lib/` function answers the domain question, a `render/` function maps straight to a schema-v2 item. `lib/moonPhases.ts`'s `nextFullMoon(fromDateKey)` returns the single next event (or `null`); `render/moonJson.ts` renders it as one item (`mainText: "Full Moon"`, `subText` the traditional name) — never a list of the year's remaining moons, since the widget only ever surfaces 1–3 items regardless of source.
- **`caption: "PEAK"`, not `null`**: `caption: null` tells `ClarkViewWidget.swift`'s `displayCaption` to fall back to formatting `timestamp` as a local clock time — correct for a game's kickoff, wrong here. `peakTime` is the exact geocentric opposition instant (Sun-Earth-Moon at 180°), which is unrelated to moonrise/moonset at any given location and routinely falls during local daylight (2026-09-26's is 9:49am Pacific — the Moon isn't even up then). A fixed caption avoids implying "go look now" at an instant that's often unviewable; the day label (TODAY/TMRW/date) is still derived from `timestamp` independently of `caption`, so that stays correct.
- **`tz` is UTC-offset seconds, and stays server-side day-boundary-only**: `lib/dates.ts`'s `resolveClientOffsetSeconds` already documents that iOS sends `TimeZone.current.secondsFromGMT()` (seconds, not minutes). `/moon` uses it exactly once — to resolve the client's local "today" as the start of the forward scan through `source_cache` (`dateAtOffset` → `nextFullMoon`) — the same narrow use `games.ts`/`messages.ts` make of it. `peakTime` itself is never shifted by `tz`; it's always the single UTC instant, unmodified, all the way to the client, per `WidgetPayload.swift`'s existing contract that `timestamp` stays raw specifically so the client localizes it. There's no "shift toward moonrise" logic and there shouldn't be — moonrise is a real per-location astronomical calculation, not a fixed offset from opposition, and out of scope here.
- **Settings**: `{}`, like Messages — nothing is device-configurable. `render/deviceHtml.tsx`'s `SourceSettingsFields` and `http/routes/devices.ts`'s `settingsFor` both special-case `kind === "moon"` the same way they already special-case `"messages"`. `render/sourceHtml.tsx` needed no changes — its index/show documents are already generic over `kind`.
- **Still open**: nothing re-seeds `source_cache` for 2027 automatically. Re-run the same research-and-insert step for the next calendar year before this one runs out, the same trade-off FIBA's uncapped-but-manually-ingested window makes.

## College football (cfb) — Sleeper's own feed, a catalog-only extension of Games

Added 2026-09-05. Unlike FIBA and Moon, this is **not** a new source: `cfb` is a sport Sleeper's existing `/scores` already carries, so the entire change is four edits to `lib/catalog.ts` and nothing else. No new `lib/` module, no `SPORT_SOURCE` entry (an absent entry already means "Sleeper's"), no `source_cache` seeding, no ingest job, no schema change, and no iOS change.

- **Why it was this cheap**: `sports[]=cfb` returns the same *flat* metadata variant nfl uses — `away_team`/`home_team` as plain code strings, scores in sibling `metadata.away_score`/`home_score` — so `games.ts`'s `teamCode`/`teamScore` already read it, and `enrichGames`/`filterByTeams`/`groupBySport`/`pickNextSlate` needed zero changes. Its status vocabulary (`pre_game`, `in_game`, `complete`) is already fully covered by `render/json.ts`'s `STATUS_MAP`; a live run returned an empty `x-effective-rejected`, confirming no unmapped value.
- **Two teams, deliberately**: `trojans` (USC) and `bruins` (UCLA) only. The FBS is ~136 schools — mapping it would roughly double the whole `TEAMS` table for a widget nobody has asked to point at more than these two. Same "roster in hand, not a standing table" rule the FIBA block states.
- **Slugs are mascots, not school abbreviations**: `teamLabel` is `titleCase(slug)` with no acronym handling, so `usc`/`ucla` would render as "Usc"/"Ucla" — the same trap that made the FIBA block use full country names. Sleeper's cfb feed does carry a second Trojans (`TROY`, Troy University); it has no `TEAMS` entry today, and if it ever gets one it needs a city-prefixed slug the way `st-louis-cardinals` and `san-francisco-giants` did. Codes confirmed live: Sleeper gives South Carolina `SCAR`, so `USC` is unambiguously Southern Cal.
- **`cfb` sits second in `SPORTS`, next to nfl**: display/group order only, and both share a weekly cadence. That cadence is also cfb's one real caveat — `windowDatesFor`'s fixed 3-day Sleeper scan means a cfb-only selection outside a Thu/Fri/Sat window legitimately resolves to no slate at all, exactly as an nfl-only one does midweek. Not a cfb bug and not fixed here; widening the Sleeper window is a shared-cost change (one live `/scores` request per date) that belongs to its own task.
- **Configurator needed no changes**: `render/deviceHtml.tsx`'s `SourceSettingsFields` builds both the sports checkboxes and the per-sport team fieldsets by iterating `SPORTS`/`TEAMS` directly, and the stored Games `settings_schema` types `sports`/`teams` as bare string arrays with no enum. A CFB fieldset with Trojans and Bruins appears on the source-assignment form automatically.
- **Verified live against the deployed endpoint** (2026-09-05): `?format=json&teams[]=trojans&teams[]=bruins&day=next` returned both schools' games with `x-effective-sports: cfb`, `x-effective-teams: cfb:USC,cfb:UCLA`, correct 🏈 emoji, seconds-based timestamps, and a correctly-mapped `LIVE` caption; `?sports[]=cfb&day=today` returned the full slate, sorted, with no status rejections; `format=png` renders; and the `fever`+`sparks`+`dodgers` starter-team request was unchanged (that fallback lost `dodgers` the same day — see the mlb section).
- **Known gap, pre-existing and not cfb's**: `FOX` is absent from `catalog.ts`'s `NATIONAL_CHANNELS`, so a FOX broadcast falls through to the regional fallback (raw label, no DirecTV number) — and long cfb network strings chop at `MAX_CHANNEL_LABEL` ("SEC Netwo…", "Fox Sport…"). Both already affect nfl; adding entries changes existing nfl/mlb output too, so it stays its own decision rather than a side effect of this change.

## MLB removed — the catalog shrinks the same way it grows

Removed 2026-09-05, right after cfb was added, for the reason the cfb block only half-solved: too many games in a sport this product doesn't follow. mlb was a ~15-game daily slate, by far the largest standing contributor to an unfiltered request.

- **The whole removal is the mirror of the addition**: `mlb` out of `SPORTS`, its `⚾` out of `SPORT_EMOJI`, its 30 rows out of `TEAMS`. Nothing else in the pipeline is sport-aware, so no handler, renderer, store, or route changed. This is the same property the cfb section claims from the other direction, now tested in both.
- **No live device was affected**: every `device_sources` Games assignment was read before the change and none referenced an mlb team. Had one existed, the failure mode would have been soft, not fatal — `resolveParams` pushes unknown slugs into `rejected` rather than erroring — but the device would have silently lost that team.
- **The one place mlb *was* load-bearing**: `http/handlers/deviceFeed.ts`'s `DEFAULT_SOURCE`, the starter feed for an unknown, unpaired, or source-less device, was `["fever", "sparks", "dodgers"]`. It is now `["fever", "sparks"]`. Leaving `dodgers` in would not have crashed anything; it would have fired the rejected-slug drift echo on every unpaired device forever, which is precisely the signal that echo exists to surface. Deliberately *not* swapped for a cfb team — this is a placeholder for a device nobody has configured, not a statement of what the product follows.
- **Consequence worth knowing**: the starter fallback now renders an **empty** card whenever neither the Fever nor the Sparks has a game inside `windowDatesFor`'s 3-day scan (verified 2026-09-05: `x-effective-teams: wnba:IND,wnba:LAS`, no rejections, zero items). Daily mlb had been quietly papering over that window for the fallback path. This resolves itself when Sleeper moves to `source_cache` and the range window goes away.
- **Comment debt paid, not deferred**: `catalog.ts`'s header comments used mlb as the worked example for two separate rules — the (sport, code) pair key (`WSH` vs `WAS`, and the BOS/HOU/TB/PHI/PIT collisions) and the city-prefixed slug rule (`st-louis-cardinals`, `san-francisco-giants`). Both rules outlive the sport, so they were rewritten to state the rule and cite mlb as its now-removed origin, rather than left pointing at rows that no longer exist. `lib/teams.ts`'s "nfl, wnba and mlb are fully mapped" and `MAX_TEAMS`'s sizing note got the same treatment. `MAX_TEAMS` itself stays 120: it bounds malformed input, it is not a budget tracking the table's size.
- **Verified live** (2026-09-05): `?sports[]=mlb&teams[]=dodgers&teams[]=yankees` → `x-effective-rejected: mlb,dodgers,yankees`, `x-effective-sports: nfl,cfb,wnba,nba,fiba`, 200 with the remaining sports' slate (soft rejection, not an error); the two real cfb device configurations and the wnba+fiba one all render unchanged.

## `sports[]` removed — teams are the only selector

Removed 2026-09-05, immediately after the mlb removal and for the same underlying reason: this product surfaces a handful of events someone actually cares about, and a whole-league request is the opposite of that. Dropping mlb shrank the laundry list; dropping `sports[]` removes the ability to ask for one at all.

- **The real simplification is losing the two-mode split.** `lib/params.ts` used to resolve into either "teams mode" or "sports mode", and the fallback path — no teams, or every requested team unknown — widened the request to *every game in every sport*. That fallback is gone. Zero resolvable teams now means zero derived sports, and since `fetchGamesByDate` derives its fetch list from those sports, it means **zero outbound requests** and an empty slate. An empty card is the honest answer to "show me nothing in particular".
- **A stale client fails visibly, not silently.** `http/handlers/games.ts` no longer reads `sports[]` at all; each value found is pushed into `rejected` as `sports:<value>` and surfaces in `x-effective-rejected`. Verified live: `?sports[]=cfb&sports[]=nfl` returns 200 with `items: []` and `x-effective-rejected: sports:cfb,sports:nfl`. A 200-with-nothing beats a 4xx here for the same reason the rest of the param contract never throws — a 4xx renders as a broken image in WidgetKit.
- **`x-effective-mode` is gone**; only one mode was left for it to report. `x-effective-sports` stays but changed meaning: it is now what the resolved teams *implied*, not what the caller requested.
- **`SPORTS` survives, demoted.** It stopped being a request allowlist and is now only the display-order vocabulary — read by `lib/params.ts`'s `orderBySports` and by the configurator's team-group headings. Nothing else touches it.
- **Full removal surface** (one edit each unless noted): `lib/params.ts` (`resolveParams` now takes only `teamsParam`; `ResolvedParams.mode` dropped), `http/handlers/games.ts`, `lib/resolver.ts` (`GamesSettings` loses `sports`; `buildFeedUrl` stops appending it), `http/handlers/deviceFeed.ts` (`DEFAULT_SOURCE`), `render/json.ts` (`effectiveHeaders`), `render/deviceHtml.tsx` (the "Sports (used only when no teams below are selected)" fieldset deleted), `http/routes/devices.ts` (`settingsFor` drops the key, `SPORTS` import removed), `http/routes/widget.ts` (`/config/status/:deviceId` body), and `lib/catalog.ts` comments.
- **Storage was migrated, not left to rot**: the singleton Games source's `settings_schema` dropped its `sports` property and its `required` entry, and all three live `device_sources` rows had the key removed with `json_remove`. `settings_schema` is descriptive — nothing validates against it — but leaving a field there that the server no longer reads is exactly the drift this brief exists to prevent. `settingsFor` also silently drops an inbound `sports[]`, so re-saving any older assignment cleans itself.
- **iOS, static analysis only** (no Xcode in this environment): `DeviceStatusClient.DeviceStatus` dropped its `sports` field, and `ContentView`'s diagnostics panel dropped the Sports row. Its `displayList` empty-state also changed from `"(all)"` to `"(none)"` — "(all)" was only ever correct while the server had the whole-league fallback, so it would now assert the exact opposite of what an empty list means. Nothing in the widget extension or the `GameDataURL` request path referenced sports; the widget's outbound contract (`device`, `d`, `tz`) is unchanged.
- **Verified live** (2026-09-05): `?teams[]=trojans&teams[]=bruins&teams[]=united-states` returns all three teams' games with `x-effective-sports: cfb,fiba` and no rejections; the `sports[]`-only request above returns empty with the drift echo; the configurator's Games form renders team fieldsets with no Sports fieldset; and a real device's `/devices/:id/preview` still composes Games + Moon correctly after the storage migration.

## `cached_games` — Sleeper moves off the live request path

Added 2026-09-05. Sleeper's slate is now a normalized SQLite table read at request time, not N live `/scores` calls. This is the change that removes the range window rather than relocating it.

- **Why not `source_cache`.** The obvious move — land Sleeper in the existing `(source, date_key) -> payload` table — would have kept the day-walk and only made it local. That table is keyed on the wrong axis for games: a date-keyed blob exposes no team dimension, so every "when does this team next play" has to brute-force the date axis. It is the right shape for Moon (one entity, no filter dimension) and adequate for FIBA (the whole tournament slate *is* the answer). Games needed the second axis in the schema.
- **Shape**: `cached_games(sport, game_id, away_code, home_code, start_time_ms, status, channel, away_score, home_score, ingested_at)`, PK `(sport, game_id)`, plus two indexes — `(sport, away_code, start_time_ms)` and `(sport, home_code, start_time_ms)`. Two, not one, because SQLite's OR optimization can only use both arms of `away_code = ? OR home_code = ?` if each has its own index; `start_time_ms` trails so `ORDER BY ... LIMIT 1` is satisfied by the index rather than a sort.
- **`start_time_ms` carries its unit in its name** deliberately. `Game.start_time` is Sleeper's milliseconds and `render/json.ts` is the one place that divides to the widget's seconds; a column called `start_time` was the obvious place to silently store the other unit, which decodes client-side as a date ~57,000 years out with nothing failing in between.
- **The read is N indexed seeks in one round trip** (`nextGamesForTeams`), one statement per team, not a single clever join. The answer wanted is N answers — each favorite's own next game, unioned — which is not the same as the earliest game across the set. That distinction is the bug `pickNextSlate`'s per-team walk was written to fix, and one statement per team maps onto it 1:1. `MAX_TEAMS` bounds N.
- **Reconciliation happens at write time.** Sleeper's `away_team` is a string for nfl/cfb but `{team, points}` for wnba, with the score in a different place per sport. `lib/sleeperIngest.ts` resolves that once using the existing `teamCode`/`teamScore` (now exported rather than reimplemented — two readings of Sleeper's shape is how they drift), so rows store the flat variant and `rowToGame` hands the pipeline something it already knows how to read. Doing this in SQL with `json_extract` was the tempting shortcut and would have put an untestable copy of that hazard in a second language.
- **`pickNextSlate` is gone, replaced by `pickNextPerTeam(candidates, teams)`** — a flat candidate list in, each favorite's next game out, deduped and grouped. Both sources now feed it: Sleeper's candidates arrive pre-reduced by the indexed query, FIBA's as a flat list off `source_cache`. FIBA keeps its own storage but no longer its own selection logic. Normalizing FIBA into `cached_games` too is the obvious next step and would delete that branch entirely.
- **`windowDatesFor` is off the Sleeper path**, replaced by `dayStartMsAtOffset(term, offsetSeconds)` — a single lower bound instead of a list of dates to scan. `today`/`next`/`tomorrow` semantics are preserved exactly, and the bound is the day's *start*, not `now`, because that is what implements the "keep showing a game for the rest of the day once it ends" setting. Two consequences worth naming: a weekly sport's next game is now found however far out it sits (verified: nfl games 5 and 6 days ahead, both invisible to the old 3-day scan), and the documented Sleeper-Eastern-vs-client-date skew is *gone* rather than bounded, since rows carry absolute instants.
- **The `backfillDays` ingest edge, found by running it.** The first run started at today-Eastern and dropped a game that was live at that moment for a Pacific viewer — Friday-night kickoffs sit in Saturday's Eastern bucket. `ingestSleeperWindow` now starts one Eastern day early. One extra request, whole class of edge gone.
- **Liveness is the accepted cost.** Status and score are as fresh as the last ingest, where they used to be per-request. This is the same trade FIBA already documents, and it is why the upsert is keyed on `(sport, game_id)` — updating a live game in place is the steady state. Nothing re-runs the ingest automatically yet; `tools/ingestSleeper.ts` is manual until a Val Town interval calls `ingestSleeperWindow()` directly.
- **An empty feed now means something different.** With no window to fall outside of, empty far more often means "not ingested" than "not scheduled". `cachedGamesCoverage()` is the diagnostic for that and is printed by the runner.
- **Verified live end to end** (2026-09-05, 168 rows: 166 cfb, 2 nfl — wnba and nba are out of season, correctly contributing nothing): `teams[]=trojans&teams[]=bruins&teams[]=united-states` returns byte-identical output to the pre-refactor response apart from a status that genuinely changed; `teams[]=seahawks&teams[]=49ers&teams[]=trojans` returns all three, with the two nfl games 5 and 6 days out; `day=tomorrow` correctly advances past a finished game to USC's next one 7 days out; `hideCompleted=1` drops the completed game; an un-ingested team (`lakers`) contributes nothing without error; `format=png` renders; and device 4's Games + Moon preview composes unchanged.

## MCP quick start: bounded workflow

Use the narrowest sequence that answers the task. Tool names below omit their generated namespace prefix.

### Read-only orientation

1. Start from the cached identifiers and maps in this document.
2. Call `val_town_get_val_detail({ val: "plusjade/sports-today" })` only when branch, ownership, or access may have changed.
3. Call `val_town_list_files` once at the exact directory you need. Do not recursively relist the known tree just to orient yourself.
4. Call `val_town_read_file` only for the exact remote files implicated by the change. Do not reread an unchanged file within the same task.

If this document, `Shared/GameDataURL.swift`, and one root `list_files` result agree on the HTTP file id and endpoint, orientation is complete.

### Editing the val

- Use `val_town_replace_in_file` for targeted edits. Its `old_string` match is the safety check.
- Use `val_town_update_file` only when most of a file is changing.
- For a new module, create a new file under the existing `lib/` or `render/` boundary; do not replace `main.ts` to reorganize it.
- For a multi-file or contract change, use one Val Town branch, verify it, then merge once. Do not create a branch per file.
- When changing an imported helper, fuse the edit and verification by setting `run.kind` to `fetch_val_endpoint` and `run.path` to `main.ts`. This avoids a separate MCP round trip.

### Verifying an HTTP change

1. Make one representative `val_town_fetch_val_endpoint` GET against `main.ts`, with the pathname/search needed for the changed route. The tool resolves the endpoint; do not paste a hand-built URL.
2. For widget-contract changes, fetch `/?format=json` with a narrow known-team query and confirm status, content type, schema version, seconds-based timestamps, and `x-effective-*` headers.
3. For resolve changes, test `/config/resolve` with a non-sensitive fixture device id. Confirm the direct response status, schema-v2 JSON, source diagnostics, and ordering; the resolver no longer redirects.
4. Call `val_town_list_files` once after deployment only when the change touched `main.ts` or endpoint identity must be certified. Confirm the file id and endpoint above did not change.
5. Use `val_town_get_traces` or `val_town_get_logs` only after a failed or surprising response. Filter to the known `main.ts` file id/trace instead of polling the whole project.

Do not use live POST routes as smoke tests. Pairing, token upload, bunch/code creation, message creation, source assignment, and device/bunch renaming all mutate production state. Exercise them only when the task explicitly requires that mutation and use disposable data where possible.

### Storage and secrets

- Prefer route-level diagnostics first. If SQLite inspection is necessary, use `val_town_sqlite_execute` with `database: { type: "val", val: "plusjade/sports-today" }`, `mode: "read"`, a parameterized query, and a narrow projection/limit.
- Never dump or repeat configuration capability ids, device ids, pairing codes, or APNs tokens in chat, logs, fixtures, or this repository.
- `val_town_list_env_vars` exposes metadata/keys, not values. Use it only for an APNs/integration task; do not repeatedly check for secrets that code inspection does not require.

## Change-location checklist

Before editing, classify the request:

- Widget layout, family-specific item count, local date/time format, empty-state copy, or refresh affordance: change the iOS repository.
- Team selection, next-game policy, ordering, channel/matchup/status copy, or server drift handling: change `plusjade/sports-today`.
- Pairing, configuration, device status, or push behavior: inspect both sides and keep the route/client pair synchronized.
- JSON field or meaning: coordinate `render/json.ts`, `Shared/WidgetPayload.swift`, the widget preview fixture, and tests; bump `schemaVersion` when compatibility requires it.
- Backend endpoint identity: do not change it. Preserve `main.ts` and verify `links.endpoint` against `GameDataURL.baseURL`.

After a server contract change, build the iOS app/widget and verify a representative endpoint response. After a presentation-only Swift change, do not touch Val Town merely because the widget consumes remote data.
