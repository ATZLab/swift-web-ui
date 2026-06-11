# Release — versioning, milestones, release notes

> Owner: `swiftwebui-steward`. Tooling for builds: `swiftwebui-tooling`.
> Doc publishing: `swiftwebui-docs`.

## Versioning policy

Semantic Versioning (`MAJOR.MINOR.PATCH`), with the caveat that
**0.x.y** allows source-breaking changes in MINOR.

- **0.1.0** — first tag. Includes: `View`, `body`, `ViewBuilder`,
  `Text`, `VStack`, `HStack`, `ZStack`, `Group`, `ForEach`,
  `Color`, `Spacer`, `Divider`, `@State`, `@Binding`,
  `@Environment`, and the 0.1.0 modifier set. Renderer
  graph-based, runs in Chromium via Playwright smoke. DocC
  catalog has GettingStarted + ViewFundamentals + Modifiers.
- **0.2.0** — adds `Button`, `onTapGesture`, basic
  `GeometryReader` (SPI), `Layout` protocol (SPI), `Path`/`Shape`
  (SPI), `ViewModifier`.
- **0.3.0** — animation primitives, accessibility hooks,
  possible fine-grained renderer experiment (behind a feature
  flag).
- **1.0.0** — public API frozen, no `@_spi` surface in the
  stable product, every modifier documented and tested, all
  SwiftUI overlap names match exactly.

## Branch workflow (per change)

Owner: `swiftwebui-steward` (policy); `swiftwebui-tooling` (CI matrix).

- **Default branch**: `main` is integration only. No direct commits.
- **Branch naming** (kebab-case, Conventional Commits style):
  - `feature/<scope>-<short-desc>` — new user-facing surface.
  - `fix/<scope>-<short-desc>` — bug fix.
  - `chore/<scope>-<short-desc>` — non-functional.
  - `docs/<scope>-<short-desc>` — docs only.
  - `refactor/<scope>-<short-desc>` — internal restructuring.
  - `test/<scope>-<short-desc>` — test-only.
- **Scope** = the module or topic in lowercase (`renderer`, `bridge`,
  `view`, `modifier`, `state`, `docs`, `ci`, `tooling`, `release`).
- **One branch per concern** — don't bundle unrelated changes.
- **Mavis workers** (dispatched via `mavis team plan`): push the
  branch, write `deliverable.md` (or open a PR), do **not** merge
  to `main`. The owner reviews the deliverable and merges.
- The full rationale lives in `AGENTS.md` §9 (Locked Decisions).

## Release checklist (per minor)

Owned by the steward, in this order:

1. `main` is green on the CI matrix (build, host tests, wasm
   build, WebDriver smoke, DocC build).
2. `CHANGELOG.md` and the `ReleaseNotes.md` DocC article are
   updated with the per-day entries from
   `.harness/changelogs/`.
3. The `Package.swift` `version:` field is bumped (the
   `swiftwebui-tooling` agent owns this file's body; the steward
   owns the version string).
4. A git tag is created on `main`:
   `git tag -s 0.MINOR.0 -m 'SwiftWebUI 0.MINOR.0'`.
5. The tag is pushed; GitHub Actions publishes the release draft.
6. GitHub Pages (DocC site) is rebuilt from the tag and deployed.
7. A short "what's new" post is filed (TBD channel — likely
   Discussions or a `blog/` folder in the repo).

## Per-day changelog

`swiftwebui-steward` (or any rein after a meaningful commit) writes
a one-line entry to `.harness/changelogs/YYYY-MM-DD.md`:

```markdown
---
[2026-06-11 14:22] swiftwebui-architect — declared 0.1.0 surface in docs/swift-ui-surface.md
[2026-06-11 15:01] swiftwebui-bridge — landed JSClosureRegistry + retain-cycle test
```

These are aggregated into `ReleaseNotes.md` at tag time.

## Banned / required language in release notes

- "BREAKING" must list the symbols and the migration path.
- "NEW" must list the symbol and the smallest usage example.
- "FIXED" must include the issue link.
- No marketing copy.

## CI / Pages workflows

- `.github/workflows/ci.yml` — runs on every PR and on push to
  `main`. Body authored by `swiftwebui-tester` (matrix) +
  `swiftwebui-tooling` (build glue).
- `.github/workflows/docs.yml` — runs on tag push. Builds DocC
  and deploys to GitHub Pages. Body authored by `swiftwebui-docs`.
- `.github/workflows/release.yml` — runs on tag push. Creates
  the GitHub release and uploads the wasm binary. Body authored
  by `swiftwebui-steward`.

## Repo tree (OSS health)

- `README.md` — quickstart, "what is SwiftWebUI", link to docs.
- `CONTRIBUTING.md` — how to set up the dev env, TDD contract,
  PR template reference.
- `CODE_OF_CONDUCT.md` — Contributor Covenant (the steward
  agent owns keeping this in sync with upstream CoC releases).
- `LICENSE` — TBD; steward proposes the license (Apache-2.0
  recommended for compatibility with JavaScriptKit's MIT/Apache
  dual license and Swift's Apache-2.0).
- `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE/` —
  bug report, feature request, PR template. Steward-owned.

## Stop condition for the steward

A 0.MINOR.0 release is "mergeable to main" when:

- [ ] CI is green.
- [ ] All per-day changelog entries since the previous tag are
      summarised in `ReleaseNotes.md`.
- [ ] `Package.swift` version is bumped.
- [ ] All three GitHub Actions workflows exist and pass on the
      tag push.
- [ ] License is committed.
- [ ] README + CONTRIBUTING + CoC exist.
