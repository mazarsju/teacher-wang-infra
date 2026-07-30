---
name: tf-state-lock-recovery
description: >-
  Recover from Terraform "Error acquiring the state lock" with S3 native
  lockfiles (use_lockfile). Downloads remote tfstate to last.terraform.tfstate,
  diffs it against local state, and deletes the .tflock only when identical.
  Use when Terraform fails with state lock / PreconditionFailed / .tflock errors,
  or when the user asks to clear a stale Terraform lock.
---

# Terraform state lock recovery

Mitigate stale S3 native locks (`use_lockfile = true`) safely.

This repo uses:

- Bucket from `backend.hcl` (e.g. `teacher-wang-tfstate-<account_id>`)
- State key from `backend.tf` (e.g. `teacher-wang/terraform.tfstate`)
- Lock object: `<state-key>.tflock` (e.g. `teacher-wang/terraform.tfstate.tflock`)

## When to run

Use immediately when Terraform reports `Error acquiring the state lock` (often S3 `412 PreconditionFailed`).

## Workflow

Copy this checklist and track progress:

```
Lock recovery:
- [ ] 1. Credentials + env root
- [ ] 2. Run recovery script
- [ ] 3. Act on script result (diff vs unlock)
- [ ] 4. Tell the user the outcome verbatim below when unlocked
```

### 1. Credentials + env root

From the environment directory (e.g. `environments/prod`):

```bash
source ../../config   # repo-root gitignored AWS creds
```

Confirm `backend.hcl` exists (bucket) and `backend.tf` has `key` + `use_lockfile = true`.

### 2. Run the recovery script

Execute (do not reimplement ad hoc):

```bash
bash ../../.cursor/skills/tf-state-lock-recovery/scripts/recover-state-lock.sh
```

Optional overrides:

```bash
bash ../../.cursor/skills/tf-state-lock-recovery/scripts/recover-state-lock.sh \
  --env-dir environments/prod
```

The script:

1. Resolves `bucket` / `region` / `key` from `backend.hcl` + `backend.tf`
2. Downloads the **current** (not version-id) S3 object into a **non-versioned local file** named `last.terraform.tfstate`
3. Compares that file to a local baseline, in order:
   - `terraform.tfstate`
   - prior `last.terraform.tfstate` (from a previous recovery run)
4. If they differ → prints the diff and **does not** delete the lock
5. If they match → deletes `s3://$bucket/$key.tflock` and prints the safe-to-retry message

### 3. Act on the result

| Exit | Meaning | Agent action |
| --- | --- | --- |
| `0` | States identical; lock deleted | Tell the user they can safely run Terraform again (use the success message below) |
| `2` | States differ | Show the diff; **do not** delete the lock; stop and ask the user how to proceed |
| `3` | No local baseline | Show lock info; ask the user to confirm a stale self-lock; only then re-run with `--force-unlock` |
| `1` | Tooling / AWS / config error | Fix creds/config and rerun; never delete the lock on error |

**Never** delete the `.tflock` unless the script exits `0`, or the user explicitly confirms `--force-unlock` after reviewing lock info.

After migrate-state, roots are often remote-only (no `terraform.tfstate`). First recovery then exits `3`: download still writes `last.terraform.tfstate` (becomes the next run’s baseline). For a clear stale lock from this machine, ask before `--force-unlock`.

### 4. Success message (required)

When the lock is removed, tell the user exactly:

> States match. Stale lock removed. You can now safely run the terraform commands again.

## Safety rules

- Never use `-lock=false` as the default fix.
- Never delete `.tflock` when remote and local state differ (unless the user explicitly requests `--force-unlock`).
- Never pass `--version-id` when downloading into `last.terraform.tfstate` — always the current object.
- Keep `last.terraform.tfstate` gitignored; do not commit state files.
- If lock `Who` is another machine/user, treat it as a real concurrent apply — do not unlock without explicit user confirmation.
