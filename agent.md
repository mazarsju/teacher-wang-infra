# Agent Instructions

## Keep documentation in sync

After **every** change in this repository (infrastructure, scaffolding, docs, scripts, or config templates), update `README.md` so it reflects the new state.

In particular, keep these README sections accurate:

- **Roadmap** — mark completed steps and add new planned work when scope changes
- **Technologies** — add or remove tools and AWS services when they enter or leave the stack
- **Repository structure** — mirror the real file tree after files are added, moved, or removed
- **Getting started** — update commands, paths, and prerequisites when the workflow changes

Also update [`docs/architecture.md`](docs/architecture.md) whenever components are **added, removed, or rewired** (VPC layout, routing, security groups, compute, data, edge, secrets, CI). Keep Mermaid diagrams and the “current vs planned” sections accurate so the visual model matches what Terraform actually manages. Platform decisions (e.g. ECS vs EKS) belong in [`docs/architecture-choice-ecs.md`](docs/architecture-choice-ecs.md) (or a sibling decision doc) and should be linked from the README.

When adding or renaming AWS resources, follow [`docs/tagging-and-naming.md`](docs/tagging-and-naming.md) (`{project}-{environment}-{role}`, required tags, `Tier`). Update that doc if you introduce a new naming pattern or required tag key.

`README.md` is the primary source of truth for status and workflow; `docs/architecture.md` is the primary source of truth for system shape; `docs/tagging-and-naming.md` is the primary source of truth for resource names and tags.

## Minimize AWS cost

All AWS configuration in this repository must aim for the **cheapest viable setup** for a solo / early-stage project. Prefer free or near-free options unless a paid choice is clearly required.

When adding or changing resources:

- Prefer **free-tier–friendly** and low-cost defaults (small instance sizes, single NAT in `dev`, AES256 over KMS when acceptable, native S3 state locking over DynamoDB).
- Avoid always-on paid components until they are needed (NAT Gateway, ECS EC2 capacity, multi-AZ RDS, ALB, Elastic IPs left idle). Prefer ECS over EKS so there is no ~$73/mo control-plane fee (see `docs/architecture-choice-ecs.md`).
- Do not enable extras that bill continuously “just in case” (extra AZs beyond what HA requires, unused public IPv4s, over-provisioned nodes).
- When several designs work, choose the lower-cost one and document the trade-off briefly in `README.md` if it affects architecture.
- Call out expensive upcoming choices in comments or the README before introducing them.
