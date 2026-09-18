# Greenfield source template — first execution pass

Status: proposed, 2026-09-17. This is an execution plan, not a description of deployed behavior. Close or replace it with the relevant standing guidance when implemented.

## Outcome

Create `plusjade/source-template`: a working, remixable GET source that passes an external verifier hosted by `plusjade/app-clarkview`. No existing source changes. Keep the existing SDK available to its consumers.

Use `source-template` without a version suffix. It is a starting point, not a dependency or release channel. Do not introduce version negotiation until an incompatible contract actually requires it.

## Ownership

Sources serve their own endpoints and own their data. They receive no parent credentials, import no parent modules, and neither call nor access parent APIs or storage. Remixes do not register or activate themselves.

The parent calls sources, verifies responses, and owns registration, assignments, and serving eligibility. An authorized operator wires a source into the parent manually for this pass. Discovery and browser registration are deferred.

The authoring agent may use the external verification endpoint as a caller; the source runtime does not call it. The endpoint exposes only a bounded verification result, never parent internals or registry access. This is the sole authoring-facing exception to an otherwise one-way runtime boundary.

## Template

Begin with one HTTP entry, a short README, and a surgical `AGENTS.md`. Implement the parent's current canonical GET contract directly: `GET /`, optional `utcOffsetSeconds`, and `200` JSON `{sourceKey, items}` with `cache-control: no-store`.

Start with no settings. Reject unknown query parameters and malformed offsets. A fixed UTC sample needs no local-day calculation; document that omitted offset leaves its absolute times unchanged. Include one plainly labeled sample event with a stable ID and explicit valid window. An expired sample remains valid; do not generate a new event identity on every read.

Keep only code needed to serve the sample correctly, validate requests and output, and produce the contract's error responses. A local item type is useful. A generic source factory, exported helper library, legacy routes, writes, storage, ingestion, schedules, diagnostics, and settings framework are not part of this starter.

The README provides one request/response example and the exact verification invocation. Link to the short source-facing contract for exact rules; do not copy system orientation or SDK history into the remix.

## Agent guidance

`AGENTS.md` is the remix's operational entry point. Open with one sentence: “This val supplies temporal items to Clark View through an independently implemented HTTP feed.” Then give the agent only what it needs to act:

- **Edit:** name the actual HTTP file and the identity/item-producing code to change. Explain how to obtain this remix's deployed endpoint; never leave the template's endpoint as a candidate default.
- **Contract:** link directly to the concise public source contract and the README's runnable verification request. These must be accessible without reading parent implementation files or obtaining parent credentials.
- **Boundary:** work inside this val; keep GET free of mutations; the source runtime never accesses the parent. Registration and activation belong to the parent operator.
- **Verify:** invoke the external checker with this remix's endpoint and source key, repair the reported failures, and rerun after the final deployed edit. Include the exact tool or command needed, directly or through the README pointer; “run conformance” is insufficient.
- **Finish:** report the endpoint, source key, and final verification result for operator handoff. A verification pass does not mean the source is registered or activated.

Write these instructions against the implemented files and deployed verifier, with no unresolved placeholders. Keep one owner for each detail: executable verification instructions in the README, wire rules in the source contract, work instructions in `AGENTS.md`. Do not require reading every linked document before editing. Add guidance only for a concrete decision or failure the author will encounter; omit architecture tours, migration history, speculative capabilities, and duplicated rules.

Use the remix acceptance exercise to check the guidance: an author should be able to change the sample and obtain a verdict using only the remix and its explicit public pointers. A need to inspect parent code is a gap to fix in the contract, instructions, or verifier feedback.

## Black-box verification

Add a parent-owned endpoint, proposed as `POST /source-verifications`, accepting `{endpoint, sourceKey}`. It probes a deployed candidate without requiring registration and without writing registry or assignment state.

Return JSON with an overall `pass` boolean and failed findings containing a check, location where applicable, and repairable explanation. A completed failed verification is a normal result; malformed verification requests are `400` errors. Do not return fetched response bodies, stack traces, or parent data.

For this first pass, support the no-settings canonical source profile only and state that scope in the result. Exercise the real GET response through the same canonical envelope and item guards used by serving. Check identity, JSON/content type, no-store, valid items, existing response/time/item budgets, omitted and valid offsets, malformed/repeated offsets, unknown settings, and non-GET rejection. Do not probe writes or ingest routes. Do not require legacy descriptor, validation, read, or publish routes.

Use bounded response reading and request deadlines. Because a caller supplies the destination, restrict candidates initially to HTTPS Val Town endpoint hosts, reject redirects and parent-owned endpoints, and bound request size and verification work. Keep this endpoint verification-only; it must not become a general fetch proxy.

Keep the checker independent of registry lookup and persistence. Parent-owned verification for a manually registered canonical source calls the same checker and records its result through the existing conformance mechanism. Existing v1 sources retain their existing verification path.

Passing checks establish observed protocol behavior, not event accuracy or complete future correctness. Empty items are valid, but the template acceptance run must exercise its nonempty sample.

## Parent integration

Keep new canonical sources out of the legacy descriptor/settings/probe requirements. Make only the narrow parent changes required to recognize a manually wired, no-settings canonical source, verify its actual GET transport, and consume it through the existing composer.

Reuse the existing explicit canonical transport selection if it remains sufficient; do not build a discovery system, generic transport framework, or registry UI. Store or configure the expected source identity and empty settings on the parent side. Do not fabricate successful legacy probe results or require compatibility routes in the template.

Before implementation, trace descriptor and settings assumptions in registration, assignment, preview, and verification. If any seam needs broader work, preserve this milestone's no-settings scope rather than growing the template to satisfy legacy assumptions.

Manual registration for the acceptance demonstration is parent-owned and does not authorize assigning sample data to an existing device. Use an isolated parent-owned fixture for composition and clean it up; code branches share production SQLite.

## Execution and acceptance

1. Confirm the current canonical contract and the parent seams above. Resolve only missing behavior required for this no-settings profile.
2. Implement the registry-independent GET checker and its bounded endpoint on a parent branch. Extend the existing owning checks for this lasting boundary; run the parent core runner.
3. Create `plusjade/source-template` with the minimal runtime, README, and `AGENTS.md`. Verify its deployed HTTP endpoint and obtain a passing result from the external endpoint with a nonempty sample.
4. Remix it once, change identity and sample content, and verify it through the same endpoint. Manually wire the candidate through the parent and demonstrate actual canonical composition using an isolated fixture. No existing source or device assignment changes.
5. Confirm malformed candidates fail with actionable findings, failed verification does not register or activate anything, and the existing parent core checks still pass. Preserve deployed HTTP file identities when merging.
6. Update current ownership/authoring guidance in place and add one concise decision-log entry with implementation and verification pointers. Do not reproduce this plan in permanent agent instructions.

Done means a working remix, a passing black-box GET verification, proven parent consumption, and unchanged existing sources. The template has no parent imports, credentials, runtime calls, or registry access. No fleet migration or SDK retirement is included.
