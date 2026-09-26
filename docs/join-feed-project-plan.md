# Join feed and retire bunches

Implementation handoff · 2026-09-26 · Implemented on parent `main` and in this
repository. Manual acceptance remains open; current contracts are in
`docs/valtown-brief.md`, `docs/ios-widget.md`, and parent `docs/subscriptions.md`.

## Product objective

Test this proposition: **You keep this experience useful; I choose to keep receiving it.**

Make joining a public feed the core receiver flow. A feed packages its sources,
presentation, and shared reminder timing. A device joins and independently turns
reminders on or off. Remove bunch enrollment and pairing from the product and
underlying system.

## Scope and constraints

- All feeds and current source data remain public. Joining organizes the receiver's
  experience; it does not confer read access or promise privacy.
- Keep device-based subscriptions. No accounts, authentication project, ACL roles,
  ownership model, private content, delegation, invitation codes, or token redemption.
- Keep browser-managed feed curation. This is not a new native feed editor.
- One shared notification lead time per feed; one reminder boolean per subscription.
  No custom recipient rules, multiple reminder rules, or live activities.
- Preserve public feed discovery and reading. Widget selection stays independent of
  joining and reminder activation.
- Use “Join feed,” “Your feeds,” “Reminders,” and “Leave feed” in receiver-facing UI.
  Existing subscription table, route, and type names may remain where renaming adds
  churn without changing meaning.
- Ordinary feed links suffice; a new universal-link/deep-link infrastructure project
  is not required. Preserve existing link behavior and document any remaining gap.

## Read first and establish live state

Read AGENTS.md, docs/valtown-brief.md, and docs/testing.md. For server work, follow
the brief's parent-task routing and inspect only implicated parent modules. The
server lives in Val Town plusjade/app-clarkview; local documentation is an orientation
snapshot, not proof of current deployed state.

Before edits, inspect repository changes and actual parent schema/routes. Record a
bounded inventory of bunch dependencies, current subscription lead values, and old
client compatibility needs. Do not read checks unless they fail. Do not expose
installation identifiers, push tokens, or codes in the handoff.

## Intended receiver experience

1. Home shows “Your feeds,” including joined feeds with reminders off. An empty state
   explains the value briefly and offers “Join feed.” Remove pairing entry points.
2. Browse the existing public directory and preview a feed before joining. Reuse the
   existing feed preview. Show shared reminder timing in plain language.
3. Join with an explicit Reminders switch, default off for new joins. Explain that
   timing is maintained with the feed and can change. Do not add a timing editor.
4. After joining, show the feed preview, current shared timing, reminder switch, and
   Leave feed action. Joining does not automatically place/configure a widget.
5. Turning reminders off keeps the feed in Your feeds. Leaving removes only this
   device's subscription; it never deletes the feed or modifies other recipients.

Keep notification authorization distinct from the stored preference. If reminders
are enabled but OS permission is unavailable, show accurate existing delivery
guidance; do not claim successful delivery or silently rewrite the user's preference.
Preserve retry, loading, empty, and error behavior. Duplicate joins must not create
duplicate subscriptions. Leaving should use consistent confirmation across entry
points, and should explain that an independently selected widget is not removed.

## Data and API changes

Retain devices, independent feeds, sources, feed assignments, device subscriptions,
tokens, reminder ledger/queue, and device diagnostics.

- Add feeds.reminder_lead_seconds: a required nonnegative integer, using the existing
  supported lead-time bounds/choices. Zero means at event start.
- Keep device_subscriptions.enabled with the precise meaning “reminders enabled.”
  Row existence means joined. Preserve UNIQUE(device_id, feed_id).
- Remove device_subscriptions.reminder_lead_seconds after migration/cutover.
- Subscription create/update accepts the device's boolean, not a device-specific
  lead. Shared timing is editable only through existing feed configuration paths.
- Return the current shared timing to receiver UI. Existing reminderLeadSeconds
  response naming may remain as a derived feed value to minimize wire churn; document
  its ownership. Ensure the pre-join preview can also obtain it without creating a
  subscription. Do not change widget payload semantics just to expose this metadata.
- Move browser timing controls from device subscription forms into feed management.
  Apply the same semantics to native and browser join/edit/leave flows.

### Migration policy

Preserve device/feed/source IDs, assignments and enabled states, subscriptions and
their booleans, presentation, tokens, frozen legacy feed mappings, and terminal
delivery history. Do not auto-join devices or turn existing reminders on/off.

For each existing feed: use the existing subscription lead if all subscriptions agree;
if none exist, use the current native creation default (observed as one hour; verify).
If leads conflict, report the affected feeds and choices before selecting a shared
value. Do not silently choose a minimum, maximum, or most common value. Other work
can proceed while that concrete migration decision is resolved.

Make migration rerunnable without resetting curated feed settings. Verify preservation
using a scoped snapshot/count/value comparison. Migration/cutover checks are disposable:
run them, record results in the commit/handoff, and remove their scripts.

### Reminder scheduling

Builder uses shared feed timing only for enabled subscriptions. Drainer rechecks
current subscription existence/enabled state and applicable timing before delivery.
Off or leave must prevent queued sends. A timing edit must invalidate/recompute stale
pending work without replaying terminal deliveries. Inspect the existing deduplication
contract (including overlap across feeds) before changing it; preserve it unless a
necessary contract change is explicitly documented. Do not reset the ledger.

## Deprecate and remove bunches

Treat this as actual retirement, not just hiding the menu.

- iOS: remove PairingView, PairingClient, paired-state storage/read paths, pairing
  sheets/menu actions, and the Paired diagnostic. Registration remains independent
  and idempotent. Remove stale pairing language from current comments and UI.
- Widget inventory: preserve the purpose of retry/report-after-registration behavior
  when removing pairing-triggered code. Replace it with the appropriate registration
  event if needed; do not mechanically delete the retry path.
- Parent: remove bunch pages, code issuance, enrollment behavior, bunch stores, route
  wiring, navigation/gallery references, and schema initialization that recreates them.
- Remove devices.bunch_id and sources.bunch_id dependencies. The source registry becomes
  system-wide for this prototype. Preserve all source IDs, assignments, pointers, and
  conformance metadata. Inspect indexes, foreign keys, triggers, and seeds as well as
  application references.
- Drop bunch_codes and bunches after dependent relationships are removed. Do not retain
  an inert bunch_id column as the final design merely to avoid planning the migration.
- Do not rebuild sources casually: the brief documents cascading assignment loss on
  table drops. Choose and verify a data-preserving schema strategy against actual
  SQLite capabilities and foreign-key behavior before applying it to shared state.

Separate concept retirement from old-client compatibility. Inspect consumers of
/pair, /devices/register, status paired fields, and unrelated legacy resolver routes.
Use an explicit coordinated cutover or a minimal temporary compatibility response
where required; never report a successful pairing that no longer occurs. Any temporary
route/field must be independent of bunch storage and have a documented removal
condition. Do not delete unrelated legacy resolver mappings in this project.

## Execution order

1. Establish live dependencies, migration values, and a bounded compatibility strategy.
2. Implement parent shared timing, APIs/browser controls, and reminder behavior on a
   parent branch. Stage schema changes so the currently installed client cannot write
   per-device timing back into the new shared policy.
3. Implement native Join feed flow and remove pairing dependencies.
4. Verify data preservation and complete bunch/schema retirement at the coordinated
   cutover. Val Town code branches share SQLite: a branch is not migration isolation.
5. Run required checks and one representative runtime smoke, update docs, then hand off.

Before an irreversible schema change, establish a recoverable data snapshot and a
specific recovery procedure. A code rollback alone cannot restore dropped columns.
Do not use live enrollments or notifications as casual migration smoke tests.

## Verification and acceptance

Follow AGENTS.md: parent tools/check.ts, xcodebuild test for iOS changes, and swiftlint
lint. Use an available simulator destination as needed and report it. Read only failing
checks; edit checks only where the asserted contract intentionally changes. Extend an
existing owning check only for a lasting seam; do not create a test per UI change.

Exercise changed deployed routes, not just the parent root. Use scoped disposable
fixtures and disabled-send verification for server delivery work; clean up fixtures.
Verify one representative runtime flow: browse, preview shared timing, join, toggle
reminders off, and confirm the feed remains joined. Keep broader acceptance manual.

Manual acceptance plan to include in the implementation handoff:

| Setup | Actions | Expected result |
| --- | --- | --- |
| Fresh install, public feed | Launch, browse, preview, join with reminders off | No pairing; feed appears in Your feeds; shared timing visible; no queued delivery |
| Two devices joined to a disposable feed | Enable reminders; change shared timing in browser | Both see new timing; no recipient timing editor; pending work follows the new plan |
| Joined device with pending reminder | Turn off, then separately test leaving | Off preserves join; both actions prevent pending sends; other device unaffected |
| Existing device with an independently selected widget | Leave its feed | Feed stays publicly readable; widget selection remains; no subscription reminders |
| Upgrade with existing subscriptions/source assignments | Install updated app and inspect migrated state | IDs/content/booleans preserved; shared timing matches migration decision; no pairing UI |
| Physical device with appropriate signing/APNs setup | Enable reminders and grant permission; observe a scheduled event | Actual notification arrives according to shared timing; server acceptance alone is not proof |
| Notifications denied | Join and enable reminders | Preference is retained; UI accurately explains blocked OS delivery |

Separate passed, failed, blocked, and unrun results. Do not claim manual acceptance
unless performed. Follow docs/testing.md limits; do not expand into a device matrix.

## Documentation and final handoff

Update current orientation/contracts in docs/valtown-brief.md and relevant parent
docs in place. Record the product boundary and bunch retirement rationale in one
dated docs/CHANGELOG.md entry. Preserve historical entries; distinguish them from
current instructions. Document any temporary compatibility state with its closure
condition. Mark this plan completed or superseded once implementation is handed off.

Provide changed local files and parent branch/version, migration and preservation
results, removed concepts/routes/tables, any temporary compatibility remnants,
verification results, and the executable manual plan. Highlight unresolved migration
choices or runtime blockers. The requesting agent will review the completed work;
do not treat implementation completion as review approval.
