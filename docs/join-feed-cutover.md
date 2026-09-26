# Join feed cutover recovery record

Observed 2026-09-26. The parent Val Town database is shared by branches. Before
dropping any columns or bunch tables, a transactional snapshot was written to
`_join_feed_backup_20260926_schema` and ten
`_join_feed_backup_20260926_<table>` tables for bunches, bunch codes, devices,
sources, feeds, feed assignments, subscriptions, the reminder queue, device feed
requests, and widget inventory. These
tables are in `plusjade/app-clarkview`'s val-scoped SQLite database. They include
installation identifiers and codes; inspect them only with narrow, private SQL.
The original schema SQL is in the schema snapshot.

## Recovery if the cutover fails

1. Stop the parent reminder builder and drainer intervals. Keep APNs sending off.
2. Restore the parent code from pre-cutover `main` version 431. Do not run it yet.
3. In the val-scoped database, recreate `bunches` and `bunch_codes` from the
   captured schema SQL and insert the snapshot rows. Add `bunch_id` back to
   `devices` and `sources` with the captured foreign-key references, then fill
   values from the matching backup rows. New device rows may remain NULL. Restore
   indexes from the captured schema. The recovered `sources.bunch_id` constraint
   may be nullable until a maintenance rebuild; all captured source values are
   restored. Do not drop or rebuild `sources`, because `feeds_sources` has a
   cascading source foreign key.
4. Add `device_subscriptions.reminder_lead_seconds` back with the original
   0–129600 check and a default of 3600. Fill captured rows from the backup;
   initialize any new rows from their feed's current shared lead. Drop the new
   feed-timing trigger and restore the original subscription triggers from the
   schema snapshot. Keep the queue and its terminal rows intact.
5. Compare row counts and both-direction value differences for the preserved
   columns, assignments, subscription booleans, tokens, and terminal queue rows.
   Only then resume the old code and intervals. A code rollback alone is not a
   schema rollback.

The first atomic `DROP COLUMN` attempt was rolled back: this libSQL version
rejected dropping `devices.bunch_id` while its table foreign key still named
the column. The final cutover rebuilt `devices` and `sources` in one transaction,
restored every affected child row from the snapshot, and then recreated the
subscription triggers. Both-direction comparisons found zero differences for
device identity, source fields, feeds, assignments, subscription booleans,
device feed requests, and widget inventory. All child references resolved,
and terminal reminder rows remained unchanged.

The snapshot is retained until the joined-feed flow and reminder timing pass
manual acceptance and no rollback is needed. Recheck then and remove the backup
tables in a separate, reviewed cleanup.

## Acceptance status (2026-09-26)

Parent `tools/check.ts` passed after the cutover. A disposable in-process smoke
passed browse, preview, join off, toggle, leave, and a `send:false` drain; its
script and rows were removed. The iPhone 17 simulator `xcodebuild test` scheme
passed, as did SwiftLint with existing warnings only. Physical APNs delivery,
OS-denied guidance, two-device timing propagation, and upgrade/widget persistence
remain manual acceptance items in [join-feed-project-plan.md](join-feed-project-plan.md).
Close this status after those scenarios are reported and the backup cleanup
decision is made. These checks do not prove a notification appeared on a device.
