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
| Networking | VPC, IGW, single NAT (optional), route tables, security groups, ALB (planned) |
| Database | **Amazon RDS** PostgreSQL (`db.t4g.micro`, single-AZ) |
| Frontend delivery | ECS service and/or S3 + CloudFront (TBD) |
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
- **ECS** — optional (`enable_ecs`); free control plane + Spot `t4g.small` capacity in public subnets (off by default)

**Planned**

- **ECS task definitions / services** — run frontend and backend from ECR
- **ALB** — HTTP(S) ingress to ECS services
- **S3 / CloudFront** — static frontend hosting (if not served from ECS)
- **IAM** — least-privilege roles for Terraform and workloads (instance + task execution roles exist when ECS is on)
- **Route 53** — DNS (when a public domain is configured)

## Repository structure

```
teacher-wang-infra/
├── agent.md                 # Instructions for coding agents (keep README + architecture in sync)
├── README.md                # Source of truth for status, stack, and layout
├── .gitignore               # Ignores local secrets, Terraform state, OS junk
├── config.example           # Template for local AWS credentials
├── config                   # Your secrets (gitignored) — copy from config.example
├── docs/
│   ├── architecture.md              # System diagrams (current + planned)
│   ├── architecture-choice-ecs.md   # Why ECS instead of EKS
│   └── tagging-and-naming.md        # Resource Name pattern and required tags
├── modules/
│   └── infra/               # Shared module: naming, vpc, SGs, state, rds, ecr, ecs, …
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
| `enable_ecs` | `environments/prod/main.tf` | `false` | ~$8–20/mo Spot `t4g.small` (ECS control plane is **free**) |

ECS instances use public subnets + public IP, so **NAT is not required**. To bring capacity up:

```hcl
enable_ecs = true
```

Then `terraform apply`. Set `enable_ecs = false` and apply again to destroy instances and stop the compute bill.

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
- [ ] ECS task definitions and services (frontend + backend)
- [ ] ALB ingress to ECS services

### 5. Application deployment

- [ ] Wire backend ↔ RDS (secret ARN / connection URL) and frontend ↔ backend URLs / CORS
- [ ] Frontend hosting (ECS and/or S3+CloudFront)
- [ ] Health checks and basic observability (CloudWatch)

### 6. Secrets & CI/CD

- [ ] Replace local `config` keys with IAM roles / AWS SSO / OIDC
- [ ] Store app secrets in Secrets Manager or SSM
- [ ] Pipeline to build images, push to ECR, and apply Terraform / deploy

### 7. Hardening & production readiness

- [ ] TLS certificates, custom domain
- [x] Environments layout (`environments/prod` root + `environments/common`; staging/dev TBD)
- [ ] Cost guards, monitoring alerts, least-privilege IAM review
