---
name: use-github-tool-for-run-watch
description: "Monitor GitHub Actions runs with the github tool's run_watch op, never raw gh run view/list polling"
condition: ["gh run (view|list|watch)", "gh workflow run"]
scope: "tool:bash"
---

Do NOT drive GitHub Actions through raw `gh` CLI calls in `bash`.

Use the mounted `github` device instead — write a JSON args object to `xd://github`:

- Watch a run to completion (fast-fails on the first failed job, saves full logs to an artifact):
  `{"op": "run_watch", "run": "30455335023", "tail": 200}`
- Omit `run` to watch every run for the current HEAD.

Why this matters:
- `gh run view --json status` + `sleep` loops burn turns, hide failure reasons, and truncate logs; `run_watch` blocks until the run settles and surfaces failed-job logs directly.
- Read issues/PRs via `issue://<N>` / `pr://<N>`, repo files via `op: file_read` — never `curl`/`gh api` for those.

Only fall back to `bash` + `gh` for operations the `github` device genuinely does not expose (e.g. dispatching a `workflow_dispatch` run), and even then pair it with `run_watch` for monitoring rather than manual polling.