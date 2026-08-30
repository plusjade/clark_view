# Clark View ↔ Val Town orientation

Read this before inspecting or changing the Val Town backend. It is a local map of the parts of `plusjade/sports-today` that matter to this repository, captured on 2026-08-30, so routine iOS work should not require rediscovering the remote project through repeated MCP calls.

## One-minute mental model

Clark View is a widget-first iOS product. The containing app is intentionally small: it registers for push, pairs an install to a helper-managed configuration, exposes prototype diagnostics, and can request a widget reload. The widget is the primary user experience.

`plusjade/sports-today` is the product brain. It stores device-to-configuration associations, fetches sports data, chooses the next relevant slate, creates the display-ready JSON contract, hosts the browser configurator, and sends best-effort silent pushes when a configuration changes.

Several Swift comments refer to `docs/widget-config-plan.md` or other planning notes that live with the backend work and are not present in this repository. This brief is the local orientation source; inspect a named remote module only when the task needs implementation detail beyond what is cached here.

```text
Helper's browser ── /config/* ──> Val Town SQLite
                                      │
iOS app ── /pair, /device/token ──────┤
                                      │
Widget ── /config/resolve ── 302 ──> /?format=json ──> WidgetPayload v2
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

The remote val has one HTTP file plus `lib/` and `render/` modules:

| Remote path | Responsibility |
| --- | --- |
| `main.ts` | Hono routing and edge orchestration. Preserve this file's identity. |
| `lib/catalog.ts` | Known sports, teams, and channel tables. |
| `lib/params.ts`, `lib/games.ts`, `lib/dates.ts`, `lib/teams.ts`, `lib/channels.ts` | Pure request validation, slate selection, date handling, and display enrichment. |
| `lib/config.ts` | Pure translation from stored preferences plus live device facts into the redirected JSON URL. |
| `lib/configStore.ts` | Val-scoped SQLite for configs (each with an auto-generated `adjective-noun` name, non-unique, editable — see `generateConfigName`/`renameConfig`), 30-minute pairing codes, device bindings/names, and APNs tokens. |
| `lib/sleeper.ts` | Outbound Sleeper data access. |
| `lib/push.ts` | Best-effort APNs silent push delivery. |
| `render/json.ts` | The native widget's schema-versioned response. |
| `render/configHtml.ts` | The helper-facing browser configurator: six focused documents (`configIndexDocument`, `configNewDocument`, `configSettingsDocument`, `configDevicesDocument`, `configPairDocument`, `configPreviewDocument`) sharing a `pageShell`/`configNav`, not one monolithic page. |
| Other `render/*` files | HTML/PNG rendering retained by the general sports endpoint; not the native widget's rendering path. |

Prefer changing pure helpers and their tests over adding policy directly to an I/O module. Keep `main.ts` as route wiring and edge behavior.

## HTTP surface and callers

| Method and route | Caller | Contract / caution |
| --- | --- | --- |
| `GET /` | Browser, diagnostics, render verification | Stateless sports endpoint. `format=json` is the widget contract; HTML is the default and PNG is also supported. Repeated `sports[]` and `teams[]` parameters are validated without turning drift into a fatal widget error. |
| `GET /config/resolve` | Widget | Accepts `device`, `d=<pixelWidth>x<pixelHeight>`, and `tz=<seconds east of GMT>`. Looks up the device and returns an uncached 302 to `/?format=json&w=&h=&...`. The widget's `URLSession` follows it. |
| `POST /pair` | Containing app | JSON `{code, device}`. Returns `{ok: true, configId}` (200), an unknown code as `{ok: false}` (404), or an expired code as `{ok: false, message: "expired"}` (422). Codes are six characters, reusable until their 30-minute expiry. Re-pairing replaces the binding. |
| `POST /device/token` | Containing app | JSON `{device, token}`. Upserts the APNs token independently of pairing. |
| `GET /config/status/:deviceId` | Containing app diagnostics | Always returns 200 for a syntactically valid request; an unknown device is `{deviceId, paired: false}`. |
| `GET /config` | Helper's browser | Prototype-stage only, no auth: every config row (name, id, resolved favorites, paired-device count, last-updated) as a live link. A row with a name shows it as the link text with the id underneath in monospace; a pre-migration row with no name yet falls back to the id alone, exactly as before this field existed. Not the unguessable-capability pattern the id-scoped routes below use — an accepted bypass until `/config` gets real access control. |
| `GET /config/new` | Helper's browser | Blank team/sport picker, plus a name field eagerly prefilled with a fresh `adjective-noun` candidate from `generateConfigName` (ported from a Ruby `SlugGenerator`; not unique-checked, since config names are a non-unique convenience label, not an identifier — the UUID stays the capability) — so the configurator sees the default and can edit or clear it before the row exists, rather than only on the Settings page afterward. |
| `POST /config/new` | Helper's browser | Creates a configuration with whatever that form's name field submits (edited, untouched, or cleared to null) and redirects to its capability URL. |
| `GET/POST /config/:id` | Helper's browser | The Settings sub-view — reads or updates the sports/teams selection, plus the config's name (prefilled with its current name, blank for a pre-migration row) in the same form/submit via `renameConfig`. The unguessable URL is the capability; do not expose real ids in logs or docs. Saving also attempts silent pushes. Device list, pairing, and preview live on their own routes below, reached via a persistent top nav (Settings \| Devices \| Pair a device \| Preview) plus a "← All configs" breadcrumb. |
| `GET /config/:id/devices` | Helper's browser | The paired-device list and rename forms. Each row shows the device id, paired-since timestamp, and push-registration status (whether an APNs token is on file, and when it last updated) alongside the existing name input. |
| `GET /config/:id/pair` | Helper's browser | The pairing-code flow. Below the mint-a-code button, lists this config's expired pairing codes (code, created, expired) — nothing prunes `pairing_codes`, so this is every code that's aged out for that config, most recent first. |
| `POST /config/:id/code` | Helper's browser | Creates a pairing code and renders the pair view with the freshly minted code (plus the same expired-codes list). This mutates live SQLite state. |
| `GET /config/:id/preview` | Helper's browser | A read-only render of what `/config/resolve` would currently hand the widget for this config — the items list as a table, plus the full `format=json` response pretty-printed in a `<pre>`. Genuinely live: it runs this config through the same `gamesHandler` path as `/` itself (real Sleeper calls), not a cached snapshot, so a Sleeper failure surfaces as this page's own error state rather than a 500. |
| `POST /config/:id/devices/:deviceId` | Helper's browser | Renames a paired device for the helper's reference. Redirects back to `/config/:id/devices`. |

Current fallback behavior matters: an unknown or unpaired device is resolved with the legacy `fever` + `sparks` team configuration. An older comment in the widget still describes an all-sports fallback; treat the deployed server behavior above as current until a deliberate cross-project change reconciles both sides.

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

Do not use live POST routes as smoke tests. `/config/new`, `/config/:id`, pairing, token upload, code creation, and device rename all mutate production state. Exercise them only when the task explicitly requires that mutation and use disposable data where possible.

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
