# Tagging and naming conventions

Source of truth for how AWS resources are named and tagged in this repository.
Follow these rules when adding or changing infrastructure.

This is a **conventions** doc, not an architecture decision record. Platform choices live in `docs/*-archi-decision.md`; the living AWS layout is in [`architecture.md`](architecture.md).

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

Implemented in Terraform as `local.name_prefix = "${var.project_name}-${var.environment}"` in `modules/aws/naming.tf`.

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
| DB subnet group | `teacher-wang-prod-db` |
| RDS PostgreSQL | `teacher-wang-prod-postgres` |
| ECR backend | `teacher-wang-prod-backend` |
| ECR frontend | `teacher-wang-prod-frontend` |
| ECS cluster | `teacher-wang-prod-ecs` |
| ECS capacity provider | `teacher-wang-prod-ec2` |
| ECS instance IAM role / profile | `teacher-wang-prod-ecs-instance` |
| ECS task execution IAM role | `teacher-wang-prod-ecs-exec` |
| ECS task IAM role | `teacher-wang-prod-ecs-task` |
| ECS backend service / task family | `teacher-wang-prod-backend` |
| ECS frontend service / task family | `teacher-wang-prod-frontend` |
| ALB | `teacher-wang-prod-alb` |
| ALB frontend target group | `teacher-wang-prod-frontend` |
| CloudFront distribution (Name tag) | `teacher-wang-prod-cdn` |
| Maintenance S3 bucket | `teacher-wang-prod-maintenance-<account_id>` |
| Conversation logs S3 bucket | `teacher-wang-prod-conversation-logs-<account_id>` |
| Route 53 zone (Name tag) | `teacher-wang-prod-dns` |
| ACM certificate ALB (Name tag) | `teacher-wang-prod-alb-cert` |
| ACM certificate CloudFront (Name tag) | `teacher-wang-prod-cloudfront-cert` (us-east-1) |
| Cognito user pool | `teacher-wang-prod-users` |
| Cognito app client | `teacher-wang-prod-app` |
| Cognito domain prefix | `teacher-wang-prod-<account_id>` |
| Cognito Pre Sign-up Lambda | `teacher-wang-prod-cognito-pre-signup` |
| Cognito Google OAuth secret (when enabled via TF_VAR) | `teacher-wang-prod-cognito-google` |
| GCP project | `teacher-wang` (Google Cloud project id) |

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
| `public` | Public subnets, public route tables, ALB SG, Route 53 zone, ACM cert |
| `private` | Private subnets, private route tables, app SG |
| `data` | Database SG, DB subnet group, RDS |
| `shared` | Account-level or registry resources (state bucket, ECR) |

### What not to tag

- Individual security group **rules** — they inherit `default_tags`; no custom `Name` needed.
- Route table **associations** and plain **routes** — not useful in the console.

## TLS / DNS

- Domain: `teacherwang.xyz` (`alb_domain_name` in prod), registered at **Namecheap**.
- Route 53 public hosted zone + ACM DNS validation + apex alias to the ALB.
- ALB `:443` HTTPS listener (TLS 1.2/1.3 policy); `:80` redirects to HTTPS when the domain is configured.
- After creating the zone, in Namecheap set Custom DNS nameservers to Terraform output `route53_name_servers`.

Prefer explicit Terraform subnet IDs for the ALB over controller-style subnet tags.

## Checklist for new resources

1. Name via `"${local.name_prefix}-…"` (or the shared-bucket exception).
2. Set `Name` tag (same as AWS `name` when both exist).
3. Set `Tier` when the resource belongs to a network/security tier.
4. Rely on provider `default_tags` for `Project` / `Environment` / `ManagedBy`.
5. Update this doc if you introduce a new naming pattern or required tag key.
