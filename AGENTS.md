# Agent instructions

## Project

SwiftUI iOS app with a WidgetKit extension. App target `clark_view`, bundle id `plusjade.clark-view`, deployment target iOS 26.5, Swift 5.0. No third-party dependencies.

Four targets: `clark_view` (app), `ClarkViewWidgetExtension` (widget), `clark_viewTests` (unit tests), and `clark_viewUITests` (UI tests).

Clark View is widget-first: the containing app handles pairing and diagnostics, while the user-facing sports experience lives in `ClarkViewWidget`. Its server API and browser-managed configuration are hosted by the Val Town project `plusjade/sports-today`. Before using Val Town MCP tools or changing the iOS/server boundary, read [`docs/valtown-brief.md`](docs/valtown-brief.md); it caches the endpoint identity, route and payload contracts, ownership boundaries, and the bounded MCP workflow intended to prevent redundant remote reads.

## Build & test

Build and run via Xcode, or from the CLI:

```
xcodebuild -project clark_view.xcodeproj -scheme clark_view build
xcodebuild -project clark_view.xcodeproj -scheme clark_view test
```

Unit tests (`clark_viewTests`) use the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`) — not XCTest. UI tests (`clark_viewUITests`) use XCTest (`XCUIApplication`) as usual.

## Linting

SwiftLint is configured (`.swiftlint.yml`). Run `swiftlint lint` from the project root. `type_name` is disabled project-wide since the project name contains an underscore, which every top-level type inherits.

## Code style

**Shared**
- Prefer **small, focused changes** that match the request; avoid drive-by refactors or unrelated file edits.
- **Comments orient the mental model, not the code**: Class and module headers answer "what is this and where does it fit in the system?" — 1–3 lines a distracted reader can parse at a glance without touching the implementation. Inline comments are for the non-obvious *why*: hidden constraints, subtle invariants, surprising behavior, gotchas. Never explain *what* the code does; well-named identifiers handle that. If removing the comment wouldn't confuse a future reader, don't write it.

### Browser UI (Val Town)

- Match the existing configurator's intentionally minimal visual language. Start with semantic HTML and the browser's native rendering; add CSS only when it improves hierarchy, scanning, responsive layout, or accessibility.
- Treat `render/configHtml.ts`'s shared `pageShell` and page styles as the browser application's source of truth. Reuse them instead of creating parallel typography, color, width, table, form, or timestamp rules; preserve the established system font stack and existing color and weight choices.
- Prefer headings, paragraphs, navigation, tables, lists, definition lists, fieldsets, and native form controls. The document structure should explain the interface without decorative containers.
- Avoid dashboard chrome by default: no card grids, pills or badges, shadows, gradients, oversized headings, uppercase micro-labels, decorative backgrounds, or rounded shells around ordinary content.
- Use whitespace and a small number of subtle rules to separate sections. A border should communicate table structure, grouping, or focus—not merely decorate a box.
- React is an implementation detail, not a visual style. Do not add Tailwind, Twind, a component library, or client-side JavaScript solely because a view uses React; follow the established server-rendered UI first.
- Follow the existing navigation hierarchy. Index pages stand alone without a global navigation bar; resource show/edit pages use the small back breadcrumb, and only config-scoped subpages use the config tab navigation. Do not introduce new global navigation as part of a feature view.
- Keep operational pages compact and data-dense. Show stable labels and identifiers plainly, preserve meaningful document order, and make empty/error states ordinary prose rather than special panels.

## Programming patterns

### A. Shared programming hygiene (all code)

- Boundaries, not "random coupling." Treat I/O, time, randomness, process/environment concerns, and other nondeterminism as external concerns.
The core should be as pure / deterministic as practical so behavior is testable and explainable.
- Dependency direction: push I/O and policy that varies to the edges; keep the core unaware of how requests are served in jobs, CLI, or non-HTTP apps.
- Testing seams (pragmatic, not purist): Inject external/nondeterministic collaborators where it materially improves tests; don't inject stable trivia "because patterns".
- Engineering safety: avoid surprise global mutable state, class-level mutable configuration that changes per test/call,
and load-time side effects at gem initialization when it's avoidable—they make tests flaky and code paths "blessed" by accident.
- Explicit beats spooky: if something must be configured, prefer it to be discoverable (constructor args, documented initializer, app wiring) over implicit magic.
- Coupling control: be skeptical of "train wreck" call chains and deep knowledge of other objects' internals; prefer clear interfaces without turning everything into a mediator maze.
- YAGNI: build for the requirement in hand, never a hypothetical future one. *Trigger: the justification for a param, config knob, abstraction layer, or branch is a "might need it" — or you find a code-path no current caller exercises. Then: don't write it (or delete it); capture the idea in a comment or issue.* Deferring is the profitable move, not the timid one — an unbuilt feature holds its full upside at zero carrying cost, and requirements only sharpen with time. You pay to build when the value actually lands; until then you hold the OPTION and let its value accrue (finance metaphor).
