# Agent Instructions

## Keep documentation in sync

After **every** change in this repository (infrastructure, scaffolding, docs, scripts, or config templates), update `README.md` so it reflects the new state.

In particular, keep these README sections accurate:

- **Roadmap** — mark completed steps and add new planned work when scope changes
- **Technologies** — add or remove tools and AWS services when they enter or leave the stack
- **Repository structure** — mirror the real file tree after files are added, moved, or removed
- **Getting started** — update commands, paths, and prerequisites when the workflow changes
- **Architecture decisions** — keep the active / archived ADR lists accurate

Also update [`docs/architecture.md`](docs/architecture.md) whenever components are **added, removed, or rewired** (VPC layout, routing, security groups, compute, data, edge, secrets, CI). Keep Mermaid diagrams and the “current vs planned” sections accurate so the visual model matches what Terraform actually manages.

When adding or renaming AWS resources, follow [`docs/tagging-and-naming.md`](docs/tagging-and-naming.md) (`{project}-{environment}-{role}`, required tags, `Tier`). Update that doc if you introduce a new naming pattern or required tag key.

`README.md` is the primary source of truth for status and workflow; `docs/architecture.md` is the primary source of truth for system shape; `docs/tagging-and-naming.md` is the primary source of truth for resource names and tags; `docs/*-archi-decision.md` files are the source of truth for locked platform choices.

## Architecture decision documents

Architecture decisions live under `docs/` as `*-archi-decision.md` files (for example ECS vs EKS, and multi-user auth/tenancy). After any change that affects those areas—container platform, Cognito / identity, tenancy or shared-data model, related Terraform, or project structure—review the matching decision docs and update them so they stay accurate.

[`docs/architecture.md`](docs/architecture.md) is **not** a decision record: it describes the overall architecture currently (and planned) in this repository. Keep it updated when the live layout changes; put *why we chose X over Y* in an `*-archi-decision.md` file instead.

### Archiving obsolete decisions

When an architecture decision **no longer describes the current implementation** (for example a stack choice that was fully replaced):

1. **Do not delete** the decision file.
2. **Move** it to `docs/archived/` (keep the same filename).
3. **Prepend** a short archival header at the top of the file with:
   - the **date** from which the document is no longer valid;
   - **why** it is no longer valid;
   - optionally a link to any **follow-up** documentation that supersedes it (usually another `docs/*-archi-decision.md`).
4. Update `README.md` / this file so active decision lists no longer point at the archived path as current guidance (linking under an “Archived” note is fine).

Example header shape:

```markdown
> **Archived — no longer current**
>
> | | |
> | --- | --- |
> | **Invalid from** | YYYY-MM-DD |
> | **Why** | Brief reason the decision no longer matches the codebase. |
> | **Follow-up** | [Related current decision](../other-archi-decision.md) |
>
> ---
```

Current (active) decision docs:

- `docs/ecs-archi-decision.md`
- `docs/multi-user-archi-decision.md`

Archived decision docs (history only):

- _(none yet — see `docs/archived/`)_

## Minimize AWS cost

All AWS configuration in this repository must aim for the **cheapest viable setup** for a solo / early-stage project. Prefer free or near-free options unless a paid choice is clearly required.

When adding or changing resources:

- Prefer **free-tier–friendly** and low-cost defaults (small instance sizes, single NAT in `dev`, AES256 over KMS when acceptable, native S3 state locking over DynamoDB).
- Avoid always-on paid components until they are needed (NAT Gateway, ECS EC2 capacity, multi-AZ RDS, ALB, Elastic IPs left idle). Prefer ECS over EKS so there is no ~$73/mo control-plane fee (see `docs/ecs-archi-decision.md`).
- Do not enable extras that bill continuously “just in case” (extra AZs beyond what HA requires, unused public IPv4s, over-provisioned nodes).
- When several designs work, choose the lower-cost one and document the trade-off briefly in `README.md` if it affects architecture.
- Call out expensive upcoming choices in comments or the README before introducing them.
