# Pull request

> **One branch per concern.** A PR fixing `renderer-null-child` should
> not also sneak in an unrelated `bridge-js-closure` refactor. Split
> it. The full rule is in [`AGENTS.md` §9](../../AGENTS.md#9-git-workflow--feature-branches-push-as-pr-owner-merges-on-github).

## Linked issue

- Closes # (or `fixes #`, or `relates to #`).

## Summary

One or two sentences. The "what" and the "why", not the diff.

## Test pair (TDD)

> **No production code lands in `main` without a failing test in the
> same (or earlier) commit.** The full contract is in
> [`.harness/docs/tdd.md`](../../.harness/docs/tdd.md).

- **Red commit**: `<sha> — <one-line test name>`
- **Green commit**: `<sha> — <one-line fix name>`

If this is a docs-only / chore / mechanical change, write "N/A — no
production code change" and explain.

## Reviewing reins

Which reins should review which file? (The full routing table is in
[`.harness/AGENTS.md`](../../.harness/AGENTS.md).)

- `swiftwebui-architect` — public API surface, SPI gating.
- `swiftwebui-tester` — tests, snapshots, WebDriver smoke.
- `swiftwebui-dom-renderer` — `_Graph`, diff/patch, event delegation.
- `swiftwebui-bridge` — JavaScriptKit interop, `JSClosure` lifetime.
- `swiftwebui-tooling` — `Package.swift`, JS bundle, dev server, CI.
- `swiftwebui-docs` — DocC, tutorial, guide text.
- `swiftwebui-steward` — release shape, templates, version bump.

## Pre-PR checklist

Confirm each of these before requesting review:

- [ ] `./scripts/lint-paths.sh` is green.
- [ ] `swift build` and `swift test` are green on the host triple.
- [ ] `swift build --triple wasm32-unknown-wasi` is green (if the
      change touches a Swift source file).
- [ ] `swift package generate-documentation` finishes with **zero
      warnings** (if the change touches a public symbol).
- [ ] A per-day entry has been added to
      `.harness/changelogs/$(date -I).md` in the format
      `HH:MM <rein-name> — <one-line summary>`.
- [ ] I read [`AGENTS.md` §9](../../AGENTS.md#9-git-workflow--feature-branches-push-as-pr-owner-merges-on-github)
      and did not commit to `main`.

## Public surface change (only if applicable)

> If this PR adds, removes, or renames a public symbol, the block
> below is required. The CI matrix fails the PR on an unintentional
> breaking change — see
> [`.harness/docs/release.md`](../../.harness/docs/release.md).

### `## API Changes`

- Symbols added:
- Symbols removed:
- Symbols renamed:
- Migration path for removed / renamed symbols:
- Smallest usage example for each new symbol:

If this is a breaking change, the commit subject must include `!` (e.g.
`feat(renderer)!: rename _GraphNode`).

## DocC (only if applicable)

If this PR adds a public symbol, the same (or earlier) commit on this
branch must include:

- [ ] A `///` DocC comment with `## Discussion` and `## Example` on
      the new symbol.
- [ ] A `swift-testing` `@Test` (or `@Suite`) covering the new symbol.
- [ ] The new symbol reflected in
      [`.harness/docs/swift-ui-surface.md`](../../.harness/docs/swift-ui-surface.md)
      under the matching version row.

## Security

> Is this PR a security fix? If yes, link the GitHub security advisory
> (e.g. `GHSA-xxxx-yyyy-zzzz`) and **do not** describe the
> vulnerability in this PR description. See
> [`SECURITY.md`](../../SECURITY.md).
