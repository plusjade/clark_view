# Clark View ↔ Val Town orientation

Read this before inspecting or changing the Val Town backend. It is a local map of the parts of `plusjade/sports-today` that matter to this repository, updated on 2026-09-02, so routine iOS work should not require rediscovering the remote project through repeated MCP calls.

## One-minute mental model

Clark View is a widget-first iOS product. The containing app is intentionally small: it registers for push, enrolls an install as a device with a bunch code, exposes prototype diagnostics, and can request a widget reload. The widget is the primary user experience.

`plusjade/sports-today` is the product brain. It stores device-to-source assignments, fetches sports data, chooses the next relevant slate, creates the display-ready JSON contract, hosts the browser administration views, and sends best-effort silent pushes when a device source changes.

This brief is the local orientation source; inspect a named remote module only when the task needs implementation detail beyond what is cached here.

```text
Helper's browser ── /bunches, /devices, /sources ──> Val Town SQLite
                                      │
iOS app ── /pair, /device/token ──────┤
                                      │
Widget ── /config/resolve ── 302 ──┬──> /?format=json ──> WidgetPayload v2
                                   └──> /messages ──────> WidgetPayload v2
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
| `ClarkViewWidget/ClarkViewWidget.swift` | Fetches the resolved JSON, follows the same-origin 302 through `URLSession`, decodes it, and renders small/medium/large widgets. Medium shows one item; large shows up to three. Its timeline normally refreshes hourly. |
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
| `http/handlers/games.ts` | Shared sports query pipeline for widget JSON, PNG diagnostics, and config previews. |
| `http/handlers/messages.ts` | Shared Messages-source pipeline for widget JSON and config previews. |
| `lib/catalog.ts` | Known sports, teams, and channel tables. |
| `lib/params.ts`, `lib/games.ts`, `lib/dates.ts`, `lib/teams.ts`, `lib/channels.ts` | Pure request validation, slate selection, date handling, and display enrichment. |
| `lib/resolver.ts` | Pure translation from a selected source's settings into the existing games/messages redirect parameters. |
| `lib/deviceStore.ts` | Device-centric projections and writes for device names and `device_sources` assignments. Device views deliberately omit bunch membership; assignment writes validate ownership and rely on SQLite's JSON, priority, foreign-key, and uniqueness constraints. |
| `lib/deviceSourceStore.ts` | Widget-facing read seam that resolves an install id to its first source by `(priority ASC, device_sources.id ASC)`. |
| `lib/deviceTokenStore.ts` | APNs token persistence and device/source token projections keyed by `devices.install_id`. Token uploads may precede device registration. |
| `lib/sourceStore.ts` | Read-only projections of source definitions, JSON settings schemas, and their device assignments for the browser explorer. |
| `lib/bunchStore.ts` | Bunch administration, reusable 30-minute bunch codes, and new-model device registration. A valid code is the only write path that creates or moves a device into a bunch. |
| `lib/messageStore.ts` | Val-scoped SQLite for the shared Messages feed, including same-day range reads and timestamp-indexed ordering. |
| `lib/sleeper.ts` | Outbound Sleeper data access. |
| `lib/sourceCache.ts` | Generic `source_cache` SQLite table (source, date_key, payload, fetched_at) for source payloads this val can't fetch live at request time — see the FIBA section below. |
| `lib/fiba.ts` | FIBA's read-side seam: `fibaGamesForDate(dateKey)` reads `sourceCache` instead of the network (shaped like `sleeper.ts`'s `fetchScores`) and `mapEventToGame` reconciles ESPN's raw shape into `Game`. `listFutureFibaDateKeys` backs the source's own (uncapped) date window. |
| `lib/push.ts` | Best-effort APNs silent push delivery to one device or every device attached to a selected source. |
| `render/json.ts` | The native widget's schema-versioned response. |
| `render/messageJson.ts` | Maps stored messages into the same schema-versioned widget item contract. |
| `render/pageShell.ts` | Shared browser shell owning typography, colors, resource tables/navigation, forms, breadcrumbs, and timestamp localization. |
| `render/deviceHtml.tsx` | React-rendered device index, source-assignment forms, and resolver-backed preview composed through the shared config `pageShell`. |
| `render/sourceHtml.tsx` | React-rendered source index/show and source-owned Messages form composed through `pageShell`, including human-readable JSON Schema fields and linked device assignments. |
| `render/bunchHtml.tsx` | React-rendered bunch index/detail and pairing-code pages. Bunches appear only in enrollment/access administration, not device feed rendering. |
| Other `render/*` files | PNG rendering and its pure layout helpers; not the native widget's rendering path. |

Prefer changing pure helpers and their tests over adding policy directly to an I/O module. Keep `main.ts` as route wiring and edge behavior.

## HTTP surface and callers

| Method and route | Caller | Contract / caution |
| --- | --- | --- |
| `GET /` | Browser, widget redirect target, diagnostics | Plain requests render a centered nav to `/bunches`, `/devices`, and `/sources`. Explicit `format=json` remains the widget contract and `format=png` remains available for diagnostics. Repeated `sports[]` and `teams[]` parameters are validated without turning drift into a fatal widget error. |
| `GET /messages` | Widget | Accepts `tz=<seconds east of GMT>` and returns schema-version-2 widget JSON containing every message whose ISO timestamp falls on the current calendar day at that fixed offset. It has no config or device parameter; `/config/resolve` gates access by selecting the Messages source for the requesting device. |
| `GET /config/resolve` | Widget | Stable compatibility URL over the device model. Accepts `device`, `d=<pixelWidth>x<pixelHeight>`, and `tz=<seconds east of GMT>`, looks up `devices.install_id`, selects one `device_sources` row by `(priority ASC, id ASC)`, and translates its source kind/settings into the unchanged games or messages redirect. Messages redirects carry only `tz`; source attachment is their gate. Multiple stored sources are deliberately not unioned yet. An unknown device, or a registered device without a source, gets the starter-team default. The widget's `URLSession` follows the uncached 302. |
| `POST /pair` | Containing app | Stable compatibility URL over bunch enrollment. JSON `{code, device}` redeems a `bunch_codes` row, registers or moves `devices.install_id`, and returns `{ok: true, deviceId}` (200). An unknown code is `{ok: false}` (404); an expired code is `{ok: false, message: "expired"}` (422). Codes are six characters and reusable until their 30-minute expiry. The app intentionally requires only `ok`, because the internal integer id is not part of its data path. |
| `POST /devices/register` | Browser/new-model API | JSON `{code, device, name?}`. Performs the same bunch registration as `/pair`, with an optional device name. Unknown and expired codes use the same 404/422 split. |
| `POST /device/token` | Containing app | JSON `{device, token}`. Upserts the APNs token independently of pairing. |
| `GET /config/status/:deviceId` | Containing app diagnostics | Stable compatibility URL over the device model. Always returns 200 for a syntactically valid request; an unknown install is `{deviceId, paired: false}`. A registered install returns `paired`, its device name, `activeSource`, and the primary Games source's sports/teams (empty arrays for Messages or no source). No config id is exposed. |
| `GET /devices/resolve` | New-model alias | Accepts the same `device`, `d`, and `tz` parameters and applies the same first-assignment ordering as `/config/resolve`. The iOS widget remains on the stable config-named URL until route renaming is coordinated. |
| `GET /devices/status/:installId` | New-model diagnostics | Returns registration state, device name, active source, and ordered source settings without exposing bunch membership. The iOS app remains on the stable config-named URL until route renaming is coordinated. |
| `GET /devices` | Helper's browser | Index of every new-model device, with install id, source count, and a link to the internal integer-id show route. Bunch membership remains intentionally absent. |
| `GET/POST /devices/:id` | Helper's browser | Device detail and direct name edit. Lists assignments in deterministic `(priority ASC, id ASC)` order and expands settings. |
| `GET /devices/:id/sources/new`, `POST /devices/:id/sources` | Helper's browser | Two-step source attachment: choose one singleton source not already attached, then set its positive integer priority and source-specific settings. Games accepts catalog-filtered sports/teams plus `intradayFilter`; Messages stores `{}`. |
| `GET/POST /devices/:id/sources/:assignmentId` | Helper's browser | Reads or edits one assignment owned by the device. This is the device-centric replacement for config Settings plus Personalization; feed choice is assignment presence/order rather than `dataFeed`. Saving sends a best-effort silent push only to that device. |
| `POST /devices/:id/sources/:assignmentId/delete` | Helper's browser | Removes only the device/source edge, leaving the singleton source and source-owned data intact. |
| `GET /devices/:id/preview` | Helper's browser | Runs the same games/messages handler selected by the device's first ordered assignment and renders both item rows and raw schema-v2 JSON. |
| `GET /sources` | Helper's browser | Read-only index of singleton source definitions with schema-field and attached-device counts. |
| `GET /sources/:id` | Helper's browser | Read-only source detail using the internal integer id. Expands the available JSON Schema, shows source timestamps, and lists attached devices with priorities and human-readable assignment settings. |
| `GET/POST /sources/:id/messages` | Helper's browser | Source-owned replacement for the transitional config Messages page. It is available only for the singleton Messages source, lists/adds the shared feed, normalizes browser-local time to UTC ISO, and refreshes every attached device best-effort. |
| `GET /bunches`, `GET /bunches/new`, `POST /bunches` | Helper's browser | Parallel new-model replacement for the config collection/create intention at the access boundary. Lists or creates enrollment scopes; feed settings are not stored here. |
| `GET/POST /bunches/:id` | Helper's browser | Shows/renames a bunch and lists its devices. This is access/enrollment administration and is intentionally separate from `/devices/:id` rendering configuration. |
| `GET /bunches/:id/pair`, `POST /bunches/:id/codes` | Helper's browser | Lists bunch-code history and creates reusable 30-minute enrollment codes. There is deliberately no direct cross-bunch “link existing device” form; moving a device across the ACL boundary requires a valid code through `/devices/register`. |
| `POST /ingest/:source/:dateKey` | External ingest process only — never the widget, app, or configurator | Bearer-gated (`INGEST_TOKEN` env var, value not recorded here) write into `source_cache`. Body is stored verbatim as JSON. See the FIBA section below for why this exists. |

Only `/config/resolve` and `/config/status/:deviceId` remain under the config-named prefix; these names are stable iOS compatibility contracts, not config resources. `GET /config` and all former id-scoped browser routes return 404.

Current fallback behavior matters: an unknown or unpaired device is resolved with the `fever` + `sparks` + `dodgers` starter-team configuration. An older comment in the widget still describes an all-sports fallback; treat the deployed server behavior above as current until a deliberate cross-project change reconciles both sides.

The retired `configs`, `device_configs`, and `pairing_codes` tables were dropped after the device cutover. Canonical enrollment and rendering state now lives in `bunches`, `bunch_codes`, `devices`, `sources`, and `device_sources`; `device_tokens`, `messages`, and `source_cache` retain their focused supporting roles.

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

`render/json.ts` returns `cache-control: public, max-age=60` and `x-effective-*` headers describing the resolved mode, sports, teams, rejected values, UTC offset, and resolved date. Use those headers for drift diagnosis instead of expanding the Swift body contract.

`render/messageJson.ts` uses that same body contract and cache policy. Stored `main`, `sub`, and ISO `timestamp` values become `mainText`, `subText`, and Unix seconds; message items use `caption: null` and `emphasized: false`. The `messages` table has only `main`, `sub`, and `timestamp`; SQLite `rowid` remains the stable widget item id, and `messages_timestamp` supports same-day range reads. Messages are shared by every device attached to the singleton Messages source, whose schema and assignments have no settings. Devices without that source cannot select the feed through the resolver. No source schema or assignment retains `legacyConfigId`; Games assignments contain only the live `sports`, `teams`, and `intradayFilter` values. A later phase is expected to union multiple sources.

## FIBA women's basketball — live, second source wired into the widget pipeline

Sleeper's `/scores` has no FIBA competitions. Phased deliberately: Phase 1 validated a source and shape; Phase 2 (this section) is the reconciliation service that normalizes it into `Game` and wires it into the real request path. `catalog.ts`'s `SPORTS`, `games.ts`'s pipeline, and `render/json.ts` are all touched now — this is live, not a spike.

- **Source**: ESPN's unofficial `site.api.espn.com/apis/site/v2/sports/basketball/fiba/scoreboard`. Currently the FIBA Women's Basketball World Cup 2026 (Berlin, Sep 4-14). This ESPN league (id 53, name literally "FIBA World Cup") is a single flagship-tournament bucket ESPN re-points per cycle, not a durable "women's basketball" feed — it returned zero events for the Aug 2024 Olympics window, and there's real risk it repoints to the *Men's* World Cup in 2027. Re-validate before trusting it for any window beyond the current one.
- **Why this val doesn't fetch it live**: `site.api.espn.com` returns `403 Forbidden` (Akamai edge rule against Val Town's shared egress IPs, confirmed ESPN-wide not FIBA-specific, not fixable with headers) from this val's own runtime — repro in `tools/fiba-source-check.ts`. Worked around with an ingest/serve split: `lib/sourceCache.ts`'s `source_cache` table is seeded by `POST /ingest/:source/:dateKey` (bearer-gated by `INGEST_TOKEN`) from an unblocked network — an agent session's `curl`, or a script run locally — and `lib/fiba.ts` reads from it instead of calling out live.
- **Reconciliation** (`lib/fiba.ts`'s `mapEventToGame`): translates ESPN's raw event shape into this project's existing `Game` type — targeting the flat/string variant (`away_team`/`home_team` as plain code strings, scores as flat `metadata` fields) that `games.ts`'s `teamCode`/`teamScore` already read for nfl, so `enrichGames`/`filterByTeams`/`groupBySport`/`pickNextSlate` needed **zero changes**. ESPN's `status.type.state` (`pre`/`in`/`post`) is exact and maps directly into `render/json.ts`'s `STATUS_MAP`, unlike Sleeper's noisier vocabulary. Every field is treated as a progressive enhancement, not a guarantee — a missing team code, score, or broadcast degrades to the same "TBD"/blank the pipeline already shows for an incomplete Sleeper game (verified live: ESPN's `TNT`/`truTV` broadcasts aren't in `catalog.ts`'s channel dictionaries and fall through cleanly to the existing "regional" fallback instead of breaking; `HBO Max` got an explicit `STREAMING_CHANNELS` entry since it's confirmed and recurring).
- **Date window**: `http/handlers/games.ts`'s `fetchGamesByDate` routes each requested sport to its source via `catalog.ts`'s new `SPORT_SOURCE` map, and gives each source its own window instead of one shared constant. Sleeper keeps `windowDatesFor`'s fixed few-day scan (justified by its one-request-per-date cost). `fiba` uses `lib/sourceCache.ts`'s `listFutureDateKeys` — every date `source_cache` actually has from today forward, uncapped, since a local table scan has no per-date cost to bound. The two window's dates are unioned before `pickNextSlate` runs, which needed no changes since it already just walks whatever `dates`/`gamesByDate` arrays it's handed. This is deliberate: the old 3-day cap was a Sleeper-specific constraint that had leaked into shared date logic, not a real limit on how far out "next" should look.
- **Verified live against the deployed endpoint** (2026-09-02, server "today" resolved to 2026-09-01 in the default Pacific client offset): `?teams[]=united-states` correctly surfaced the USA-China group game on **2026-09-04** — a date outside Sleeper's own `[09-01, 09-02, 09-03]` window, proving the union actually reaches past it rather than coincidentally landing inside it. `?sports[]=fiba&day=today` returned all 8 real Sep-4 games, correctly sorted, with real team names and per-game channels. Mixed requests (`teams[]=fever&teams[]=united-states`, one empty source + one populated) and `format=png` both still work. No regression on existing wnba-only requests.
- **Team slugs**: full country names (`united-states`, `puerto-rico`, `south-korea`, `turkey` — not ESPN's `Türkiye` — etc.), not ESPN's 3-letter codes, because `teamLabel` derives the display string from the slug via `titleCase`, which has no acronym handling (`usa` → "Usa"). 16 teams, the current group stage; see `catalog.ts`'s `TEAMS` for the full list.
- **Still open**: knockout-round dates (Sep 8-14) were ingested empty since ESPN hadn't published that schedule yet as of 2026-09-02 — re-ingest closer to those dates. Nothing re-ingests `source_cache` automatically; live/final status accuracy for fiba depends entirely on how recently someone re-ran the ingest loop. That's an accepted trade per this phase's own scope: presence (a game is on the slate at all) is the source's real contract, not intraday freshness.

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
3. For resolve changes, test `/config/resolve` with a non-sensitive fixture device id and remember the tool follows same-origin redirects. Check both the final JSON and the endpoint's redirect behavior when the change concerns caching or query translation.
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
- Sports selection, next-game policy, ordering, channel/matchup/status copy, or server drift handling: change `plusjade/sports-today`.
- Pairing, configuration, device status, or push behavior: inspect both sides and keep the route/client pair synchronized.
- JSON field or meaning: coordinate `render/json.ts`, `Shared/WidgetPayload.swift`, the widget preview fixture, and tests; bump `schemaVersion` when compatibility requires it.
- Backend endpoint identity: do not change it. Preserve `main.ts` and verify `links.endpoint` against `GameDataURL.baseURL`.

After a server contract change, build the iOS app/widget and verify a representative endpoint response. After a presentation-only Swift change, do not touch Val Town merely because the widget consumes remote data.
