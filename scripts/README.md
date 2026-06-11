# scripts/

Shell scripts owned by `swiftwebui-tooling`. All are executable;
none of them require sudo.

| Script | Summary | Invoked by |
|---|---|---|
| `serve.sh` | One-shot dev workflow: host build + test, best-effort wasm32 build, serve `web/` on `http://localhost:8000`. | A contributor, manually. |
| `lint-paths.sh` | Path-hygiene guard. Fails if any tracked Markdown contains an absolute filesystem path. Run before any PR. | CI (`ci.yml`), and manually as a pre-PR sweep. |
| `finish-task.sh` | Worker finish protocol. Commits on the current feature branch, pushes to `origin`, prints the PR URL. Refuses to run on `main`. | Every Mavis worker, at end of task. |
| `open-pr.sh` | Train-PR opener. Verifies the branch is pushed, builds a PR body from commit subjects + the project's `PULL_REQUEST_TEMPLATE.md`, and calls `gh pr create`. Refuses to run on `main` or on a non-pushed branch. | The last worker (or the owner) at the end of a phase, exactly once per phase. |
| `release.sh` | Non-destructive release pre-flight. Refuses to run on `main`; best-effort `gh pr checks`; **prints** the `git tag -s` + `git push` commands the owner will run by hand; appends a one-line "tagged" entry to `.harness/changelogs/<today>.md` (does NOT commit it). | The release owner, after the close-out PR is merged to `main`. |

## Order of operations for a fresh clone

```bash
# 1. Confirm the path-hygiene guard is clean.
scripts/lint-paths.sh

# 2. Build and test on the host triple.
swift build
swift test

# 3. Run the dev server.
scripts/serve.sh
#   → http://localhost:8000
```

## Order of operations for finishing a worker task

```bash
# On the current feature branch (NOT main):
scripts/finish-task.sh "<commit message>"
#   → commits, pushes, prints the PR URL.
```

The worker does NOT open the PR. The owner opens it on github.com.
