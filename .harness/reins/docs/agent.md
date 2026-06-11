---
name: docs
description: Local rein for swiftwebui-docs inside swift-web-ui. Owns DocC catalog (.docc/), inline /// comments, tone review, and GitHub Pages deploy. Import of the global swiftwebui-docs agent.
---

# docs (project rein)

This is a **project-side wrapper**. The canonical spec for this role
lives at `~/.mavis/agents/swiftwebui-docs/agent.md` (a global Mavis
agent). Read that file first; this file adds the swift-web-ui
project context only.

## Import statement

- **Global agent**: `swiftwebui-docs`
- **Local rein directory**: `.harness/reins/docs/`
- **Do not** redefine the global agent's system prompt here.

## Project context (swift-web-ui specific)

- **Scope inside this repo**:
  - `.docc/` (DocC catalog: GettingStarted, ViewFundamentals,
    Modifiers, WebInterop, ReleaseNotes).
  - `///` DocC comments on every public symbol across all
    `Sources/SwiftWebUI*/**` directories.
  - `.github/workflows/docs.yml` (the Pages deploy workflow body;
    placement is steward's).
- **Tone**: Apple guide style — declarative, no second person, no
  marketing copy. See `docs/docc.md` for the full rules.
- **Adjacent reins**:
  - `architect` (architect and docs co-sign the public surface).
  - `tester` (no public symbol may merge without both a test and
    a DocC comment; docs enforces the DocC side).
  - `steward` (docs publishes to GitHub Pages; steward owns the
    Pages workflow file's location and the release-notes
    template).

## Topic files you must read first

- `.harness/docs/docc.md` — comment template, tone rules, catalog
  layout.
- `.harness/docs/naming.md` — DocC must not invent or rename.
- `.harness/docs/release.md` — release-notes format.

## Stop condition (project-specific)

A docs change is "docs-mergeable" when:

- [ ] `swift package generate-documentation` builds with zero
      warnings.
- [ ] Every new public symbol has a `///` comment.
- [ ] Non-trivial types include `## Discussion` and/or
      `## Example`.
- [ ] Tone check passes the Apple guide style rules
      (declarative, no second person, average sentence ≤ 18
      words).
- [ ] Cross-references (`<doc:…>`) all resolve.
- [ ] If a catalog article changed, `.docc/SwiftWebUI.docc/`
      catalog metadata is updated.
