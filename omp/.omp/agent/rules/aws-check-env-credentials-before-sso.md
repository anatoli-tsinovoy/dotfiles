---
name: aws-check-env-credentials-before-sso
description: "Test shell-environment AWS credentials before treating a named-profile failure as an authorization blocker"
condition: ["aws\\s+sts\\s+get-caller-identity\\s+--profile\\s+(?:PowerUser|IAM)", "(?:Authorize the required AWS PowerUser SSO session|Please authorize the renewed PowerUser code)"]
scope: ["tool:bash(/root/DrawRecog*)", "tool:ask"]
---

A profile-scoped AWS failure does not prove that AWS access is unavailable. Before requesting SSO authorization or declaring the task blocked, run `aws sts get-caller-identity` **without `--profile`** so the CLI can use `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` from the shell environment. If it succeeds, continue using unqualified `aws` commands.