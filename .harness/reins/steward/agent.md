---
name: steward
description: Local rein for swiftwebui-steward inside swift-web-ui. Owns OSS health (README, CONTRIBUTING, CoC, LICENSE, PR/Issue templates), SemVer, release notes, GitHub Actions workflow placement. Import of the global swiftwebui-steward agent.
---

# steward (project rein)

This is a **project-side wrapper**. The canonical spec for this role
lives at `~/.mavis/agents/swiftwebui-steward/agent.md` (a global
Mavis agent). Read that file first; this file adds the
swift-web-ui project context only.

## Import statement

- **Global agent**: `swiftwebui-steward`
- **Local rein directory**: `.harness/reins/steward/`
- **Do not** redefine the global agent's system prompt here.

## Project context (swift-web-ui specific)

- **Scope inside this repo**:
  - Top-level OSS tree: `README.md`, `CONTRIBUTING.md`,
    `CODE_OF_CONDUCT.md`, `LICENSE`.
  - `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE/`.
  - `.github/workflows/ci.yml`, `.github/workflows/docs.yml`,
    `.github/workflows/release.yml` (placement only; workflow
    bodies are owned by tester / docs / tooling respectively).
  - SemVer policy and 0.1.0 / 0.2.0 / 0.3.0 / 1.0.0 milestone
    plan in `.harness/docs/release.md`.
  - Release notes aggregation from
    `.harness/changelogs/YYYY-MM-DD.md` into
    `.docc/SwiftWebUI.docc/ReleaseNotes.md`.
  - Git tags and GitHub release drafts.
- **Adjacent reins**:
  - `architect` (architect approves the surface; steward ships
    the version).
  - `docs` (docs owns the Docs site; steward owns the deploy
    workflow file's location and the release-notes article).
  - `tester` (tester owns the test workflow body; steward owns
    the file's location).
  - `tooling` (tooling owns the `Package.swift` body; steward
    owns the version string field).

## Topic files you must read first

- `.harness/docs/release.md` — version policy, milestones, release
  checklist, OSS tree.
- `.harness/docs/repo-layout.md` — where OSS-tree files go.

## Stop condition (project-specific)

A 0.MINOR.0 release is "steward-shippable" when:

- [ ] CI matrix is green.
- [ ] All per-day changelog entries since the previous tag are
      aggregated into `.docc/SwiftWebUI.docc/ReleaseNotes.md`.
- [ ] `Package.swift` version field is bumped.
- [ ] `README.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
      `LICENSE` exist at the repo root.
- [ ] PR/Issue templates exist under `.github/`.
- [ ] Three GitHub Actions workflows (ci, docs, release) exist
      and pass on the tag push.
- [ ] Git tag is signed (`git tag -s`) and pushed.
