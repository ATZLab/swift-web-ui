# Contributing to SwiftWebUI

> Welcome. SwiftWebUI is an open-source, SwiftUI-style declarative UI
> framework for the web, built on **JavaScriptKit** and the **Wasm** target.
> The full project brain — locked decisions, package name, JavaScriptKit-only
> rule, SemVer policy, and the branch workflow — lives in
> [`AGENTS.md`](./AGENTS.md). Read it first; this guide covers the
> contributor mechanics on top of that.

## Code of conduct

All participants are expected to follow the
[Contributor Covenant, version 2.1](./CODE_OF_CONDUCT.md). Reports of
unacceptable behaviour go to the steward at the address in
[`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md).

## Development environment

### Prerequisites

- **Swift toolchain** with the `wasm32-unknown-wasi` target installed
  (verify with `swift --version` and
  `swift build --triple wasm32-unknown-wasi --help`).
- A modern browser (Chromium, Firefox, or Safari) for the Playwright smoke.
- `git` and your editor of choice.

### Setup

```bash
# 1. Fork the repo on GitHub, then clone your fork.
git clone https://github.com/<your-handle>/swift-web-ui.git
cd swift-web-ui

# 2. Add the upstream remote (so you can sync with main).
git remote add upstream https://github.com/ATZLab/swift-web-ui.git
git fetch upstream

# 3. Build the host target and run the unit + snapshot tests.
swift build
swift test

# 4. Build the wasm target — proves the JavaScriptKit bridge compiles.
swift build --triple wasm32-unknown-wasi

# 5. Run the local dev workflow (build wasm + bundle JS + serve).
./scripts/serve.sh
```

> The `./scripts/serve.sh` step above activates once the
> `feature/tooling-package-skeleton` PR is merged. Until then, build the
> host target with `swift build` and `swift test` — they are the fastest
> feedback loop and do not require the wasm toolchain.

## TDD is mandatory

> **No production code lands in `main` without a failing test in the
> same (or earlier) commit.**

The full TDD contract lives in [`.harness/docs/tdd.md`](./.harness/docs/tdd.md).
The short version:

1. **Red** — open a PR with a failing test that describes the new
   behaviour. The CI matrix must show red on the relevant test target.
2. **Green** — commit the smallest implementation that makes the test
   pass. CI goes green.
3. **Refactor** — clean up while keeping tests green.

Test framework of record is **swift-testing** (`@Test`, `@Suite`,
`#expect`, `#require`). Snapshot tests live in
`Tests/SwiftWebUISnapshots/`. Browser smoke tests live in
`Tests/SwiftWebUIWebDriver/`. The `swiftwebui-tester` agent enforces this
contract on every PR.

## Branch workflow (no direct commits to `main`)

> **`main` is integration only. Every change lands through a feature
> branch → push to `origin` → GitHub PR → owner merges on github.com.**

The full rule lives in [`AGENTS.md` §9](./AGENTS.md#9-git-workflow--feature-branches-push-as-pr-owner-merges-on-github).
Quick rules of the road:

### Branch naming

Conventional Commits style, kebab-case scope:

| Prefix       | When                                               | Example                                |
|--------------|----------------------------------------------------|----------------------------------------|
| `feature/`   | New user-facing surface (modifier, view, state)    | `feature/renderer-initial-graph`       |
| `fix/`       | Bug fix                                            | `fix/renderer-null-child`              |
| `chore/`     | Non-functional (CI, scripts, repo hygiene)         | `chore/ci-cache`                       |
| `docs/`      | Documentation only                                 | `docs/swift-ui-surface`                |
| `refactor/`  | Internal restructuring                             | `refactor/bridge-js-closure-registry`  |
| `test/`      | Test-only changes                                  | `test/snapshot-text-div`               |

The **scope** is the module or topic name in lowercase (`renderer`,
`bridge`, `view`, `modifier`, `state`, `docs`, `ci`, `tooling`,
`release`).

### One branch per concern

A PR fixing `renderer-null-child` should not also sneak in an unrelated
`bridge-js-closure` refactor. Split it. Squash-merge is the default —
two commits on a feature branch flatten into one on the way to `main`.

### Finishing a task

Workers and contributors run [`scripts/finish-task.sh`](./scripts/finish-task.sh)
to do the commit + push in one shot. The script:

1. Refuses to run on `main` (or `master`).
2. Refuses to run mid-merge or mid-rebase.
3. `git add -A` and commits with the provided message.
4. `git push -u origin <branch>`.
5. Prints the PR URL.

```bash
scripts/finish-task.sh "feat(renderer): initial _Graph node kinds"
```

The owner (the human, via Mavis root) opens the PR on github.com, reviews
the diff, and merges there. **No local `--no-ff` shortcut** — that breaks
`git log --first-parent main` as the release audit trail.

## Commit style

Follow the [Conventional Commits](`https://www.conventionalcommits.org/`)
spec, one-line summary in the subject, body wraps at 72 columns. The
prefix matches the branch type:

- `feat:` for new user-facing surface.
- `fix:` for bug fixes.
- `chore:` for non-functional changes.
- `docs:` for documentation only.
- `refactor:` for internal restructuring.
- `test:` for test-only changes.
- `perf:` for performance improvements.

Breaking changes use a `!` after the type (e.g. `feat(renderer)!: rename
_GraphNode`).

## API surface changes

If a PR changes the **public** surface, the PR description must include a
`## API Changes` block listing:

- The symbols added, removed, or renamed.
- A migration path for removed / renamed symbols.
- A small usage example for any new symbol (this feeds the release notes).

A `feat!:` or `feat(api)!:` commit is required for any intentional
breaking change. The CI matrix fails the PR if the public API diff is
unintentional — see
[`.harness/docs/release.md`](./.harness/docs/release.md) for the policy.

## Documentation

- Public API uses `///` DocC comments. Non-trivial types include a
  `## Discussion` and `## Example` section. Tone is Apple guide tone:
  declarative, no second-person, no marketing copy. See
  [`.harness/docs/docc.md`](./.harness/docs/docc.md) for the full template.
- `swift package generate-documentation` must finish with **zero
  warnings** before merge.
- DocC catalog content lives in [`.docc/`](./.docc/) and is owned by
  `swiftwebui-docs`.

## Path hygiene

> **All paths in tracked docs MUST be repository-relative. No
> `/Users/...`, no `~/projects/...`, no Windows drive roots.**

[`scripts/lint-paths.sh`](./scripts/lint-paths.sh) enforces this and is
wired into CI. The full rule lives in [`AGENTS.md` §10](./AGENTS.md#10-repository-relative-paths-only--no-absolute-filesystem-paths-in-tracked-files).
Run it locally before pushing:

```bash
scripts/lint-paths.sh
```

## Versioning

SwiftWebUI follows [Semantic Versioning](`https://semver.org/`). Until
1.0.0, the format is `0.MINOR.PATCH`, where MINOR may break source
compatibility on a per-major-zero basis (see
[`.harness/docs/release.md`](./.harness/docs/release.md)). The current
milestone plan is in [`ROADMAP.md`](./ROADMAP.md).

## First PR — walkthrough

The fastest path to a first merged PR is to pick up a small item from the
open [good first issue](`https://github.com/ATZLab/swift-web-ui/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22`)
list, or to follow the open
[`feature/tooling-package-skeleton`](`https://github.com/ATZLab/swift-web-ui/pulls`)
PR. The walkthrough:

1. **Open an issue** (or comment on the open
   `feature/tooling-package-skeleton` PR) describing the change in one
   paragraph. Include a "test that proves it works" sentence.
2. **Branch** off `main`:
   `git checkout -b feature/<scope>-<short-desc> main`.
3. **Red commit** — write the failing test first. Run
   `swift test` and watch it go red.
4. **Green commit** — add the smallest implementation that makes the
   test pass. Run `swift test` and watch it go green.
5. **Path lint + DocC** — run `scripts/lint-paths.sh` and
   `swift package generate-documentation`. Both must be clean.
6. **PR** — `scripts/finish-task.sh "<commit message>"`, then open the
   PR on github.com. Fill in the PR template (linked issue, one-line
   summary, the red→green test pair, the reviewing reins).
7. **Review** — the architect and tester reins sign off; the owner
   merges.

## Reporting vulnerabilities

**Do not open a public issue for security bugs.** See
[`SECURITY.md`](./SECURITY.md) for the private advisory channel.
