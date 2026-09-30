# Managed sources

Agent-published Clark View sources: an agent creates a source from findings it
already has, then publishes events and shared editorial intent over HTTP. Public
prototype through phase 3 of [managed-source-plan.md](managed-source-plan.md); the
contract rationale is in [managed-source-design.md](managed-source-design.md).
Deployed 2026-09-30.

**Public by design.** Anyone with a source's management URL can read and change it.
There is no authentication until phase 4.

## Deployment identities

| Val | Role | HTTP entry (`main.ts` → `links.endpoint`) |
| --- | --- | --- |
| `plusjade/managed-sources` | Provisioner: guide at `GET /`, `POST /managed-sources` | `https://plusjade--0ebfae8abd2511f1b3b91607ee4eb77e.web.val.run` |
| `plusjade/managed-source-template` | Runtime template; remixed into slots | `https://plusjade--9c61c210bd2411f1a0711607ee4eb77e.web.val.run` |
| `plusjade/managed-source-01` … `05` | Pool slots, keys `managed-01` … `managed-05` | Read from each val's `list_files` |
| `plusjade/managed-source-test` | Disposable slot for API and agent tests; not in the pool | Read from `list_files` |

Each val owns its own README, `AGENTS.md`, and checks (`tools/check.ts` in the
template and slots). Read those before changing code; they own the operating
procedures. Slots are independent remixes, so a runtime change ships to each slot.

## Ownership

- Slot runtime: canonical `GET /` (unchanged `get-no-settings` contract) plus
  `/manage/v1/state`, `/reconcile`, `/history`, `/initialize`.
- Provisioner: slot allocation, replay of creation, the human-facing destination.
  It holds no parent authority and no Val Town credentials, and never deploys vals.
- Parent: registration, conformance, and feed attachment stay manual operator
  actions ([get-sources](https://www.val.town/x/plusjade/app-clarkview/code/docs/get-sources.md)).
  No parent code knows about managed sources.
- External agent hosts: research and scheduling.

## Path from creation to a widget

1. Agent creates the source; the response's `destination.nextStep` names the slot and endpoint.
2. Operator registers the slot in the parent (get-sources runbook), then records the
   parent ID in the provisioner: `UPDATE pool SET parent_source_id = ? WHERE slot = ?`.
3. Operator attaches the source to a feed at `/feeds/:id/manage`.
4. The steerer's widget shows that feed; items appear after its next timeline reload.

Until step 2, `destination.integration` is `not_in_a_feed`. The provisioner never
claims attachment.

## Agent prompts

Bootstrap:

> Add Clark View as a destination for these findings using
> https://plusjade--0ebfae8abd2511f1b3b91607ee4eb77e.web.val.run/managed-sources (read its
> guide at the same host's root). Reuse this conversation's research and preferences.
> Create the source and publish the usable events. [If recurring: update this existing
> task to maintain that destination on future runs.] Return the destination and say
> what was actually published and configured.

Existing source:

> Use &lt;manageUrl&gt; to read this source and [requested change]. Preserve event IDs.
> Treat its shared preferences as defaults that my request can revise; publish updated
> preferences and affected events together when appropriate.

## Status (observed 2026-09-30)

- Pool: slots 01–05 available, none registered in the parent. Recheck with
  `SELECT slot, state, parent_source_id FROM pool` on `plusjade/managed-sources`.
- Remix does not copy the database schema; every new slot needs `setup.ts` before
  verification.
- Unverified: the provisioner's `pending` path (slot timeout/5xx), a slot at its
  1000-event limit, and paging beyond 100 events. Close when exercised in phase 3 or
  covered by a scripted run.
- Slot `initialize` is public; a squatted slot is marked `foreign` and skipped.
  Closes with phase 4 provisioning authority.
