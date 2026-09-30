# Managed sources: product orientation and execution plan

Status: agreed product direction; implementation contract proposed. Updated
2026-09-30. This document replaces the earlier authentication-first plan. It does
not describe deployed functionality or authorize deployment by itself. An external
implementation agent should begin at phase 1 and stop at each phase checkpoint.
Phase 1 design, awaiting review: [managed-source-design.md](managed-source-design.md).

## Product lens

**The agent owns the workflow. Clark View owns publication state. Shared intent
provides continuity, and the API makes changing that intent inexpensive.**

Treat the agent and its human steerer as first-class users:

- The steerer has an already useful research session or scheduled task and wants
  its findings in a native iOS experience. They should not have to design a feed,
  repeat their preferences, or restart their research to add this destination.
- The agent brings its own research tools, reasoning process, scheduling
  primitives, and output conventions. Clark View adds a lightweight publication
  contract, not a prescribed research workflow.

Optimize for one person steering one agent on a focused source. Events are useful
around their occurrence; the source may outlive several seasons, but its history
should not burden every interaction. Other agents must be able to take over from
an endpoint without reconstructing the original conversation.

The principal product risk is friction: excessive turns, repeated discovery,
confusing errors, slow publication, or wording that ignores the steerer. Reliable
writes support that experience; elaborate collaboration machinery is not a first
deliverable.

### Three kinds of source context

| Context | Authority and purpose |
| --- | --- |
| Mechanical contract | Required event fields, stable identity, revision and write semantics; enforced by the service |
| Shared editorial intent | A short editable purpose and preferences, such as “Fever first; broadcast in subtext”; defaults until the steerer changes them |
| Current state | Relevant events, IDs, and revision; avoids accidental duplication or reversal |

Do not store prescriptions for research tools, search counts, reasoning methods,
or host scheduling APIs. Do not accumulate a conversation transcript as editorial
intent. Current user direction may revise prior preferences and affected events
in one publication. The agent interprets intent; the server enforces mechanics.
Natural-language intent is not a deterministic rendering guarantee.

## First deliverables

1. **Bootstrap:** add Clark View as a destination for existing findings, creating
   a managed source and publishing its initial events through one logical request.
2. **Curate:** given an endpoint, understand and update a source with one compact
   read and one publication in the ordinary case, including changes to intent.
3. **Public UAT:** exercise those journeys in real agent environments and a shared
   Clark View feed/widget before implementing authentication.
4. **Access control after UAT:** add per-source grants and pairing without changing
   the editorial workflow, then revalidate authenticated unattended use.

Each source has its own val runtime and val-scoped storage. Managed describes its
code-free authoring interface; existing computed, static, and upstream-ingesting
sources remain valid. Canonical source reads and widget payloads stay unchanged.
The parent composer needs no managed-source dispatch or domain policy.

Embedded chat, MCP adapters, arbitrary code authoring/deployment, deterministic
formatting engines, account recovery/onboarding, and complex collaboration UI are
outside these deliverables. Automatic parent registration/attachment is a phase 1
scope decision, not an implicit consequence of source creation.

## Journey A: bootstrap from useful work

Example request: “Send these boxing findings to Clark View, and keep it updated
when this task runs.”

1. Reuse the session's findings, preferences, and research scope. Do not restart
   research or require a source-specification interview.
2. Send a name, concise purpose/editorial intent, initial publishable events, and
   request ID to a Clark View creation operation. An empty initial set is allowed
   when there are no publishable findings; missing times must not be invented.
3. Receive a stable source identity, management endpoint, publication receipt,
   and a human-facing destination with truthful integration status and next step.
4. Using the host's own tools, add the destination to the existing recurring task
   if requested and supported. Do not silently create a second schedule.
5. Report what was published and whether recurring publication was actually
   configured. Ask only about information materially blocking the intended result;
   publish the usable subset and identify unresolved findings when appropriate.

Source creation must be a Clark View operation; end-user agents do not need Val
Town account access. An operator-provisioned empty val or bounded pool may back
that operation. An operator-assisted step is acceptable in the spike, but a
human manually creating every requested source does not complete bootstrap UAT.
A pool must fail clearly when exhausted, not fall back to unbounded deployment.

One request is a UX target, not a distributed-transaction claim. Prefer a prepared
runtime for the prototype. If provisioning is asynchronous, return a stable
operation receipt and explicit pending/failed/ready state. Retrying creation must
never allocate another source or republish duplicate initial events. A failed
initial publication must not appear as a ready, successfully populated source.

The source and feed remain distinct: provisioning a val is not parent verification,
registration, attachment, app subscription, or widget selection. Phase 1 must
choose and document the shortest human path from the returned destination to a
usable feed, keeping authority for those operations in the parent.

## Journey B: curate from an endpoint

Example request: “Make Fever appear first: Fever at the opponent when away, Fever
vs the opponent when home.”

1. Read one compact management response: identity, purpose/preferences, relevant
   events with IDs, revision, and concise operation/schema guidance.
2. Submit one batch containing the updated preference and affected events.
3. Trust the durable publication receipt and report completion. No mandatory
   verification GET, separate settings transaction, or repeated approval for an
   ordinary edit within the steerer's granted scope.

A source is collaboratively maintained. Any actor with write permission may
change it, affecting every feed using it and everyone subscribed to those feeds.
Explain that shared impact when establishing context. Do not automatically fork
personal variants. Subscription alone does not grant write authority once access
control exists; during the public prototype everyone effectively has it.

Current user direction can intentionally change established wording. Existing
content is context, not a veto. Publish editorial intent and event changes
atomically so later runs see a coherent update. Intent alone does not rewrite
stored events; an agent includes affected event updates in the same batch.

## Minimal interface and publication semantics

Exact names and schemas are phase 1 deliverables, not frozen by these sketches.
Version management independently of canonical GET.

| Operation | Proposed interface | Required experience |
| --- | --- | --- |
| Learn bootstrap | Public creation guide/schema | Short, reusable instructions independent of agent host |
| Create and publish | POST /managed-sources | One idempotent logical operation; bounded provisioning |
| Learn/inspect a source | GET /manage/v1/state | Compact state plus enough inline guidance to publish |
| Publish | POST /manage/v1/reconcile | Events and optional editorial intent in one atomic batch |
| Inspect older state/history | Explicit optional query or linked route | No history tour required for routine curation |

The creation operation belongs to a trusted provisioning service; per-source
management belongs to that source runtime. Phase 1 chooses their actual locations.
A concise standalone guide/schema may also exist, but agents must not fetch a
chain of documentation pages before an ordinary update. Schemas and guidance
must agree with the actual deployed API.

Illustrative publication shape:

```json
{
  "requestId": "unique-publication-id",
  "baseRevision": 12,
  "intent": "Major upcoming boxing matches; broadcast details in subtext.",
  "upserts": [
    {
      "id": "stable-event-id",
      "mainText": "Fighter A vs Fighter B",
      "subText": "Broadcast information",
      "startsAt": "2027-01-01T00:00:00Z",
      "expiresAt": "2027-01-01T03:00:00Z"
    }
  ],
  "removals": []
}
```

- Prefer timezone-qualified ISO input at the management boundary; normalize to
  canonical Unix seconds internally. Freeze accepted forms in phase 1, rejecting
  ambiguous local times. Reuse canonical validation after normalization; this
  convenience must not change source or widget wire semantics.
- Intent is optional; omitted means unchanged. Upserts replace complete individual
  events, not the whole source. Omitted events survive. Removals are explicit IDs;
  removing an absent event is a no-op. Reject duplicate or overlapping IDs.
- Preserve IDs through wording changes and rescheduling. Use stable upstream IDs
  where available; otherwise choose a persistent source-local ID. Return IDs next
  to recognizable text/times. Do not derive identity from mutable titles/times.
  Retry idempotency is not semantic deduplication; do not add fuzzy matching yet.
- Validate the whole request and return all actionable field errors together,
  with accepted examples. Commit events, intent, revision, and receipt atomically.
  Invalid requests change nothing. Set finite, documented payload/event limits.
- One source revision covers events and intent. Stale base revisions conflict;
  do not silently overwrite concurrent changes. No-op publications succeed
  without advancing the revision or generating editorial change-history noise.
- Successful request ID replays with the same payload return the original receipt
  before checking the now-stale base revision. Different payload reuse conflicts.
  Retain receipts for the prototype lifetime; no cleanup subsystem is needed yet.
- Return request ID, revision, and created/updated/removed/unchanged IDs. A receipt
  proves durable publication, not research accuracy, feed integration, or widget
  refresh. The agent need not fetch again to prove the same commit happened.
- Keep a recoverable prior publication/change record for public UAT, with enough
  data for operator recovery. Do not build a merge UI or approval queue.
- Default management reads emphasize current/upcoming events. Identify the scope,
  truncation, and continuation explicitly; older data remains accessible on demand.
  Never mistake a scoped read for the full dataset or infer deletion from omission.
- Choose a simple explicit serving/retention policy in phase 1. Management view
  filtering and public source selection are distinct. Do not silently discard
  stored events or accumulate unbounded default response payloads.
- Unknown start times remain unpublished; an estimated duration may follow shared
  intent. Cancellation initially removes the item; introduce no lifecycle vocabulary.
  Evidence links may be optional management metadata, not a publication ceremony.
  Do not fetch arbitrary supplied links during reconciliation.

Canonical GET / remains mutation-free and follows its existing query validation
and {sourceKey, items} schema. No intent, receipts, history, pairing data, or other
management-only fields enter widget items. Provision schema outside feed reads.

### Recovery should cost as few turns as possible

| Outcome | Response and recovery |
| --- | --- |
| 400/422 validation | All useful field errors and examples; agent repairs with a new request ID |
| 409 stale revision | Current revision and compact updated context where practical; agent re-evaluates and republishes with a new ID |
| 409 request ID reuse | Explain payload mismatch; do not imply the original request failed |
| 429 | Retry-After and bounded backoff |
| Timeout/network/5xx | Retry identical request and ID; a missing response does not mean no commit |
| 401/403, after access control | Explain pairing/permission next step; never suggest bypassing enforcement |

Choose a small retry budget. After it is exhausted, report the blocker and preserve
existing data. No new research findings is a no-op, not a clear-source request.
Do not respond to API errors by requesting Val Town credentials or editing code.
Errors must not leak stack traces or, later, secrets and unauthorized source data.

## Agent guidance package

Deliver two short, copyable entry prompts and matching endpoint guidance. They
teach publication, not research. Adapt to the host rather than requiring specific
skills, plugins, models, tools, or scheduling terminology.

**Bootstrap prompt template**

> Add Clark View as a destination for these findings using [creation endpoint].
> Reuse this conversation's research and preferences. Create the source and publish
> the usable events. [If recurring: update this existing task to maintain that
> destination on future runs.] Return the destination and say what was actually
> published and configured.

**Existing-source prompt template**

> Use [management endpoint] to read this source and [requested change]. Preserve
> event IDs. Treat its shared preferences as defaults that my request can revise;
> publish updated preferences and affected events together when appropriate.

Endpoint guidance should explain request/response/recovery semantics, shared
impact, and the distinction between publication and delivery. It should allow an
agent to immediately report missing HTTP or scheduling capability without claiming
success. A script test is not evidence that an actual agent host supports writes.
Once authentication exists, add pairing and secret-storage guidance without
rewriting these journeys.

## Ownership, public prototype, and later authentication

Sources own content, event windows, intent, and storage. The parent owns registry,
conformance, assignments, composition, and reminders. External hosts own their
research and execution schedules. Editing source intent cannot update a host's
schedule or provision a source cron. Device IDs remain unrelated to write authority.

Public prototyping is intentional through phase 3, including an agreed shared
feed with real public content. Clearly disclose that anyone discovering an
endpoint can read and modify its source. Do not make token work a prerequisite
for this UAT. Record actors as anonymous; supplied agent labels are unverified.

Keep one explicit authorization seam around management operations, permitting
public access during the prototype. Do not build token tables, fake identity
systems, or unused scope abstractions in advance. Public access is a deployment
policy, not a query parameter that can later bypass authentication.

Provisioning must remain bounded (for example, a prepared pool); expose no general
Val Town operations. Management clients receive no Val Town credentials. Verify
val-scoped storage, inherited environment secrets, imports, and jobs. Val branches
share storage and are not isolation for disposable tests. Source-local runtime
separation does not itself prove complete platform isolation.

After public UAT, define the smallest per-source grant system:

- Separate public resource IDs from secret authority; devices never prove ownership.
- Bootstrap source administration through an operator, then issue expiring,
  single-use invitations redeemable for revocable source-scoped bearer grants.
- Keep administration separate from ordinary publishing. Since intent and events
  form one editorial operation, prefer one write capability covering both; do not
  introduce separate editorial scopes without a demonstrated need.
- Store secret hashes; authenticate before mutations and receipt lookup. Decide
  receipt/grant scoping, lifetimes, lost-redemption recovery, and transition from
  anonymous history at the phase 4 design checkpoint.
- Close every alternate unprotected management path, including inherited writes
  and provisioning routes. Canonical reads may remain public. Authenticated writes
  do not imply private published content.

Pairing and credential persistence need their own UAT. Public unattended success
cannot prove authenticated unattended success. App/web identity mapping and
recovery are a subsequent scope decision; do not infer ownership from caller IDs.

## Execution phases and checkpoints

### Phase 1 — product journeys and smallest contract

Read AGENTS.md, docs/valtown-brief.md, and docs/testing.md. Follow targeted remote
orientation: source-template's AGENTS.md and README, then only relevant code and
contracts. Use applicable Val Town skills. Verify actual provisioning and storage
capabilities rather than treating platform assumptions as facts.

Deliver a concise reviewable design:

- Walk through both journeys with sample requests/responses and expected agent
  calls, including “Fever first” as one intent+events publication.
- Freeze schemas, timestamp normalization, IDs, limits, state scoping/retention,
  atomicity, receipts, conflicts, and one concrete error-repair example.
- Select a separate managed-source template/runtime and bounded creation mechanism.
  Specify retry-safe provisioning and empty/failed initial publication behavior.
- Define the returned human destination and exact path into a feed and widget.
  Identify any parent changes needed, without granting sources parent authority.
- Produce the two short agent guides. Show the ordinary path without prescribing
  research or adding mandatory history/diagnostic calls.

**STOP:** Review the UX examples, provisioning approach, and contract before
implementation/deployment. Authentication design is not a phase 1 dependency.

### Phase 2 — public bootstrap and curation implementation

Implement the minimal source runtime, compact state, atomic publications, replay,
recovery, and bounded creation operation. Begin with synthetic source content.
Operator-assisted setup may unblock the first spike, but report that limitation.
Use a prepared runtime/pool if it achieves bootstrap without a deployment platform.

Run source checks and external canonical conformance. Verify the API with a script,
then use real available agent environments for bootstrap and curation. Record calls,
repair attempts, user questions, and observed latency without secrets or unnecessary
conversation capture. Prefer two environments; report unavailable ones honestly.
Do not add MCP unless an observed host limitation warrants a separate decision.

Deliver working code, endpoint guidance/schema, the two prompt templates, scrubbed
examples, verification results, and a short manual UAT plan.

**STOP:** Review interaction evidence and friction. Fix demonstrated UX problems
before expanding scope. Agree on the shared feed/content for public UAT.

### Phase 3 — public end-to-end UAT: first product deliverable

Adopt an already useful research session or task. Create its source through the
Clark View operation, publish existing findings, and configure continued publication
through that host's tools where available. Follow established external verification,
registration, and attachment procedures; distinguish pending integration from success.

Exercise later curation from the endpoint, ideally with a different agent. Update
intent and current events together. Observe one actual later scheduled run and one
representative widget refresh through supported paths. No auth implementation yet.
Follow docs/testing.md; hardware/setup blockers remain explicit acceptance gaps.

**STOP:** Review UAT evidence and steerer feedback. The public product deliverable
is validated only for the journeys actually observed. Leave unmet criteria open;
public UAT does not establish permissions or authenticated unattended operation.
Proceed to phase 4 only after reviewing this experience and its remaining gaps.

### Phase 4 — grants, pairing, and authenticated UAT

First deliver a small design covering operator authority, invitation redemption,
write grants, revocation, secret storage, and closure of public management routes.
Include bootstrap/provisioning authority as well as existing-source permissions.

**DESIGN CHECKPOINT:** Review this concrete access model before implementing it.

Implement the approved design. Verify cross-source token rejection, insufficient
permissions, revocation, invitation reuse, expiry policy, and authenticated replay.
Repeat real agent pairing, publication, and a later unattended run with stored
credentials. Verify provisioning is protected or disabled; no public bypass remains.
Do not change shared edits into private variants during the access-control cutover.

**STOP:** Report authenticated acceptance separately from earlier public UAT.
Account/app integration, MCP, embedded chat, and code authoring remain later choices.

## Acceptance and implementation handoff

| Scenario | Starting state and action | Expected observation |
| --- | --- | --- |
| Reuse useful research | Existing findings; ask to add Clark View | Initial publication without restarting research or a specification interview |
| Bootstrap | Available provisioning capacity; use creation guide | One logical creation request returns one stable destination; replay creates no duplicate |
| Endpoint-only curation | Give another agent endpoint and edit request | One compact read and one write in ordinary case; no documentation tour |
| Preference change | Existing events; request “Fever first” | Intent and affected items change together; subsequent run retains preference |
| Scheduled continuation | Existing task; add source destination | Actual later run maintains same source; host scheduling limitations reported |
| Retry/error recovery | Replay request, then submit invalid fields or stale revision | No duplicate events; actionable errors aim for one repair attempt |
| Shared output | Agreed feed in a widget; publish a correction and refresh | Same feed selection shows corrected text/window after refresh |
| Authentication, phase 4 | Pair, run later, revoke, run again | Credential persists as intended; revoked writes fail without changing data |

Measure ordinary calls, extra user turns, repair attempts, and latency. The one-read/
one-write target is not a prohibition on needed pagination or conflict recovery.
Investigate observed overhead before adding abstractions. Never equate API success,
feed composition, and widget delivery, or a prompt requesting a schedule with a
confirmed recurring task. No automatic repeated approvals for ordinary authorized edits.

Checks remain black boxes until failure. Run the source's documented runner;
parent changes run tools/check.ts; iOS changes run xcodebuild test and SwiftLint.
Add coverage only for lasting contracts under AGENTS.md, not a test per edit.
Disposable cutover checks are removed after use. Docs name runners, not checks.

Every implementation handoff includes passed/failed/blocked/unrun verification and
short executable manual acceptance steps under docs/testing.md. Stop after scoped
verification; do not silently expand into a device/environment matrix. Update
orientation only for deployed contracts, record significant decisions in CHANGELOG,
and keep consequential temporary gaps dated with closure conditions. Routine passing
checks belong in commit messages. Preserve this plan as a scoped plan until those
contracts are implemented; do not present proposed APIs as current behavior.
