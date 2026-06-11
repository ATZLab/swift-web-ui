---
name: Bug report
about: Report a defect in SwiftWebUI — wrong DOM, wrong behaviour, crash, build break.
title: "[bug] "
labels: ["bug", "needs-triage"]
assignees: []
---

## Summary

One or two sentences. What broke, and what you expected to happen.

## Reproduction steps

Minimal Swift snippet that produces the bug:

```swift
import SwiftWebUI

struct Repro: View {
    var body: some View {
        // ...
    }
}
```

Steps to run:

1. `git clone` this repo at the commit / tag you used.
2. `./scripts/serve.sh` (or `swift test` for the unit path).
3. …

## Expected vs actual

**Expected** (what SwiftUI does, or what the docs say):

> …

**Actual** (what SwiftWebUI does today):

> …

## Environment

- Swift version (`swift --version`):
- OS and version (macOS / Linux / WSL / browser):
- Browser and version, for the wasm path (Chrome / Firefox / Safari):
- Commit SHA or tag (`git rev-parse HEAD`):
- Built with `./scripts/serve.sh` or a custom `swift build`?

## Relevant docs

Which of the project docs is most likely to be wrong or missing? (These
are the topics the reins are gated on.)

- [`AGENTS.md`](../../AGENTS.md) — locked decisions
- [`ROADMAP.md`](../../ROADMAP.md) — milestone / stop condition
- [`.harness/docs/swift-ui-surface.md`](../../.harness/docs/swift-ui-surface.md) — public surface ledger
- [`.harness/docs/naming.md`](../../.harness/docs/naming.md) — naming rules
- [`.harness/docs/tdd.md`](../../.harness/docs/tdd.md) — TDD contract
- [`.harness/docs/docc.md`](../../.harness/docs/docc.md) — DocC contract
- [`.harness/docs/js-bridge.md`](../../.harness/docs/js-bridge.md) — JavaScriptKit interop
- [`.harness/docs/release.md`](../../.harness/docs/release.md) — versioning

## Severity

How broken is it? (Pick one. Delete the others.)

- [ ] Blocker — `swift build` / `swift test` fails, no workaround.
- [ ] Major — wrong DOM or wrong behaviour, with a workaround.
- [ ] Minor — cosmetic, naming, or ergonomics issue.
- [ ] I don't know — please triage.

## Security

> **Is this a security vulnerability?** If yes, **do not file a public
> issue** — follow [`SECURITY.md`](../../SECURITY.md) and open a
> private security advisory on GitHub instead.
