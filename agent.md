# Agent Instructions

## Keep documentation in sync

After **every** change in this repository (infrastructure, scaffolding, docs, scripts, or config templates), update `README.md` so it reflects the new state.

In particular, keep these README sections accurate:

- **Roadmap** — mark completed steps and add new planned work when scope changes
- **Technologies** — add or remove tools and AWS services when they enter or leave the stack
- **Repository structure** — mirror the real file tree after files are added, moved, or removed
- **Getting started** — update commands, paths, and prerequisites when the workflow changes

`README.md` is the primary source of truth for humans and agents working in this repo.

## Minimize AWS cost

All AWS configuration in this repository must aim for the **cheapest viable setup** for a solo / early-stage project. Prefer free or near-free options unless a paid choice is clearly required.

When adding or changing resources:

- Prefer **free-tier–friendly** and low-cost defaults (small instance sizes, single NAT in `dev`, AES256 over KMS when acceptable, native S3 state locking over DynamoDB).
- Avoid always-on paid components until they are needed (NAT Gateway, EKS control plane, multi-AZ RDS, ALB, Elastic IPs left idle).
- Do not enable extras that bill continuously “just in case” (extra AZs beyond what HA requires, unused public IPv4s, over-provisioned nodes).
- When several designs work, choose the lower-cost one and document the trade-off briefly in `README.md` if it affects architecture.
- Call out expensive upcoming choices in comments or the README before introducing them.
