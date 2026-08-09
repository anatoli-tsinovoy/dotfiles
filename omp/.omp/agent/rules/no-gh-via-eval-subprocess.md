---
name: no-gh-via-eval-subprocess
description: "Never shell out to `gh` from an eval cell — use the github device, pr://, or a single bash gh call"
condition: ["import subprocess[\\s\\S]*gh", "subprocess\\.run\\(\\[", "\\\\\"gh\\\\\",\\\\\"api\\\\\"", "\\\\\"gh\\\\\", *\\\\\"api\\\\\""]
scope: "tool:eval"
---

Do NOT drive the `gh` CLI from an `eval` cell via `subprocess.run([...])`, `Bun.$`, or any hand-rolled wrapper.

- GitHub work has first-class support: the **`xd://github` device** (`op: pr_create`, `pr_checkout`, `pr_push`, `run_watch`, `search_*`, `file_read`) and the `pr://<N>` / `issue://<N>` read URIs.
- For an endpoint the device does not cover (e.g. `gh api repos/<o>/<r>/pulls/comments/<id>/replies`), call it **once through `bash`**, passing prose through `env: { BODY: "…" }` and `-f body="$BODY"` so quoting stays safe.
- Several independent replies/requests → several parallel `bash` calls in one block, not a Python `for` loop around `subprocess`.
- Keep `eval` for computation over data you already hold. Wrapping CLIs there hides exit codes, loses the device's validation and caching, and makes the transcript unreviewable.