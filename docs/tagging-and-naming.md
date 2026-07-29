# Tagging and naming conventions

Source of truth for how AWS resources are named and tagged in this repository.
Follow these rules when adding or changing infrastructure.

## Naming

### Pattern

```text
{project}-{environment}-{role}[-{qualifier}]
```

| Part | Rules | Example |
| --- | --- | --- |
| `project` | lowercase, digits, hyphens; starts with a letter | `teacher-wang` |
| `environment` | same charset (`prod`, later `staging` / `dev`) | `prod` |
| `role` | short resource purpose | `vpc`, `alb`, `nat`, `public` |
| `qualifier` | optional (AZ, suffix) | `eu-west-1a`, `eip`, `rt` |

Implemented in Terraform as `local.name_prefix = "${var.project_name}-${var.environment}"` in `modules/infra/naming.tf`.

### Examples

| Resource | Name |
| --- | --- |
| VPC | `teacher-wang-prod-vpc` |
| Public subnet | `teacher-wang-prod-public-eu-west-1a` |
| Private subnet | `teacher-wang-prod-private-eu-west-1a` |
| IGW | `teacher-wang-prod-igw` |
| NAT Gateway | `teacher-wang-prod-nat` |
| NAT EIP | `teacher-wang-prod-nat-eip` |
| Public route table | `teacher-wang-prod-public-rt` |
| Private route table | `teacher-wang-prod-private-rt` |
| ALB security group | `teacher-wang-prod-alb` |
| App security group | `teacher-wang-prod-app` |
| DB security group | `teacher-wang-prod-db` |

### Exceptions

| Resource | Pattern | Why |
| --- | --- | --- |
| Terraform state bucket | `{project}-tfstate-{account_id}` | Account-scoped, shared by all environments |

### Rules

- Prefer **hyphen-separated lowercase**; no underscores in AWS `Name` values.
- When a resource has an AWS `name` attribute (e.g. security groups), set **`name` and the `Name` tag to the same value**.
- Do not encode region in the name unless needed for disambiguation (AZ is enough for subnets).
- Keep names stable: renaming AWS `name` on security groups forces replacement.

## Tagging

### Required (provider `default_tags`)

Applied automatically to every taggable resource from each environment root (`environments/*/providers.tf`):

| Key | Value | Purpose |
| --- | --- | --- |
| `Project` | `teacher-wang` | Cost / ownership filter |
| `Environment` | `prod` (per root) | Isolate envs in consoles and billing |
| `ManagedBy` | `terraform` | Distinguish IaC-managed resources |

### Resource tags

| Key | When | Values |
| --- | --- | --- |
| `Name` | **Always** on taggable resources | Follows the naming pattern above |
| `Tier` | Network / security tiers | `public`, `private`, `data`, `shared` |

Extra tags can be passed into the infra module via `additional_tags` and are merged with `Name` / `Tier`.

### Tier meanings

| Tier | Used for |
| --- | --- |
| `public` | Public subnets, public route tables, ALB SG |
| `private` | Private subnets, private route tables, app SG |
| `data` | Database SG (and later RDS) |
| `shared` | Account-level resources (state bucket) |

### What not to tag

- Individual security group **rules** — they inherit `default_tags`; no custom `Name` needed.
- Route table **associations** and plain **routes** — not useful in the console.

## Future (EKS / ALB)

When adding Kubernetes and load balancers, also apply AWS/controller conventions where required, for example:

- `kubernetes.io/role/elb` / `kubernetes.io/role/internal-elb` on subnets
- `kubernetes.io/cluster/<cluster-name> = shared|owned`

Those are additive and must not replace the tags above.

## Checklist for new resources

1. Name via `"${local.name_prefix}-…"` (or the shared-bucket exception).
2. Set `Name` tag (same as AWS `name` when both exist).
3. Set `Tier` when the resource belongs to a network/security tier.
4. Rely on provider `default_tags` for `Project` / `Environment` / `ManagedBy`.
5. Update this doc if you introduce a new naming pattern or required tag key.
