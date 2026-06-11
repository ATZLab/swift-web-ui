# Security policy

> Owner: `swiftwebui-steward`. Last revised: 2026-06-11.

## Reporting a vulnerability

**Do not open a public GitHub issue for security bugs.** Public issues
are indexed by search engines and the moment a vulnerability is
described in the open, every downstream user is exposed before a fix can
ship.

Use one of the two private channels below:

1. **Preferred: GitHub private security advisory.**
   Open a draft security advisory on this repository:
   `https://github.com/ATZLab/swift-web-ui/security/advisories/new`
   (or: **Settings → Security → Advisories → New draft security
   advisory** in the GitHub web UI).
   GitHub's advisory workflow keeps the report private between the
   reporter and the maintainers until a CVE is reserved and a fix is
   ready, at which point the advisory is published alongside the
   patched release.

2. **Fallback: email the steward.** If GitHub's advisory workflow is
   not available to you, email the steward at the address listed in
   [`CODE_OF_CONDUCT.md`](./CODE_OF_CONDUCT.md). The steward will
   respond within **three business days** with an acknowledgement and
   a tracking reference.

Reports should include:

- A short description of the vulnerability and its impact.
- A reproducer — minimal Swift snippet, JS payload, or build command.
- The affected version range (or commit SHA).
- The reporter's preferred contact channel and credit name for the
  eventual advisory.

## What happens after a report

1. **Acknowledge** within three business days.
2. **Triage** within one week: severity, affected versions, exploit
   surface, and a CVE request via GitHub's advisory workflow.
3. **Fix** in a private PR; ship on the next minor / patch release
   (see [`ROADMAP.md`](./ROADMAP.md) for the SemVer policy).
4. **Disclose** the advisory alongside the patched release so users
   can update.

## No public issue until a CVE is reserved

Until GitHub (or MITRE) reserves a CVE for the report, no part of the
vulnerability — reproducers, screenshots, partial fixes, or hints — is
posted to public issues, Discussions, social media, or third-party bug
trackers. The moment a CVE is reserved, the steward publishes the
advisory and a short "what changed" note in the next
[`ROADMAP.md`](./ROADMAP.md) stop-condition entry.

## Out of scope

- Theoretical issues without a concrete reproducer.
- Best-practice suggestions that do not describe a specific
  vulnerability.
- Issues in **JavaScriptKit** (file an advisory against the
  `JavaScriptKit/JavaScriptKit` repository — SwiftWebUI inherits its
  security posture from there).
- Issues in upstream Swift / SwiftWasm toolchains (file with
  [swift.org](`https://forums.swift.org`) or the Swift bug tracker).

## Supported versions

Until 1.0.0 ships, the project is pre-stable and only the latest
minor receives security fixes. Once 1.0.0 is released, the supported
range is the latest minor + the previous minor, in line with the
SemVer policy in
[`.harness/docs/release.md`](./.harness/docs/release.md).
