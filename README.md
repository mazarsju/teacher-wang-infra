> 🚧 **Work in progress** — This repository is currently under active development. See the [roadmap](#roadmap) for planned features and progress.

# teacher-wang-infra

Infrastructure-as-code repository for hosting **[teacher-wang-app](https://github.com/mazarsju/teacher-wang-app)** on AWS.

The application is composed of:

| Component | Stack (app repo) | Target hosting |
| --- | --- | --- |
| Frontend | React, TypeScript, Vite | AWS (CDN / ECS container) |
| Backend | Python, Flask, SQLAlchemy | AWS (**ECS** on EC2) |
| Database | SQLite today → managed DB in cloud | AWS RDS (PostgreSQL) |

This repo provisions and wires those pieces together with **Terraform**.

System shape (current + planned): [`docs/architecture.md`](docs/architecture.md).  
Why ECS not EKS: [`docs/architecture-choice-ecs.md`](docs/architecture-choice-ecs.md).  
Naming and tags: [`docs/tagging-and-naming.md`](docs/tagging-and-naming.md).

## Technologies

| Layer | Choice |
| --- | --- |
| IaC | Terraform (>= 1.10) |
| Cloud | Amazon Web Services (AWS) |
| Remote state | **S3** with native lock files (`use_lockfile`, no DynamoDB) |
| Orchestration | **Amazon ECS** on EC2 (Spot Graviton) — not EKS |
| Containers | **Amazon ECR** (image registry) |
| Networking | VPC, IGW, single NAT (optional), route tables, security groups, ALB |
| Database | **Amazon RDS** PostgreSQL (`db.t4g.micro`, single-AZ) |
| Frontend delivery | ECS behind ALB at **https://teacherwang.xyz** (ACM + Route 53) |
| DNS / TLS | **Route 53** hosted zone + free **ACM** cert; HTTP→HTTPS redirect |
| Secrets (now) | RDS master password in **Secrets Manager** (RDS-managed); broader secrets later |
| Credentials (now) | Local gitignored `config` file — temporary |
| Cost posture | Cheapest viable defaults (see `agent.md`) |

### AWS services

**In use**

- **S3** — Terraform remote state + native lock files (versioned, AES256, public access blocked; noncurrent versions expire after 30 days)
- **VPC** — isolated network with public and private subnets across 2 AZs (no auto-assign public IPs)
- **Internet Gateway** — public subnet default route to the internet
- **NAT Gateway** — single shared NAT in one public subnet for private outbound (toggle with `enable_nat_gateway`)
- **Security groups** — baselines for ALB (80/443), app (from ALB), and DB (5432 from app)
- **RDS** — PostgreSQL 16, `db.t4g.micro`, single-AZ, private subnets; master password in Secrets Manager
- **ECR** — private repos for backend and frontend images (AES256, scan-on-push, lifecycle retention)
- **ECS** — optional (`enable_ecs`); free control plane + Spot `t4g.small` capacity; backend/frontend task definitions and services (off by default)
- **ALB** — optional with ECS; internet-facing HTTP→HTTPS redirect + HTTPS → frontend only (backend stays off the ALB)
- **Route 53** — public hosted zone for `teacherwang.xyz` when `alb_domain_name` is set (~$0.50/mo)
- **ACM** — free public TLS certificate for `teacherwang.xyz` (DNS-validated via Route 53)

**Planned**

- **S3 / CloudFront** — static frontend hosting (if not served from ECS)
- **IAM** — least-privilege roles for Terraform and workloads (ECS instance / execution / task roles exist when ECS is on)

## Repository structure

```
teacher-wang-infra/
├── agent.md                 # Instructions for coding agents (keep README + architecture in sync)
├── README.md                # Source of truth for status, stack, and layout
├── .gitignore               # Ignores local secrets, Terraform state, OS junk
├── .cursor/skills/          # Cursor agent skills (e.g. tf state lock recovery)
├── config.example           # Template for local AWS credentials
├── config                   # Your secrets (gitignored) — copy from config.example
├── docs/
│   ├── architecture.md              # System diagrams (current + planned)
│   ├── architecture-choice-ecs.md   # Why ECS instead of EKS
│   └── tagging-and-naming.md        # Resource Name pattern and required tags
├── modules/
│   └── infra/               # Shared module: naming, vpc, SGs, state, rds, ecr, ecs, alb, route53, …
└── environments/
    ├── common/              # Shared defaults module (project, region, AZ count)
    └── prod/                # Prod root — cd here and run terraform plan/apply
        ├── backend.tf
        ├── backend.hcl.example
        ├── main.tf          # wires module.common + module.infra
        ├── providers.tf
        ├── versions.tf
        └── outputs.tf
```

Add `environments/staging` or `environments/dev` later with the same root layout as `prod`.

## Getting started

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.10 (needed for S3 `use_lockfile`)
- An AWS account and IAM user/role with permissions to create the resources you plan to manage
- AWS CLI optional but useful for debugging (`aws sts get-caller-identity`)

### Configure credentials (temporary)

```bash
cp config.example config
# Edit `config` with your AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and region
source ./config
```

`config` is gitignored. Do not commit real keys. A safer approach (SSO, roles, CI OIDC) is planned in the roadmap.

### Bootstrap remote state (first time only)

The state bucket cannot exist before the first apply, so bootstrap is two steps. Run them from the environment root (e.g. `environments/prod`):

```bash
source ../../config   # from environments/prod
cd environments/prod

# 1. Create the state bucket with local state (skip remote backend briefly)
mv backend.tf backend.tf.disabled
terraform init -reconfigure
terraform apply
mv backend.tf.disabled backend.tf

# 2. Point the backend at the new bucket and migrate state
cp backend.hcl.example backend.hcl
# Set bucket to the value of: terraform output -raw terraform_state_bucket
terraform init -backend-config=backend.hcl -migrate-state -force-copy
```

After migration, local `terraform.tfstate` is no longer used; state lives in:

- Bucket: `teacher-wang-tfstate-<aws_account_id>` (versioned, encrypted, private)
- Key: `teacher-wang/terraform.tfstate`
- Locking: native S3 lock file (`.tflock`) via `use_lockfile = true`

### Day-to-day usage

Each environment folder is a full Terraform root. From the repo root:

```bash
source ./config
cd environments/prod
terraform init -backend-config=backend.hcl   # first time / after backend changes
terraform plan
terraform apply
terraform output
```

No `-var-file` flags needed: prod values live in `environments/prod/main.tf`; shared defaults come from `environments/common`.

### Public HTTPS (`teacherwang.xyz`)

Prod sets `alb_domain_name = "teacherwang.xyz"`. The domain is registered at **Namecheap**; Terraform provisions a Route 53 hosted zone and a free ACM certificate. The ALB HTTPS listener and apex alias appear when `enable_ecs = true`.

1. Domain **`teacherwang.xyz`** is already registered at Namecheap.
2. Apply Terraform (zone + ACM validation records can be created even with ECS off):

```bash
source ./config
cd environments/prod
terraform apply
terraform output route53_name_servers
```

3. In Namecheap (Domain List → Manage → Nameservers → Custom DNS), set nameservers to the `route53_name_servers` output (one-time).
4. Wait for NS delegation; ACM validation may take a few minutes (apply can wait up to 45m on `aws_acm_certificate_validation`).
5. Turn on the app (`enable_ecs = true`), apply again → HTTPS listener + `A` alias → open **https://teacherwang.xyz** (HTTP redirects to HTTPS).
6. AnkiConnect: keep `webCorsOriginList: ["*"]` or add `https://teacherwang.xyz`.

### Push images to ECR (from teacher-wang-app)

Repos are region-account scoped. ECS capacity uses **Graviton (`t4g`)** — build **`linux/arm64`**. On an Apple Silicon Mac (M3) that is the native arch.

```bash
# From teacher-wang-infra (once): copy registry URLs
cd environments/prod
source ../../config
export AWS_REGION="$(terraform output -raw aws_region)"
export ECR_BACKEND="$(terraform output -raw ecr_backend_repository_url)"
export ECR_FRONTEND="$(terraform output -raw ecr_frontend_repository_url)"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$(echo "$ECR_BACKEND" | cut -d/ -f1)"
```

Then from **teacher-wang-app** (adjust Dockerfile paths if different):

```bash
# Backend
docker buildx build --platform linux/arm64 \
  -t "$ECR_BACKEND:latest" \
  -f path/to/backend/Dockerfile \
  --push .

# Frontend
docker buildx build --platform linux/arm64 \
  -t "$ECR_FRONTEND:latest" \
  -f path/to/frontend/Dockerfile \
  --push .
```

Prefer a git SHA tag in addition to `:latest` once you deploy for real (`-t "$ECR_BACKEND:$(git rev-parse --short HEAD)"`).

### Toggle expensive components

Prod defaults keep always-on paid pieces **off**:

| Flag | File | Default | Approx. cost when on |
| --- | --- | --- | --- |
| `enable_nat_gateway` | `environments/prod/main.tf` | `false` | ~$32/mo + data |
| `enable_ecs` | `environments/prod/main.tf` | `false` | ~$8–20/mo Spot `t4g.small` + **~$16/mo ALB** (ECS control plane is **free**) |

ECS instances use public subnets + public IP, so **NAT is not required**. Push **`linux/arm64`** images to ECR **before** (or immediately after) enabling services, or tasks will fail to pull.

```hcl
enable_ecs = true
```

Then `terraform apply`. Set `enable_ecs = false` and apply again to destroy instances/services/**ALB** and stop those bills.

When enabled, Terraform also creates:

| Service | Exposure | Host port | Resources |
| --- | --- | --- | --- |
| Frontend | **Public** via ALB `:80` → target group | 8080 | 256 CPU / 256 MiB |
| Backend | **VPC-local only** (not on the ALB) | 5000 | 512 CPU / 512 MiB |

- Frontend URL: `http://$(terraform output -raw alb_dns_name)`
- Backend receives `DB_*` / `DB_PASSWORD`; frontend receives `BACKEND_UPSTREAM` (`http://172.17.0.1:5000`) for a same-host reverse proxy (browser must not call the API directly).

See [`docs/architecture-choice-ecs.md`](docs/architecture-choice-ecs.md) for why this is preferred over EKS.

## Roadmap

### 1. Repository & AWS bootstrap

- [x] Initialize infra repo with README, `agent.md`, and `.gitignore`
- [x] Terraform scaffolding (`versions`, `providers`, `variables`, bootstrap outputs)
- [x] Local AWS credentials via gitignored `config` (temporary)
- [x] Validate `terraform init` / `plan` against a real AWS account
- [x] Remote state on S3 with native S3 locking (`use_lockfile`)

### 2. Networking foundation

- [x] VPC, public/private subnets across AZs
- [x] NAT, route tables, security group baselines (single NAT for cost; `enable_nat_gateway` to toggle)
- [x] Tagging and naming conventions (`docs/tagging-and-naming.md`, `local.name_prefix`)

### 3. Data layer

- [x] RDS PostgreSQL (cheap sizing: `db.t4g.micro`, single-AZ, private, Secrets Manager password)
- [ ] Backup / retention policy (currently 1-day automated backups — free-tier max)

Schema / migrations from the app’s SQLite models → Postgres live in **[teacher-wang-app](https://github.com/mazarsju/teacher-wang-app)** (DB URL config + Alembic); this repo only provisions the empty database.

### 4. Container platform

- [x] ECR repositories for backend and frontend
- [x] ECS cluster + EC2 Spot capacity (gated by `enable_ecs`, default off; no EKS)
- [x] ECS task definitions and services (frontend + backend)
- [x] ALB ingress (public frontend only; backend VPC-local)
- [x] HTTPS on ALB (`teacherwang.xyz` via ACM + Route 53; HTTP→HTTPS)

### 5. Application deployment

- [ ] Wire backend ↔ RDS (secret ARN / connection URL) and frontend ↔ backend proxy / CORS
- [ ] Frontend hosting extras (S3+CloudFront if leaving ECS)
- [ ] Health checks and basic observability (CloudWatch)

### 6. Secrets & CI/CD

- [ ] Replace local `config` keys with IAM roles / AWS SSO / OIDC
- [ ] Store app secrets in Secrets Manager or SSM
- [ ] Pipeline to build images, push to ECR, and apply Terraform / deploy

### 7. Hardening & production readiness

- [x] TLS certificates + custom domain (`teacherwang.xyz`)
- [x] Environments layout (`environments/prod` root + `environments/common`; staging/dev TBD)
- [ ] Cost guards, monitoring alerts, least-privilege IAM review
