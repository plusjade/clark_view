# Live Activity spike

Open app Diagnostics → Live Activity Spike. Edit a title, message, status, and
optional progress; Create Record and Start first persists a standalone SQLite
record, then starts ActivityKit locally from the saved content. Send Update via
Server and End via Server persist the next snapshot and deliver it through APNs.
There is no source/event relationship, automatic schedule, or browser CRUD UI.

## Ownership and contract

- `Shared/ClarkLiveActivityAttributes.swift`: immutable `recordID` and mutable
  `{title,message,status,progress}`. Progress is a fraction or explicit null.
- `ClarkViewWidget/ClarkLiveActivity.swift`: Lock Screen and expanded, compact,
  and minimal Dynamic Island views, independent of the widget timeline.
- `clark_view/LiveActivityCoordinator.swift`: one persisted experiment per app
  install, foreground start, token/state observation, relaunch recovery, and retries.
- `clark_view/LiveActivityClient.swift`: JSON API on the existing server base URL.
- Parent `lib/liveActivityModel.ts`, `lib/liveActivityStore.ts`, and
  `http/routes/liveActivities.ts`: content validation, SQLite coordination, and API.
  Parent `lib/push.ts` owns environment-specific signing and ActivityKit delivery.

The parent table is `live_activity_spikes`. Desired state, last observed device
state, content revision, accepted revision, and delivery result are distinct.
APNs acceptance does not prove visible delivery. Terminal device observations
prevent further sends. Failed sends retain content and end intent for explicit
retry. A new experiment gets a new record; finished activities are not resurrected.

A random per-record bearer key is retained in the app's private defaults, separate
from the record ID in ActivityKit attributes. Never log the key, token, or complete
database row. Public response projections omit credentials. The spike has no
account authorization system or cross-device activity sharing.

Title/message/status limits are 80/240/24 UTF-16 units; progress is null or 0–1.
The server caps content at 2400 UTF-8 bytes. Content contains no dates, avoiding
differences between widget Unix-second decoding and ActivityKit's Codable behavior.

Parent `docs/live-activity-spike.md` owns schema provisioning, endpoint bodies,
delivery ordering, and operator procedures. The API is
`/live-activities/:id/{create,status,register,observe,update,end,deliver}`; only status
uses GET. Update/end use revision comparison to reject stale edits. Content updates
are limited to one per second to keep APNs timestamps ordered. After a conflict,
refresh the record before retrying. Direct SQLite edits do not trigger delivery;
use the parent's store functions to validate, persist, and send a snapshot.

## Trying the spike

1. Run a signed build and open Diagnostics → Live Activity Spike.
2. Create Record and Start. Confirm the local state becomes active and the push
   token becomes registered. A local start does not depend on APNs delivery.
3. Edit content and send an update. Inspect Lock Screen and Dynamic Island.
   Load Saved Content copies the server snapshot into the editor after reopening.
4. End via Server requests immediate dismissal. Retry Last Server Delivery sends
   the saved snapshot again without changing its revision. Dismiss Locally is an
   explicit cleanup fallback and does not demonstrate server delivery.

For background delivery, use the parent store function from an operational script
while the app is closed; target only the experiment's exact record. Do not commit
record keys into scripts. Push-to-start, event triggers, scheduling, automatic
delivery retries, and live source integration are outside this spike.

## Verification and deployment status — 2026-09-19

The server implementation was merged from `live-activity-spike` into parent main
snapshot 376 with explicit deployment approval. Its `tools/check.ts` passed before
merge, including mocked ActivityKit APNs transport and disposable SQLite lifecycle
fixtures. HTTP create and status on the stable main endpoint both returned 200
with the expected standalone content; the disposable record was removed afterward.
The schema is provisioned in the parent database; Val Town branches share that database.

The iOS simulator build and unit suite pass, including a complete snapshot Codable
contract check. SwiftLint reports only pre-existing warnings. Real ActivityKit
start/rendering and APNs update/end delivery are not yet verified on a device.

The app uses the stable main endpoint, which now serves the new routes. Remaining
verification is observing start/update/end on a signed device. Close this status
item after that check. Production delivery needs its own verification; sandbox
acceptance alone does not establish it.
