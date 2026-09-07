# Clark View ↔ Val Town orientation

Read this before inspecting or changing the Val Town backend. It is a local map of the parts of `plusjade/sports-today` that matter to this repository, updated on 2026-09-06, so routine iOS work should not require rediscovering the remote project through repeated MCP calls.

## One-minute mental model

Clark View is a widget-first iOS product. The containing app is intentionally small: it enrolls an install as a device with a bunch code, exposes prototype diagnostics, and can request a widget reload. The widget is the primary user experience and registers its own WidgetKit push token.

`plusjade/sports-today` is the central orchestrator. It stores device-to-source assignments, hosts the browser administration views, forwards ingest work, and sends best-effort WidgetKit pushes when a device source changes. `plusjade/sports-today-device-feed` owns the current source data, feed execution, and display-ready JSON contract.

This brief is the local orientation source; inspect a named remote module only when the task needs implementation detail beyond what is cached here.

```text
Helper's browser ── /bunches, /devices, /sources ──> Val Town SQLite
                                      │
iOS app ── /pair ─────────────────────┤
                                      │
Widget ── /config/resolve ──> sports-today device lookup
                                      │
                                      └── authenticated RPC ──> sports-today-device-feed
                                                                        │
                                                                        ├── Games handler
                                                                        ├── Moon handler
                                                                        └── WidgetPayload v2
                                      │
                                      ├── Sleeper sports data
                                      └── WidgetKit push refreshes
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
| Device-feed provider val | `plusjade/sports-today-device-feed` |
| Provider RPC file / id | `rpc.ts` / `0d4599dc-aa26-11f1-be61-1607ee4eb77e` |
| Provider RPC endpoint | `https://plusjade--0d4599dcaa2611f1be611607ee4eb77e.web.val.run/` |

The endpoint is derived from the HTTP file id, not from the file path. **Update `main.ts` in place; never delete, recreate, or rename it.** Doing so would mint a new endpoint while the widget continued calling the old one.

Never construct a Val Town URL from the val or file name. When an endpoint check is actually needed, read `links.endpoint` from one `val_town_list_files` call and compare it with `GameDataURL.baseURL`. The exact file id above must remain present.

The iOS machine calls intentionally use the `val.run` endpoint. As of this snapshot, the human-facing `jade.beer` domain is stale for `/config/status/:deviceId` and `/device/token`; keep it out of `GameDataURL` unless that routing issue is separately verified as fixed.

## iOS-side map

| File | Role in the boundary |
| --- | --- |
| `Shared/GameDataURL.swift` | Owns the single backend base URL and builds `/config/resolve?device=&d=<pixels>&tz=<seconds>`. |
| `ClarkViewWidget/ClarkViewWidget.swift` | Fetches the resolved JSON, decodes it, dispatches the selected template, and renders small/medium/large widgets. Medium shows one item; large shows up to three. Its timeline normally refreshes hourly. |
| `Shared/WidgetPayload.swift` | Mirrors JSON schema version 2. This is a display contract, not a raw sports-data model. |
| `Shared/WidgetPresentation.swift` | Loss-tolerant client contract for the optional presentation envelope. Resolves the default `beacon` template and deprecated `standard-v1` plus opaque sRGB Light/Dark Mode root surfaces, falling back to Beacon with white/black roots. |
| `Shared/DeviceIdentity.swift` | Creates the per-install UUID and shares it with the widget through the App Group. Local `isPaired` affects copy only; server state remains authoritative. |
| `Shared/PairingClient.swift` | Sends `POST /pair` with `{code, device}`. |
| `Shared/PushTokenClient.swift` | Mirrors WidgetKit's native push-token lifecycle through `POST /device/token` with `{device, token, kind: "widget", environment, active}`. Debug builds register sandbox tokens and distribution builds register production tokens. |
| `Shared/DeviceStatusClient.swift` | Reads `GET /config/status/:deviceId` for diagnostics; it is not the widget data path. |
| `Shared/WidgetRefreshDiagnostics.swift` | Shares last manual request, network attempt, success, and error metadata from the widget to the containing app through the App Group. |
| `ClarkViewWidget/ClarkViewWidgetPushHandler.swift` | Registers the native WidgetKit push token and removes its server registration when no widget instance remains. |
| `clark_view/ContentView.swift` and `PairingView.swift` | Keep the containing app limited to pairing, server status, widget-refresh diagnostics, and manual reload. Team/sport selection stays in the browser configurator. |

`RefreshWidgetIntent` and the app's refresh buttons only ask WidgetKit for a new timeline. They do not bypass WidgetKit's scheduling guarantees or call a separate refresh endpoint.

## Server-side map

The production boundary spans two vals. `plusjade/sports-today` retains the stable public HTTP entrypoint, device lookup, administration, iOS compatibility surface, and operator-facing ingest routes/runners. `plusjade/sports-today-device-feed` owns feed execution and the `cached_games`, `messages`, and `source_cache` tables.

Val Town's val-scoped SQLite follows the **executing val**, not the `esm.town` module that defined an imported function. Directly importing a provider function from the parent therefore reads or writes the parent's database. Database-backed cross-val work must enter the provider's `rpc.ts` HTTP runtime. The RPC is bearer-gated by `DEVICE_FEED_RPC_TOKEN`, stored independently in both vals; never expose its value. The parent centralizes calls in `lib/deviceFeedClient.ts`. `main.ts` in the provider remains a child-local script export, not the production cross-val database boundary.

Responses crossing that boundary are parsed, not asserted. `rpcJson` takes a type guard and throws naming the endpoint when a body does not match, so a provider contract drift fails at the seam instead of surfacing as an undefined property several frames away. Two calls are deliberately exempt, for opposite reasons. `deviceFeedResponse` is not parsed because the widget payload is the provider's contract with iOS and the parent streams it through untouched rather than taking a position on a schema it does not own — which also means validating in the parent cannot protect the iOS contract; only a contract test against the provider can. `fetchCachedFibaScoreboard` returns `unknown` because it hands back ESPN's stored payload verbatim and its caller only tests for null, so there is no shape to assert. The one place the parent does read inside a widget payload is `previewResponse` in `http/routes/devices.ts`, which checks each item and lets the preview page's existing error state show the failure.

A dead-export pass on 2026-09-06 removed `sendWidgetPush` (no caller; `notifyDevice` is the whole push API) and collapsed one presentation constant that carried three exported names — `DEFAULT_WIDGET_PRESENTATION`, `CONTROL_WIDGET_PRESENTATION` and `INITIAL_DEVICE_PRESENTATION` were always the same object, serving as both the parse fallback and the registration seed. `DataFeed` and `GamesSettings` in `lib/resolver.ts` were inlined at their single use rather than exported. `PushKind`, `SourceDeviceView` and `WidgetTemplate` were deliberately kept exported: each names a domain shape used repeatedly inside an exported signature. The same pass finished `isRecord`'s consolidation into `lib/guards.ts`, and rewrote `tools/presentation-check.ts`, which had asserted the retired v1 contract (`fullColor.primarySurface`, `system-v1`/`future-v2`) and so had been failing since the Beacon migration instead of guarding anything.

The parent val's relevant modules are:

| Remote path | Responsibility |
| --- | --- |
| `main.ts` | Stable Hono assembly point. Preserve this file's identity; route implementations live under `http/`. |
| `http/routes/*.ts` | Hono route groups for the HTML-only root, stable iOS compatibility URLs, browser administration APIs, and ingest. The parent has no source-feed routes or handler directory. |
| `lib/deviceFeedClient.ts` | Authenticated client for the composed device feed, source-cache ingest, Sleeper ingest/coverage, and FIBA cache checks. Owns the provider RPC endpoint and reads `DEVICE_FEED_RPC_TOKEN`. Typed responses are parsed through a guard, not asserted. |
| `lib/guards.ts` | Domain-free runtime type guards. Sole home of `isRecord`, which five modules previously defined for themselves. |
| `lib/catalog.ts` | Known sports and teams used to parameterize Games source assignments in the parent UI. |
| `lib/resolver.ts` | Parent-side source-assignment types plus the small Games projection used by device status. Feed request normalization belongs to the provider. |
| `lib/deviceStore.ts` | Device-centric projections and writes for names, presentation, and `device_sources` assignments. Device views deliberately omit bunch membership; assignment writes validate ownership and rely on SQLite's JSON, priority, foreign-key, and uniqueness constraints. |
| `lib/deviceSourceStore.ts` | Widget-facing read seam that resolves an install id to its presentation and all sources by `(priority ASC, device_sources.id ASC)`. |
| `lib/presentation.ts` | Versioned widget-presentation types, the single `DEFAULT_WIDGET_PRESENTATION` value, loss-tolerant stored JSON parsing, and browser-form validation. |
| `lib/deviceTokenStore.ts` | App-background and native-widget APNs token persistence keyed by `devices.install_id`. Native tokens are preferred while old beta builds retain a fallback. Token uploads may precede device registration. |
| `lib/sourceStore.ts` | Read-only projections of source definitions, JSON settings schemas, and their device assignments for the browser explorer. |
| `lib/bunchStore.ts` | Bunch administration, reusable 30-minute bunch codes, and new-model device registration. A valid code is the only write path that creates or moves a device into a bunch. |
| `lib/push.ts` | Best-effort APNs delivery to one device, preferring native WidgetKit pushes while retaining app-background tokens as an old-beta fallback. Source-wide fan-out went with the Messages retirement. |
| `render/pageShell.ts` | Shared browser shell owning typography, color tokens (light and Dark Mode), resource tables/navigation, forms, breadcrumbs, and timestamp localization. Mobile-first: the unqualified rules are the phone layout and `min-width: 40em` blocks restore the wide one. |
| `render/deviceHtml.tsx` | React-rendered device index, source-assignment and presentation forms, and provider-backed device preview composed through the shared `pageShell`. |
| `render/sourceHtml.tsx` | React-rendered, read-only source index/show composed through `pageShell`, including human-readable JSON Schema fields and linked device assignments. |
| `render/bunchHtml.tsx` | React-rendered bunch index/detail and pairing-code pages. Bunches appear only in enrollment/access administration, not device feed rendering. |
| `render/rootHtml.ts`, `render/dataTable.tsx` | The HTML-only application root and the shared `DataTable`/`Row`/`Cell` table primitives every index and detail table is built from. `Cell` emits `data-label` (the stacked phone layout prints it in place of the hidden header) and each element carries its implied ARIA role, which a `display` change would otherwise drop. |

Prefer changing pure helpers and their tests over adding policy directly to an I/O module. Keep `main.ts` as route wiring and edge behavior.

The parent no longer contains any source-feed handler. The retired public `GET /messages`, `GET /moon`, `GET /?format=json`, and `GET /?format=png` behaviors had no first-party runtime caller and were removed on 2026-09-06. Their parent-only request parsing, slate selection, date/channel enrichment, JSON/PNG renderers, and layout support were deleted with them. Source execution and widget-payload rendering now exist only in the provider; the parent receives the complete response through `deviceFeedResponse`. The data those renderers read went with them: `lib/catalog.ts` keeps only `SPORTS` and `TEAMS` (the vocabulary a Games assignment is written against), having shed `SPORT_SOURCE`, `SPORT_EMOJI`, `NATIONAL_CHANNELS`, `STREAMING_CHANNELS`, `MAX_CHANNEL_LABEL`, and `MAX_TEAMS`; `lib/text.ts` keeps only `titleCase`; and `lib/push.ts` no longer exports the `sendSilentPush` compatibility seam. `notifyDevice` is the whole push API.

The Messages source was retired from the parent on 2026-09-06. It was a proof of concept, and its parent-side plumbing carried the two couplings least worth keeping: a browser form that wrote through the RPC boundary and then fanned out pushes locally in a separate, non-transactional step, and a "singleton Messages source" invariant enforced only by the parent's route guard while the provider's read and write side stayed globally unscoped. Removed together: the `GET/POST /sources/:id/messages` routes; `listMessages`, `createMessage` and `StoredMessage` in `lib/deviceFeedClient.ts`; `sourceMessagesDocument` and `SourceMessageView` in `render/sourceHtml.tsx`; `notifySourceDevices` in `lib/push.ts`; `getTokensForSource` in `lib/deviceTokenStore.ts`; and the `datetime-local` form styling plus ISO-timestamp script in `render/pageShell.ts`. The `sources` row (`id=2`) was deleted — no device was attached to it — and `"messages"` is gone from every parent type union (`SourceKind`, `DataFeed`, `settingsFor`, `SourceSettingsFields`), so the parent can no longer write a Messages assignment or send that kind across the RPC boundary. `sources.kind`'s CHECK still admits `'messages'`: the constraint was left alone rather than recreating the table for no behavioral gain, and it is what a re-implementation will want anyway. The provider's `messages` table and handler are untouched and still hold their rows. Re-implementation in a more aligned pattern is deferred until the parent/source boundary stabilizes.

## HTTP surface and callers

| Method and route | Caller | Contract / caution |
| --- | --- | --- |
| `GET /` | Helper's browser | Always renders the centered administration nav to `/bunches`, `/devices`, and `/sources`. Query parameters do not select a data representation. |
| `GET /config/resolve` | Widget | Stable compatibility URL over the device model. Accepts `device`, legacy no-op `d=<pixelWidth>x<pixelHeight>`, and `tz=<seconds east of GMT>`, looks up `devices.install_id`, and loads the device presentation plus every `device_sources` row by `(priority ASC, id ASC)`. The parent sends that configuration through its authenticated provider client; the provider executes sources in its own runtime, globally sorts their items by timestamp, attaches `presentation`, and returns schema-v2 JSON with `cache-control: no-store`. An unknown or source-less device gets the starter-team feed, and an unknown device gets the default Beacon presentation. `x-device-feed-provider`, `x-effective-source-count`, and `x-effective-sources` expose boundary/composition diagnostics without changing the body contract. |
| `POST /pair` | Containing app | Stable compatibility URL over bunch enrollment. JSON `{code, device}` redeems a `bunch_codes` row, registers or moves `devices.install_id`, and returns `{ok: true, deviceId}` (200). An unknown code is `{ok: false}` (404); an expired code is `{ok: false, message: "expired"}` (422). Codes are six characters and reusable until their 30-minute expiry. The app intentionally requires only `ok`, because the internal integer id is not part of its data path. |
| `POST /devices/register` | Browser/new-model API | JSON `{code, device, name?}`. Performs the same bunch registration as `/pair`, with an optional device name. Unknown and expired codes use the same 404/422 split. |
| `POST /device/token` | Widget push handler; legacy containing apps | Native JSON is `{device, token, kind: "widget", environment: "sandbox" | "production", active}`. `active: false` removes the widget token after the last instance disappears. Missing `kind`, `environment`, and `active` remain compatible with old beta builds uploading a sandbox app-background token. Tokens are stored independently of pairing; delivery prefers a widget token and otherwise falls back to the legacy app token. |
| `GET /config/status/:deviceId` | Containing app diagnostics | Stable compatibility URL over the device model. Always returns 200 for a syntactically valid request; an unknown install is `{deviceId, paired: false}`. A registered install returns `paired`, its device name, `activeSource`, and the primary Games source's sports/teams (empty arrays for a non-Games primary source or no source). No config id is exposed. |
| `GET /devices/resolve` | New-model alias | Accepts the same `device`, `d`, and `tz` parameters and returns the same ordered, combined response as `/config/resolve`. The iOS widget remains on the stable config-named URL until route renaming is coordinated. |
| `GET /devices/status/:installId` | New-model diagnostics | Returns registration state, device name, active source, and ordered source settings without exposing bunch membership. The iOS app remains on the stable config-named URL until route renaming is coordinated. |
| `GET /devices` | Helper's browser | Index of every new-model device, with install id, source count, and a link to the internal integer-id show route. Bunch membership remains intentionally absent. |
| `GET/POST /devices/:id` | Helper's browser | Device detail and direct name edit. Lists assignments in deterministic `(priority ASC, id ASC)` order and expands settings. |
| `GET/POST /devices/:id/presentation` | Helper's browser | Reads or edits the device-owned template and opaque Light/Dark Mode root surface values. The editor offers Beacon; `standard-v1` remains deprecated and is no longer selectable. Saving validates the versioned domain shape, updates the device row, and sends a best-effort push to that device. |
| `GET /devices/:id/sources/new`, `POST /devices/:id/sources` | Helper's browser | Two-step source attachment: choose one singleton source not already attached, then set its positive integer priority and source-specific settings. Games accepts catalog-filtered sports/teams plus `intradayFilter`; Moon stores `{}`. |
| `GET/POST /devices/:id/sources/:assignmentId` | Helper's browser | Reads or edits one assignment owned by the device. This is the device-centric replacement for config Settings plus Personalization; feed choice is assignment presence/order rather than `dataFeed`. Saving sends a best-effort silent push only to that device. |
| `POST /devices/:id/sources/:assignmentId/delete` | Helper's browser | Removes only the device/source edge, leaving the singleton source and source-owned data intact. |
| `GET /devices/:id/preview` | Helper's browser | Runs the same concurrent, ordered composition as the device resolver and renders both item rows and raw schema-v2 JSON. A device without assignments previews the same starter-team fallback used by the resolver. |
| `GET /sources` | Helper's browser | Read-only index of singleton source definitions with schema-field and attached-device counts. |
| `GET /sources/:id` | Helper's browser | Read-only source detail using the internal integer id. Expands the available JSON Schema, shows source timestamps, and lists attached devices with priorities and human-readable assignment settings. |
| `GET /bunches`, `GET /bunches/new`, `POST /bunches` | Helper's browser | Parallel new-model replacement for the config collection/create intention at the access boundary. Lists or creates enrollment scopes; feed settings are not stored here. |
| `GET/POST /bunches/:id` | Helper's browser | Shows/renames a bunch and lists its devices. This is access/enrollment administration and is intentionally separate from `/devices/:id` rendering configuration. |
| `GET /bunches/:id/pair`, `POST /bunches/:id/codes` | Helper's browser | Lists bunch-code history and creates reusable 30-minute enrollment codes. There is deliberately no direct cross-bunch “link existing device” form; moving a device across the ACL boundary requires a valid code through `/devices/register`. |
| `POST /ingest/:source/:dateKey` | External ingest process only — never the widget, app, or configurator | The parent keeps the stable bearer gate (`INGEST_TOKEN`, value not recorded here), then forwards the payload through authenticated RPC so the provider writes its own `source_cache`. Body is stored verbatim as JSON. |

Only `/config/resolve` and `/config/status/:deviceId` remain under the config-named prefix; these names are stable iOS compatibility contracts, not config resources. `GET /config`, `GET /messages`, `GET /moon`, the retired `/sources/:id/messages` pair, and all former id-scoped browser routes return 404. The root ignores former `format`, team, day, and dimension query parameters and always returns HTML.

Current fallback behavior matters: an unknown, unpaired, or source-less device is resolved with the `fever` + `sparks` starter-team configuration.

The retired `configs`, `device_configs`, and `pairing_codes` tables were dropped after the device cutover. In the parent, canonical enrollment and rendering state lives in `bunches`, `bunch_codes`, `devices`, `sources`, `device_sources`, and `device_push_tokens`; `devices.presentation` is validated JSON with a non-null initial value. The provider owns `cached_games`, `messages`, and `source_cache`. The parent's own copies of those three tables have been dropped: no parent code referenced them, and no parent module issues SQL against them. Every remaining parent dependency on that data goes through `lib/deviceFeedClient.ts` over authenticated RPC.

The pre-`device_push_tokens` `device_tokens` table was dropped on 2026-09-06, along with the `INSERT OR IGNORE` backfill and the `apns_environment` ALTER that `ensureDeviceTokenSchema` replayed on every cold start. Both migrations had long since completed; replaying the backfill resurrected any app-background row that dead-token cleanup had deleted, because `INSERT OR IGNORE` only skips rows that still exist. Four token rows referencing installs that were never registered as devices were deleted at the same time. `tools/device-token-check.ts` guards the result: it calls `ensureDeviceTokenSchema` and then asserts the table is not recreated, that no token row is orphaned, and that lookup still prefers a widget token. Every registered device currently holds both a widget and an app-background token, so nothing selects the app-background row today — it remains a real standby, reachable again if a device's last widget instance disappears and its widget token is removed.

## Widget JSON contract

The `/config/resolve` response is `schemaVersion: 2` with provider-ordered `items`. The provider also emits a deprecated top-level `eyebrow`; Swift deliberately ignores unknown keys and derives each item's day label from its timestamp.

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
  ],
  "presentation": {
    "version": 2,
    "template": "beacon",
    "rootSurface": {
      "light": "#FFFFFF",
      "dark": "#000000"
    }
  }
}
```

Device resolver responses now always include the additive `presentation` envelope. Paired devices
source it from `devices.presentation`; existing and newly paired devices use Beacon with the
white/black values above. Registration explicitly writes this default rather than relying on the
table's dormant legacy column default. An unknown device receives the same Beacon presentation.

One template id represents its complete small/medium/large family; the server does not choose a
template by widget dimensions. Root surface values are opaque six-digit sRGB colors selected by
the device's Light or Dark Mode. Missing presentation, unsupported versions, unknown templates, and
the retired `system-v1` identifier fall back to Beacon without discarding valid items. A missing or
invalid individual Light/Dark Mode value falls back independently to white/black. Accented and vibrant
rendering remain system-owned native presentations.

`standard-v1` is the deprecated original accessibility-focused family: it intentionally uses measured
scaling and tuned fixed geometry to maximize type for older people and people with low vision.
`beacon` is the current default. It mirrors that family's established layout and positioning, but leaves semantic
SwiftUI text styles at their system-resolved sizes instead of measuring and scaling the rendered
stack. It retains tuned spacing while allowing each family to
use its available content width without manually magnifying its type. Its removable WidgetKit
container selects the server-provided root surface matching Light or Dark Mode. Cards, controls,
borders, text, and accents use Apple's semantic colors. In full-color mode, only the focused card
uses regular material; the compact card is transparent so the root surface shows through directly.
Reduce Transparency gives the focused card an opaque semantic surface, while non-full-color widget
appearances remain WidgetKit-owned. Its shared
date/time treatment keeps the localized time on one conventional line (`TODAY · 8:10 PM`), with
a prominent primary style and a smaller secondary style. The large Beacon view renders the
first two server-ordered items. Its local interactive focus can promote the secondary item without
changing the payload, server order, or either item's position. The focused item grows in place while
the other item adopts the compact presentation. Both items remain leading-aligned regardless of focus;
the focused item uses a contrasting filled surface and subtle solid keyline while the compact item
uses a dashed outline and roughly 70/30 content-and-action row. `StaticConfiguration` means
that focus is shared by widget instances on the device. Focus-triggered timeline entries reuse the
last successfully decoded payload from App Group storage so the interaction does not wait on the
endpoint; scheduled and explicit refreshes continue to request current server data. Secondary detail
remains in the SwiftUI view tree while an animatable layout collapses its intrinsic height and opacity,
keeping it synchronized
with the rest of the focus transition without measured or fixed dimensions. The compact item exposes
a circular system-symbol `Show Larger` cue in the trailing action column. Each full card is a button:
the compact card changes focus, while the focused card captures the tap without changing presentation.
Custom motion is disabled when the system Reduce Motion preference is active.

Beacon intentionally has no refresh affordance: its cards own the complete widget interaction
surface. Manual beta refresh lives in the containing app, where diagnostics show the last request,
network attempt, successful fetch, and failure result. `standard-v1` retains its older on-widget
refresh control for now.

`ClarkViewWidget` registers `.pushHandler(ClarkViewWidgetPushHandler.self)` and carries the Push
Notifications entitlement on the widget extension rather than the containing app. The server sends
native refreshes with `apns-push-type: widgets`, the widget-extension topic suffix
`.push-type.widgets`, and `{ "aps": { "content-changed": true } }`. WidgetKit push delivery remains
opportunistic, so the hourly timeline is still load-bearing. Each token records whether it belongs to
Apple's sandbox or production host, allowing Xcode and TestFlight builds to coexist. Val Town requires
`APNS_KEY_ID`, `APNS_TEAM_ID`, and `APNS_AUTH_KEY`. `APNS_APP_TOPIC` and `APNS_WIDGET_TOPIC` are
optional overrides of the known bundle-derived topics.

Contract rules:

- `mainText`, `subText`, `caption`, item order, and `emphasized` are server-owned view decisions.
- `caption: null` tells Swift to format `timestamp` as the device-local start time. Live is currently `caption: "LIVE"` with `emphasized: true`; final is `"END"` without emphasis.
- `timestamp` is Unix **seconds**, decoded with `.secondsSince1970`; milliseconds would silently produce a date thousands of years in the future.
- Swift derives `TODAY`, `TMRW`, or a localized month/day from each timestamp.
- The product intentionally displays no scores or live game clock.
- Preserve or add fields compatibly. Removing or repurposing a field requires a schema-version bump and coordinated server, Swift model, preview fixture, and decoding changes.

Provider renderers normalize Games and Moon data into this contract before the response crosses the RPC boundary. The provider still carries a Messages renderer and its `messages` table, but the parent no longer assigns that kind, so nothing reaches it — see the Messages retirement note above. No source schema or assignment retains `legacyConfigId`; Games assignments contain only the live `teams` and `intradayFilter` values.

The device feed is globally sorted by item timestamp after all assigned sources execute concurrently. Assignment priority and id still determine the stable input order, so equal timestamps retain the configured source order. A source failure currently fails the whole composition; partial-feed degradation has not been introduced.

## FIBA women's basketball — live, second source wired into the widget pipeline

Sleeper's `/scores` has no FIBA competitions. Phased deliberately: Phase 1 validated a source and shape; Phase 2 (this section) is the provider-owned reconciliation service that normalizes it into `Game` and wires it into the real device-feed path.

- **Source**: ESPN's unofficial `site.api.espn.com/apis/site/v2/sports/basketball/fiba/scoreboard`. Currently the FIBA Women's Basketball World Cup 2026 (Berlin, Sep 4-14). This ESPN league (id 53, name literally "FIBA World Cup") is a single flagship-tournament bucket ESPN re-points per cycle, not a durable "women's basketball" feed — it returned zero events for the Aug 2024 Olympics window, and there's real risk it repoints to the *Men's* World Cup in 2027. Re-validate before trusting it for any window beyond the current one.
- **Why the provider doesn't fetch it live**: `site.api.espn.com` returns `403 Forbidden` (Akamai edge rule against Val Town's shared egress IPs, confirmed ESPN-wide not FIBA-specific, not fixable with headers). An external process fetches from an unblocked network and POSTs to the parent's bearer-gated `/ingest/:source/:dateKey`; the parent forwards it to the provider's authenticated RPC, and provider `lib/sourceCache.ts` stores it.
- **Reconciliation** (provider `lib/fiba.ts`): translates ESPN's raw event shape into the existing `Game` type. ESPN's `status.type.state` (`pre`/`in`/`post`) maps into the provider renderer's status vocabulary. Missing team, score, or broadcast data remains a progressive enhancement rather than failing the feed.
- **Candidate lookup**: provider `feeds/games.ts` queries `cached_games` with one indexed seek per Sleeper-backed team and scans future FIBA `source_cache` date keys only when FIBA is selected. Slate selection and JSON rendering remain entirely inside the provider runtime.
- **Historical live verification** (2026-09-02): the then-public stateless route proved that the union reached beyond Sleeper's three-day window and that mixed Sleeper/FIBA selections rendered correctly. Those parent diagnostic formats were retired on 2026-09-06; current verification goes through `/config/resolve` or a device preview.
- **Team slugs**: full country names (`united-states`, `puerto-rico`, `south-korea`, `turkey` — not ESPN's `Türkiye` — etc.), not ESPN's 3-letter codes, because `teamLabel` derives the display string from the slug via `titleCase`, which has no acronym handling (`usa` → "Usa"). 16 teams, the current group stage; see `catalog.ts`'s `TEAMS` for the full list.
- **Still open**: knockout-round dates (Sep 8-14) were ingested empty since ESPN hadn't published that schedule yet as of 2026-09-02 — re-ingest closer to those dates. Nothing re-ingests `source_cache` automatically; live/final status accuracy for fiba depends entirely on how recently someone re-ran the ingest loop. That's an accepted trade per this phase's own scope: presence (a game is on the slate at all) is the source's real contract, not intraday freshness.

## Moon — lunar full moons, a third static source

Added 2026-09-04 as the third row in `sources` (`id=3`, `kind='moon'`), alongside Games and the since-retired Messages. Games and Moon are the two remaining rows. Devices attach to it the same way as any other singleton source.

- **Schema change**: `sources.kind` was `CHECK (kind IN ('games', 'messages'))`. SQLite can't alter a `CHECK` in place, so the table was recreated (same `id`s, same `ux_sources_kind` unique index) with `moon` added to the constraint. `device_sources.source_id`'s FK survives this untouched — SQLite doesn't enforce FK constraints against DDL, only DML, so dropping/recreating the parent table mid-transaction never orphans the child rows.
- **No live-fetch problem, unlike FIBA**: full-moon instants are public, deterministic astronomical data. Provider `source_cache` (`source='moon'`) is reused because a calendar year's full moons are a small, fixed set; provider `lib/sourceCache.ts` and `lib/moonPhases.ts` answer the "next date on or after X" query.
- **Dataset**: 13 full moons for calendar year 2026, UTC peak instants sourced from Astropixels (Fred Espenak's ephemeris tables) and cross-checked against timeanddate.com's Central-Time table converted through 2026's US DST boundaries (Mar 8 / Nov 1) — independent sources agreed to the minute. One calendar Blue Moon (May 31, the second full moon in May). Payload shape per row: `{peakTime: "2026-01-03T10:03:00Z", name: "Wolf Moon", isBlueMoon: false}`, `date_key` = the UTC calendar date of the peak.
- **Serving shape skips the `Game` pipeline**: a full moon has no teams or score. Provider `lib/moonPhases.ts` returns the next event; provider `render/moonJson.ts` maps it directly to one schema-v2 item.
- **`caption: "PEAK"`, not `null`**: `caption: null` tells `ClarkViewWidget.swift`'s `displayCaption` to fall back to formatting `timestamp` as a local clock time — correct for a game's kickoff, wrong here. `peakTime` is the exact geocentric opposition instant (Sun-Earth-Moon at 180°), which is unrelated to moonrise/moonset at any given location and routinely falls during local daylight (2026-09-26's is 9:49am Pacific — the Moon isn't even up then). A fixed caption avoids implying "go look now" at an instant that's often unviewable; the day label (TODAY/TMRW/date) is still derived from `timestamp` independently of `caption`, so that stays correct.
- **`tz` is UTC-offset seconds, and stays provider-side day-boundary-only**: provider `lib/dates.ts` documents that iOS sends `TimeZone.current.secondsFromGMT()` (seconds, not minutes). The Moon source uses it to resolve the client's local "today" as the start of the forward scan through `source_cache`; `peakTime` itself is never shifted. There is no public parent `/moon` route.
- **Settings**: `{}` — nothing is device-configurable. `render/deviceHtml.tsx`'s `SourceSettingsFields` and `http/routes/devices.ts`'s `settingsFor` both special-case `kind === "moon"`; since the Messages retirement it is the only kind they special-case. `render/sourceHtml.tsx` needed no changes — its index/show documents are already generic over `kind`.
- **Still open**: nothing re-seeds `source_cache` for 2027 automatically. Re-run the same research-and-insert step for the next calendar year before this one runs out, the same trade-off FIBA's uncapped-but-manually-ingested window makes.

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
2. For widget-contract or resolve changes, test `/config/resolve` with a non-sensitive fixture device id. Confirm the direct response status, schema-v2 JSON, source diagnostics, and ordering; the resolver no longer redirects.
3. For parent root changes, confirm both `/` and a query-bearing root URL return `text/html`; source-shaped query parameters must not reactivate a data representation.
4. Call `val_town_list_files` once after deployment only when the change touched `main.ts` or endpoint identity must be certified. Confirm the file id and endpoint above did not change.
5. Use `val_town_get_traces` or `val_town_get_logs` only after a failed or surprising response. Filter to the known `main.ts` file id/trace instead of polling the whole project.

Do not use live POST routes as smoke tests. Pairing, token upload, bunch/code creation, source assignment, and device/bunch renaming all mutate production state. Exercise them only when the task explicitly requires that mutation and use disposable data where possible.

### Storage and secrets

- Prefer route-level diagnostics first. If SQLite inspection is necessary, use `val_town_sqlite_execute` with `database: { type: "val", val: "plusjade/sports-today" }`, `mode: "read"`, a parameterized query, and a narrow projection/limit.
- Never dump or repeat configuration capability ids, device ids, pairing codes, or APNs tokens in chat, logs, fixtures, or this repository.
- `val_town_list_env_vars` exposes metadata/keys, not values. Use it only for an APNs/integration task; do not repeatedly check for secrets that code inspection does not require.

## Change-location checklist

Before editing, classify the request:

- Widget layout, family-specific item count, local date/time format, empty-state copy, or refresh affordance: change the iOS repository.
- Sports selection, next-game policy, ordering, channel/matchup/status copy, or source drift handling: change `plusjade/sports-today-device-feed`; change the parent only when assignment parameters or orchestration also change.
- Pairing, configuration, device status, or push behavior: inspect both sides and keep the route/client pair synchronized.
- JSON field or meaning: coordinate the provider renderer, `Shared/WidgetPayload.swift`, the widget preview fixture, and tests; bump `schemaVersion` when compatibility requires it.
- Backend endpoint identity: do not change it. Preserve `main.ts` and verify `links.endpoint` against `GameDataURL.baseURL`.

After a server contract change, build the iOS app/widget and verify a representative endpoint response. After a presentation-only Swift change, do not touch Val Town merely because the widget consumes remote data.
