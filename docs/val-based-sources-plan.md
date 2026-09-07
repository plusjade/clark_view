# Val-based sources: direction and first implementation plan

Status: milestone one deployed on 2026-09-07. See `valtown-brief.md` for the
current endpoints, validation results, and deliberate compatibility seams.
The remaining milestones are proposed.

## Direction

Allow agents to produce useful source feeds without deploying application code.
A source is an independently operated capability, not a table. It can use multiple
tables and must expose both a configuration contract for the parent admin and a
display-item contract for the widget feed.

The intended lifecycle is sandboxed authoring → deterministic validation →
immutable release → pointer activation → contract-conforming serving. Items,
facets, and options are the default data model. Custom implementations can expose
the same contracts through a separately authorized code deployment path.

Use one val and its backing SQLite database per source instance. Stable source
identity is independent of the val endpoint and active release. Each source instance belongs to a bunch; milestone one records this ownership
without building sharing, subscriptions, or ACL machinery. The prototype has
effectively one scope. `games` remains a legacy internal adapter name for sports
competitions; the new val is `plusjade/source-sports`.
Immutable implementation/package releases and changing live data are distinct.

## Sequential milestones

1. **Establish parent → N source-val routing.** Create public
   `plusjade/source-sports` from the existing provider, including data. Add a
   versioned source shim, parent-owned pointers, generic composition, and explicit
   compatibility adapters. Keep Games internals and existing widget behavior.
   Prove two destinations using Games on the new val and Moon on the old sibling.
2. **Make configuration domain-independent.** Source descriptors supply settings,
   options, and validation. Replace parent Games/Moon form branches with the small
   supported descriptor vocabulary. Remove remaining legacy routing adapters.
3. **Provide a standard data-package template.** Implement items/facets/options,
   package metadata, deterministic example inputs/outputs, and explicit temporal
   and freshness semantics. Verify it with a non-sports source. Keep custom vals
   possible without making arbitrary runtime execution part of the data path.
4. **Introduce candidate validation and immutable publication.** Isolate agent
   workspaces; validate candidate packages; activate accepted revisions by pointer.
   Establish rollback, resource limits, and enforceable agent capabilities. A
   contract version or revision label alone is not an immutability guarantee.
5. **Extend ownership and operations when needed.** Model bunch subscriptions and
   private/shared source instances, device moves, retention, freshness reporting,
   and source-change notification. Choose partial-failure behavior explicitly.

## Milestone 1 outcome and scope

A device assigned Games and Moon resolves through two independently executing
vals. Games data reads and writes occur in `source-sports`'s SQLite database.
Changing a trusted pointer changes the destination without rewriting source
dispatch code or assignments. iOS continues using the existing parent endpoint
and schema-v2 payload.

Preserve source data schemas, selection/rendering behavior, assignment IDs,
presentation, fallback teams, timestamp ordering, and browser configuration. Defer arbitrary
source creation UI, advanced bunch policies, agent authentication/ACL design,
generic SQL execution, package deployment,
and wholesale provider cleanup. Retained source-kind branches are explicitly
compatibility code, not the new routing abstraction.

## Architecture decision

For this experiment, put the small generic feed composer in the parent, next to
pointer resolution. This deliberately revises the earlier suggestion to retain a
separate composer val: parent → composer → source would add a hop and distribute
pointer/credential management before there is a need. Keep composition a pure
helper so it can move later. The parent understands display items, not sports
selection or storage.

```text
Widget → stable parent /config/resolve
           → assignments + active source-instance pointers
           → generic authenticated source client
                → source-sports /v1/read → existing Games implementation + SQLite
                → existing sibling /v1/read → Moon compatibility shim + SQLite
           → validate items, compose, attach presentation → widget schema v2

Parent Games catalog/ingest/diagnostics → same Games pointer → source-sports
```

The old sibling's `/device-feed` remains available during rollout and rollback.
No database-backed source function is imported into the parent: SQLite scope
follows the executing val, so these calls must cross HTTP.

## Minimal mapping

Reimplement parent `sources` as the deployed-source registry. Each row is a bunch-owned instance pointing to its implementing val.
Do not add a permanent binding table underneath the old singleton registry.

| Field | Meaning |
| --- | --- |
| `id` | Stable source-instance identity, independent of deployment |
| `bunch_id` | Owning bunch; FK to `bunches` |
| `name` | Human-readable instance name |
| `endpoint` | Exact HTTP endpoint returned by Val Town tooling |
| `remote_source_key` | Identity expected by the implementation/shim |
| `contract_version` | Transport contract version, initially 1 |
| `credential_ref` | Existing server credential reference, if required; never a secret value |

`device_sources` references `sources.id` and retains settings and
uniqueness per device/instance. Multiple instances of the same implementation
are allowed; there is no unique kind constraint. An instance is assignable only
to devices in its owning bunch. This basic membership invariant is part of the
model, not a new authentication/ACL system.

Migrate each existing source to an instance per bunch that uses it, preserving
device assignment IDs and settings. Seed the prototype bunch's Sports and Moon
instances and an explicit default Sports instance for the current starter-feed
behavior. Unknown-device fallback uses that explicit prototype default; it does
not infer ownership or make any future cross-bunch access promise.

Reimplement `sources` in place as the instance registry; remove its singleton
kind constraints rather than retaining a separate definitions table. Source descriptors come from implementing vals. Reusable
templates/definitions, if introduced later, are distinct from instances and are
never device assignment targets. Existing specialized browser forms can use an
explicit temporary adapter mapping without reinstating a singleton kind registry.

Resolve instance pointers once per request and pass a consistent snapshot to each
caller. Device settings cannot override destinations. Missing pointers fail
explicitly. This is a mutable prototype deployment pointer, not an immutable
release registry. Preserve existing service-to-service bearer checks and provision
what the clone needs; agent identities, grants, and ACLs are outside this pass.

Assignment priority is not part of the target model or configuration UI. Sort
combined items by timestamp ascending, with stable instance ID and source-local
item ID as deterministic tie breakers. These tie breakers express no preference.
Remove priority reads/writes/controls when migrating assignments; a legacy column
may survive temporarily only as an inert migration detail. Use the composer's
existing default eyebrow (`NEXT`) rather than deriving device metadata from an
arbitrarily first assignment; source-local eyebrow can remain in the shim only
for compatibility.

## Version-1 shim contracts

Use a common authenticated HTTP boundary with runtime request and response guards.
Source protocol version 1 is independent of widget schema version 2.

| Operation | Milestone-one behavior |
| --- | --- |
| `GET /v1/descriptor` | Returns protocol version, source key, settings schema, and supported capabilities. Games projects its existing settings/catalog; Moon exposes empty settings. |
| `POST /v1/read` | Receives source key, opaque settings, and explicit request context (timezone offset seconds); returns source key, protocol version, and existing display items, with optional existing eyebrow text. |
| `POST /v1/write` | Receives source key, operation name, and payload. Dispatches only advertised existing ingest operations through a local adapter. Unknown operations are rejected. |

Read responses preserve `id`, `mainText`, `subText`, `caption`, `emphasized`, and
Unix-second `timestamp`. This is the existing widget JSON main/sub/time shape:
the literal wire keys are `mainText` and `subText`, not `main` and `sub`.
Every item represents a time-based event; timestamp is required and meaningful.
Undated information and non-temporal abstractions are out of scope. Source responses do not own device presentation. Validate
every item at the parent boundary, including finite timestamps and nullable caption.
Do not send install IDs, pairing information, presentation, or a full device URL
to source vals. The shim can reconstruct any legacy Request locally.

For writes, advertise only the existing Games cache ingest and Sleeper refresh
operations needed by current callers, with explicit per-operation validation.
Preserve their existing result bodies inside a versioned result envelope. This
is a common transport, not a claim that ingestion payloads are domain-independent.
Keep read-only catalog, coverage, and cached-FIBA compatibility adapters working
against the same pointer. Moon cache ingest remains on the Moon binding.

Describe future package validation/publication as unsupported capabilities.
If a stub route is needed by a contract fixture, it returns an explicit
`not_implemented` error and makes no changes; it must never report successful
publication. No SQL endpoint or pretend validator is introduced.

## Implementation sequence

1. **Record the baseline.** Inspect the exact remaining caller modules and current
   source IDs. Capture synthetic Games, Moon, mixed-source, and source-less-device
   fixtures. Inventory Games catalog, Sleeper, FIBA, and source-cache callers so
   both reads and writes move together. Check interval runners before remixing.
2. **Remix the provider.** Use `val_town_remix_val` with source
   `plusjade/sports-today-device-feed`, name `source-sports`, `privacy: public`,
   and `copyDatabase: true`. The tool supports copying the full database for an
   owned val; its default copies schema only. Confirm returned ownership, app
   access, and exact endpoint. Do not assume secret values copied: the documented
   remix copies environment keys. Provision the new RPC credential securely.
   Prevent duplicate scheduled ingestion if the remix includes interval files.
3. **Verify independent storage.** Compare bounded counts/coverage for
   `cached_games`, `catalog_competitions`, `catalog_teams`, and relevant
   `source_cache` data. Exercise a disposable cache record through the new val
   and confirm it does not appear in the old database. Remove the fixture.
   Recoverable data does not require a source-table redesign.
4. **Add source shims.** Wrap the existing Games implementation in the new val and
   Moon in the existing sibling. Preserve their renderers and data models. Reject
   unrelated source keys at the new Games boundary. Keep copied unused modules
   dormant instead of turning this into a cleanup project. Public code/app access
   does not remove application-level bearer checks, particularly on writes.
5. **Migrate parent source instances and add generic composition.** Replace
   singleton references with bunch-owned instance references, preserving assignment
   IDs/settings and validating device/instance bunch membership. Update the read
   projection to carry instance identity and its pointer. Add a generic source
   client and a pure composer. Namespace item IDs using stable parent source ID
   plus source-local ID, independent of destination/revision. Preserve timestamp
   sorting with instance/item-ID tie breaking, default eyebrow `NEXT`, `no-store`,
   default presentation, and fallback teams. Keep the current whole-feed failure
   policy, adding bounded request timeouts and source-specific errors; partial
   feeds are a separate product change.
6. **Route all Games access through the binding.** Keep existing public ingest
   URLs and browser forms. Their compatibility helpers resolve the Games pointer
   for catalog, writes, coverage, and FIBA reads. Explicitly map existing ingest
   identifiers to the appropriate source at the legacy edge. Do not leave live
   writers updating the original database after switching feed reads.
7. **Verify, then activate.** Test branch/candidate routes and disposable fixtures
   before switching active traffic. Use one implementation branch per existing
   val and merge each once; Val Town branches are not assumed to isolate SQLite.
   Stage and verify the instance migration before retiring singleton references.
   Remove assignment priority controls and behavior; keep assignments intact.
   Activate Games → new val and Moon → old val after shims are live. Verify the
   stable parent route and device preview. Update `docs/valtown-brief.md` with the
   actual resulting identifiers, contracts, and temporary seams.

Likely parent changes: `lib/deviceFeedClient.ts`, `lib/deviceSourceStore.ts`,
`lib/resolver.ts`, new instance/client/composition helpers, source/device stores and admin views,
   and targeted route callers. Provider changes: `rpc.ts` plus focused contract adapters. Inspect exact
route filenames before editing. Preserve the parent's `main.ts` file identity.

## Acceptance and rollback

- A real mixed-source response demonstrates Games from the new val and Moon from
  the old val, with unchanged visible content and presentation. Item IDs have only
  the documented stable namespace change.
- Generic client/composer tests use a third fake source key without adding a
  dispatch branch. Verify two instances can use the same implementation without
  a unique-kind constraint, and reject a cross-bunch device assignment. Generic
  descriptor-driven form rendering remains deferred.
- Guards reject malformed items, protocol/source mismatches, invalid settings,
  unsupported writes, and unauthenticated calls. Timeout behavior is tested.
- Existing ingest, catalog, and diagnostics all follow the Games pointer.
  A disposable write proves database isolation. Unsupported publication never
  mutates data or reports success.
- A binding switch to a compatible test destination and back needs no dispatch
  code change. Record the prior bindings for production rollback.
- Verify deterministic equal-timestamp ties independent of assignment order or
  legacy priority. Preserve Games/Moon selection, default feed behavior,
  and the schema-v2 Swift decoding contract. Run provider contract tests and the
  relevant iOS build/decoding checks; leave iOS source unchanged unless drift is
  discovered. Preserve the stable HTTP file ID/base URL.

Before activation, rollback means leaving pointers unchanged. After activation,
switch back only to a contract-compatible endpoint. The old sibling needs a Games
shim as well if it is to be a pointer-only Games rollback target; add that small
adapter during step 4. Reconcile any post-cutover Games writes before rollback:
a copied database is a snapshot, not an automatically synchronized replica.

This milestone is complete when the routing boundary works end to end. It does
not claim generic admin forms, immutable live releases, agent SQL isolation, or
deterministic package publication are already implemented.
