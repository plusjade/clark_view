# Changelog

Record of significant decisions and *why* they were made. Entries describe decisions
at the time; verify current behavior against the owning code, live diagnostics when
relevant, and orientation docs in `docs/`.
Newest entries on top. Use one concise, dated entry: what + why, with an optional
pointer. Preserve historical meaning; record reversals as new entries. Typo and
broken-link corrections are allowed. See [AGENTS.md](../AGENTS.md#documenting-decisions)
for routing current guidance, operational evidence, and routine validation.

## 2026-09-10

- Replaced the item's single `timestamp` with a required `startsAt`/`expiresAt`
  window (widget schema 3, SDK snapshot 12) so lifecycle is derived from the clock
  instead of a stored status that only moves when someone ingests. `expiresAt` is a
  source-owned estimate and is never displayed; the widget uses it only to schedule
  its next refresh on the next bound. An instantaneous event publishes a one-second
  window rather than a null, because a nullable expiry fails silently in both JS
  (`now > null`) and SQL (`expires_at > :now`). The name is `expiresAt`, not
  `endsAt`, because the two bounds are not symmetric in use — only the start is
  rendered — and "expires" carries the approximation the field actually has.
- Kept caption authorship in the sources rather than moving it to the parent: the
  staleness the window fixes came from reading an ingest-frozen status, not from
  where the caption is computed, and a source deriving it from `phase()` at read
  time is equally fresh while keeping domain vocabulary out of a parent that has no
  games model. A stored `final` still outranks the estimated expiry.
- Added a rectangular Lock Screen proof of concept using the existing widget identity
  and provider, plus Beacon's shared date/status view, to keep layout iteration local
  without introducing another feed or refresh path. See [iteration guide](lock-screen-widget.md).
- Added scoped operational evidence and preserved verification pointers in documentation
  routing because removing provenance can make temporary observations look permanent.
- Consolidated current guidance and introduced decision routing because completed
  migration narratives were being mistaken for current system behavior.
