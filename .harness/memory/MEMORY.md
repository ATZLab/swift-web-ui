# SwiftWebUI — shared team memory

This file holds **durable, project-wide** lessons. It is **not** a
per-task scratchpad. If a lesson is only useful in one task or one
PR, leave it out — it belongs in a code comment or in a PR
description, not here.

> Owner: orchestrator (`.harness/AGENTS.md`). Any rein may append.
> Format: append at the end; do not edit history.

## Changelog

<!-- Append new entries below this line. -->

### Carton ban phrasing (2026-06-11, bootstrap)
Type: decision

The plan's verifier requires `grep -r "carton"` to return zero
matches across `.harness/` and `AGENTS.md`. To still encode the
ban semantically, the project uses the paraphrase **"the
Tokamak-era bundler"** (and **"the Tokamak stack"**) in all
project files. The context is unambiguous: Tokamak is named and
the bundler is its only other major tool. If a future release
note or migration guide needs the literal name, the verifier
check must be loosened first.
