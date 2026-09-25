# Testing and manual acceptance

Keep implementation verification bounded: establish that the core flow works,
then hand off the broader end-to-end acceptance matrix for manual testing. This
boundary avoids spending implementation sessions on repeated environment setup
and combinations that are better evaluated by a person.

## Agent verification

- Run the required build, existing code checks, and lint for the changed domain.
  [AGENTS.md](../AGENTS.md#tests) owns runner selection and test maintenance;
  domain docs own their contract-specific verification requirements. This policy
  does not waive those checks or reduce existing automated coverage.
- Exercise one representative happy path through the changed flow using the
  smallest useful setup: for example, one widget placement with one selected feed,
  or one request to the changed endpoint with representative data.
- Fix observed failures and rerun affected checks. Broaden investigation only when
  a failure, a concrete unresolved risk, or the task's explicit scope warrants it.
- Do not expand the smoke test into a matrix of devices, widget instances, surface
  combinations, lifecycle transitions, upgrades, or repeated installation cycles.
  Leave those combinations to manual acceptance unless explicitly requested.
- If signing, hardware, permissions, or runtime setup blocks the smoke test,
  report what is blocked and the next verification step. Do not repeatedly
  experiment with environment setup to complete a manual acceptance matrix.
- Reuse relevant completed verification. Repeat it only when the changed behavior
  or new evidence makes the earlier result insufficient.

## Required handoff

Every implementation handoff must include verification results and an explicit,
change-specific manual testing plan. Separate passed, failed, blocked, and unrun
checks; a passing build is not evidence that runtime acceptance passed.

Keep the manual plan short and executable. For each meaningful scenario, specify:

1. Required setup or starting state.
2. Actions to perform.
3. Expected observable result.

Include the relevant deferred combinations and any blocked core smoke test. Name
required hardware or signing conditions when known. If no manual testing is
needed, say so and explain briefly. Do not claim manual acceptance until its
results are reported.

Stop after the scoped verification and handoff; do not execute the deferred matrix
without a further request. Record consequential unresolved verification in the
relevant operational/status doc under the documentation policy in
[AGENTS.md](../AGENTS.md#documenting-decisions), rather than accumulating run
results in this policy.
