# Changelog

Append-only record of *why* decisions were made. Never a statement of current
behavior — for that, verify against the code or the orientation docs in `docs/`.
Newest entries on top. One line per entry: what (one clause) + why (one clause) +
an optional pointer. Never edit a past entry; if a decision is later reversed, add a
new entry instead. See AGENTS.md for when something belongs here versus in an
orientation doc versus only in the commit message.

## 2026-09-10

- Removed `docs/catalog-model.md`, `docs/catalog-schema.sql`,
  `docs/source-val-migration.sql`, and `docs/val-based-sources-plan.md`; rewrote
  `docs/valtown-brief.md` and `docs/push-notifications.md` around durable rules
  instead of dated narrative. Why: orientation docs were accreting verification
  play-by-plays and completed-migration logs because there was nowhere else to put
  them, producing stale-but-still-trusted claims; that content now belongs here
  (if it carries a reusable rationale) or nowhere (if it was pure verification
  chatter with no forward relevance — that already lives in commit history).
