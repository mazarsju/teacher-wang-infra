> 🚧 **Work in progress** — This repository is currently under active development. See the [roadmap](#roadmap) for planned features and progress.

# teacher-wang-infra

Infrastructure-as-code repository for hosting **[teacher-wang-app](https://github.com/mazarsju/teacher-wang-app)** on AWS.

The application is composed of:

| Component | Stack (app repo) | Target hosting |
| --- | --- | --- |
| Frontend | React, TypeScript, Vite | AWS (CDN / ECS container) |
| Backend | Python, Flask, SQLAlchemy | AWS (**ECS** on EC2) |
| Database | PostgreSQL | AWS RDS (PostgreSQL) |

This repo provisions and wires those pieces together with **Terraform**.

System shape (current + planned): [`docs/architecture.md`](docs/architecture.md).  
Naming and tags: [`docs/tagging-and-naming.md`](docs/tagging-and-naming.md).

## Architecture decisions

Longer design notes live under `docs/` as `*-archi-decision.md` (see `agent.md` for archiving rules):

- [ECS instead of EKS](docs/ecs-archi-decision.md) — Graviton on ECS (on-demand in prod); no EKS control-plane fee
- [Multi-user auth & tenancy](docs/multi-user-archi-decision.md) — Cognito; shared schema + RLS + partitions; shared read-only catalog

Obsolete decisions are kept under [`docs/archived/`](docs/archived/) (none yet).

## Technologies

| Layer | Choice |
| --- | --- |
| IaC | Terraform (>= 1.10) |
| Cloud | **AWS** (app hosting) + **GCP** (Google OAuth project for SSO) |
| Remote state | **S3** with native lock files (`use_lockfile`, no DynamoDB) |
| Orchestration | **Amazon ECS** on EC2 (Graviton; on-demand in prod) — not EKS |
| Containers | **Amazon ECR** (image registry) |
| Networking | VPC, IGW, single NAT (optional), route tables, security groups, ALB |
| Database | **Amazon RDS** PostgreSQL (`db.t4g.micro`, single-AZ) |
| Frontend delivery | ECS behind ALB, public via **CloudFront** at **https://teacherwang.xyz** |
| DNS / TLS | **Route 53** → CloudFront (ACM us-east-1); ALB is the CDN origin |
| Identity | **Amazon Cognito** User Pool (password + Google IdP) |
| Google SSO project | GCP project `teacher-wang` (module.gcp); OAuth Web client via Console |
| Secrets (now) | RDS master password + **LLM API key** in **Secrets Manager**; Google OAuth via `TF_VAR_*` |
| Credentials (now) | Local gitignored `config` + gcloud ADC for GCP |
| Cost posture | Cheapest viable defaults (see `agent.md`) |

### AWS services

**In use**

- **S3** — Terraform remote state + native lock files (versioned, AES256, public access blocked; noncurrent versions expire after 30 days)
- **VPC** — isolated network with public and private subnets across 2 AZs (no auto-assign public IPs)
- **Internet Gateway** — public subnet default route to the internet
- **NAT Gateway** — single shared NAT in one public subnet for private outbound (toggle with `enable_nat_gateway`)
- **Security groups** — ALB (80/443 public; origin gated by `X-Origin-Verify` on listeners), app (from ALB), and DB (5432 from app)
- **RDS** — PostgreSQL 16, `db.t4g.micro`, single-AZ, private subnets; master password in Secrets Manager
- **ECR** — private repos for backend and frontend images (AES256, scan-on-push, lifecycle retention)
- **ECS** — optional (`enable_ecs`); free control plane + `t4g.small` capacity (`ecs_use_spot = false` in prod for availability); backend/frontend task definitions and services (off by default); instance role includes SSM for local RDS port-forwarding
- **SSM Session Manager** — free; tunnel to private RDS via the ECS host (no bastion, RDS stays non-public)
- **ALB** — optional with ECS; CloudFront origin on :80 → frontend only (backend stays off the ALB)
- **CloudFront** — apex HTTPS for `teacherwang.xyz`; on ALB 502/503/504 serves a styled maintenance page from S3
- **S3 (maintenance)** — private bucket + OAC for `maintenance.html` (Welcome Auth–style static page)
- **S3 (conversation logs)** — private bucket for per-user chat transcripts (`users/{cognito_sub}/…`); ECS task role can read/write objects under `users/`
- **Cognito admin delete** — ECS task role can call `cognito-idp:AdminDeleteUser` on the app User Pool (needed by backend `DELETE /admin/users/<id>`)
- **Route 53** — public hosted zone for `teacherwang.xyz` when `alb_domain_name` is set (~$0.50/mo); apex → CloudFront
- **ACM** — free certs for ALB (`eu-west-1`) and CloudFront (`us-east-1`), DNS-validated via Route 53
- **Cognito** — User Pool + public app client + Hosted UI domain; optional Google IdP when `TF_VAR_cognito_google_client_*` are set; ECS tasks get `COGNITO_*` env
- **Secrets Manager** — RDS master password (RDS-managed); optional Google OAuth JSON; **LLM API key** (`TF_VAR_llm_api_key`) injected into the backend task as `LLM_API_KEY`
- **Lambda (Cognito Pre Sign-up)** — enforces unique email; links Google SSO to an existing password user with the same email (`AdminLinkProviderForUser`); publishes to SNS on every genuinely new user
- **SNS** — `cognito-new-user` topic; email subscription (`mazarsju@gmail.com`) alerts on new Cognito sign-ups (native or first-time Google)

**GCP (Google SSO)**

- **Project** `teacher-wang` — created/linked by `module.gcp` with billing account `01FAA2-0A2C47-146756`
- **APIs** — Resource Manager, Service Usage, IAM, Billing, People (profile attributes)
- **OAuth Web client** — created once in Console (not API-automatable); checklist via `terraform output gcp_oauth_setup_checklist`

**Planned**

- **IAM** — further least-privilege for Terraform operators (ECS instance role already has ECS + SSM; execution / task roles exist when ECS is on)

## Repository structure

```
teacher-wang-infra/
├── AGENTS.md                # Instructions for coding agents (keep README + architecture in sync)
├── CLAUDE.md                # Claude Code entry point (imports AGENTS.md)
├── README.md                # Source of truth for status, stack, and layout
├── .gitignore               # Ignores local secrets, Terraform state, OS junk
├── .cursor/skills/          # Cursor agent skills (e.g. tf state lock recovery)
├── .claude/skills/          # Same agent skills, packaged for Claude Code
├── config.example           # Template for local AWS / LLM / Google TF_VAR secrets
├── config                   # Your secrets (gitignored) — copy from config.example
├── docs/
│   ├── architecture.md                       # Living system overview (current + planned)
│   ├── ecs-archi-decision.md                 # Why ECS instead of EKS
│   ├── multi-user-archi-decision.md          # Cognito + shared-schema tenancy
│   ├── tagging-and-naming.md                 # Resource Name pattern and required tags
│   └── archived/                             # Obsolete *-archi-decision.md files
├── modules/
│   ├── aws/                 # AWS: naming, vpc, SGs, state, rds, ecr, cognito, llm, ecs, alb, …
│   └── gcp/                 # GCP: project, billing, APIs + OAuth Console checklist for Google SSO
└── environments/
    ├── common/              # Shared defaults module (project, region, AZ count)
    └── prod/                # Prod root — cd here and run terraform plan/apply
        ├── backend.tf
        ├── backend.hcl.example
        ├── main.tf          # wires module.common + module.aws + module.gcp
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
- [gcloud](https://cloud.google.com/sdk/docs/install) for GCP Google SSO (`mazarsju@gmail.com` + ADC)

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

Prod sets `alb_domain_name = "teacherwang.xyz"`. The domain is registered at **Namecheap**; Terraform provisions a Route 53 hosted zone and free ACM certificates (regional + `us-east-1` for CloudFront). When `enable_ecs = true`, apex DNS points at CloudFront; the ALB is the origin. ECS deploys that briefly return 502/503/504 show the S3 maintenance page instead of a raw ALB error.

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
# Backend — disable attestations so multi-tag pushes cannot leave :latest on a provenance stub
docker buildx build --platform linux/arm64 --provenance=false --sbom=false \
  -t "$ECR_BACKEND:latest" \
  -f path/to/backend/Dockerfile \
  --push .

# Frontend
docker buildx build --platform linux/arm64 --provenance=false --sbom=false \
  -t "$ECR_FRONTEND:latest" \
  -f path/to/frontend/Dockerfile \
  --push .
```

Prefer the app-repo wrapper (`.cursor/skills/update-ecr-images/scripts/push.sh`) or `scripts/push-ecr.sh` — both pass those flags and also tag `:<git-sha>`. After push, force a new ECS deployment (the wrapper does this); pushing `:latest` alone does not restart tasks.

### Toggle expensive components

Prod defaults keep always-on paid pieces **off**:

| Flag | File | Default | Approx. cost when on |
| --- | --- | --- | --- |
| `enable_nat_gateway` | `environments/prod/main.tf` | `false` | ~$32/mo + data |
| `enable_ecs` | `environments/prod/main.tf` | `false` | ~$12–15/mo on-demand `t4g.small` + **~$16/mo ALB** (ECS control plane is **free**) |
| `ecs_use_spot` | `environments/prod/main.tf` | `false` (prod) | Spot saves ~30–50% on the instance but can be interrupted (caused a prod outage) |

ECS instances use public subnets + public IP, so **NAT is not required**. Push **`linux/arm64`** images to ECR **before** (or immediately after) enabling services, or tasks will fail to pull.

```hcl
enable_ecs = true
```

Then `terraform apply`. Set `enable_ecs = false` and apply again to destroy instances/services/**ALB** and stop those bills.

When enabled, Terraform also creates:

| Service | Exposure | Host port | Resources |
| --- | --- | --- | --- |
| Frontend | **Public** via CloudFront → ALB `:80` → target group | 8080 | 256 CPU / 256 MiB |
| Backend | **VPC-local only** (not on the ALB) | 5000 | 512 CPU / 512 MiB |

- Frontend URL: `http://$(terraform output -raw alb_dns_name)`
- Backend receives `DB_*` / `DB_PASSWORD` and `COGNITO_*` (pool id, client id, issuer, region); frontend receives `BACKEND_UPSTREAM` (`http://172.17.0.1:5000`) plus public Cognito ids for a future SPA login.

See [`docs/ecs-archi-decision.md`](docs/ecs-archi-decision.md) for why this is preferred over EKS.

### Connect to RDS from your laptop (SSM tunnel)

RDS is private (`publicly_accessible = false`) and only accepts `5432` from the app SG. Do **not** open it to the internet. With `enable_ecs = true`, tunnel through the ECS EC2 host via Session Manager (no bastion, no NAT required — instances already have a public IP for SSM).

**Prerequisites**

- [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the AWS CLI
- ECS capacity running and registered in SSM (`aws ssm describe-instance-information`)
- Your IAM user/role can call `ssm:StartSession`

```bash
cd environments/prod

NAME_TAG=$(terraform output -raw ecs_instance_name_tag)
RDSHOST=$(terraform output -raw db_address)
SECRET_ARN=$(terraform output -raw db_master_user_secret_arn)
DBNAME=$(terraform output -raw db_name)

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${NAME_TAG}" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Terminal A — keep the tunnel open (use 15432 locally so a laptop Postgres on 5432 does not win)
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${RDSHOST}\"],\"portNumber\":[\"5432\"],\"localPortNumber\":[\"15432\"]}"

# Terminal B — connect via localhost (sslmode=require; verify-full fails against 127.0.0.1)
psql "host=127.0.0.1 port=15432 dbname=${DBNAME} user=teacherwang sslmode=require password=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text | jq -r '.password')"
```

After the first apply that attaches `AmazonSSMManagedInstanceCore`, wait a minute for the instance to appear in SSM. If it never shows up, reboot the ECS instance once.

### Cognito (end-user identity)

Always provisioned (near-free under Cognito MAU free tier). After apply:

```bash
cd environments/prod
terraform output cognito_user_pool_id
terraform output cognito_app_client_id
terraform output cognito_issuer
terraform output cognito_hosted_ui_base_url
```

**Google SSO / GCP**

Terraform manages the **GCP project** (`teacher-wang`) + billing + APIs via `module.gcp`.  
Google no longer allows creating classic OAuth Web clients via API/Terraform — create the client once in Console, then wire secrets into Cognito.

1. Authenticate as **mazarsju@gmail.com** (not a work account):

```bash
gcloud auth login mazarsju@gmail.com
gcloud config set account mazarsju@gmail.com
gcloud config set project teacher-wang
gcloud auth application-default login
```

2. Apply infra (creates/links GCP project + prints checklist):

```bash
source ./config
cd environments/prod
terraform init   # picks up the google provider
terraform apply
terraform output -raw gcp_oauth_setup_checklist
terraform output -raw cognito_google_redirect_uri
```

If project `teacher-wang` already exists (typical): leave `gcp_create_project = false` (default).  
Terraform will **not** try to create it again (avoids `409 alreadyExists`); it only links billing + enables APIs.

To create a *new* project id with Terraform instead: set `gcp_create_project = true`.

3. In Google Cloud Console (credentials page from `gcp_oauth_console_url`):
   - OAuth consent screen: External, app **Teacher Wang**, support **mazarsju@gmail.com**
   - OAuth client ID → **Web application**
   - Redirect URI = `cognito_google_redirect_uri` output (exact)
   - Origins: `https://teacherwang.xyz`, `http://localhost:5173`

4. Enable Cognito Google IdP:

```bash
export TF_VAR_cognito_google_client_id="...."
export TF_VAR_cognito_google_client_secret="...."
terraform apply
terraform output cognito_google_enabled   # expect true
```

Password auth works without Google. Flask verifies access tokens via JWKS (`GET /auth/me` in the app).

**Same email = same user:** a Pre Sign-up Lambda rejects duplicate emails on classic sign-up and, when Google SSO uses an email that already exists, links Google to that Cognito user (`AdminLinkProviderForUser`) instead of creating a second profile. The Cognito `sub` stays the original user’s. The first Google attempt after linking may fail with `EXTERNAL_PROVIDER_LINKED` — sign in with Google once more. If a stray `Google_*` user was created before this Lambda existed, delete that orphan in the Cognito console.

### Backend LLM secrets

The backend task gets `LLM_MODEL` as a plain env var (default `gpt-5.6-luna`) and `LLM_API_KEY` from Secrets Manager.

```bash
# In gitignored `config` (see config.example), then:
source ./config
export TF_VAR_llm_api_key="sk-...."
# optional: export TF_VAR_llm_model="gpt-5.6-luna"
cd environments/prod
terraform apply
```

Alternative: create the secret yourself and set `TF_VAR_llm_api_key_secret_arn` instead of the key value.

## Roadmap

### 1. Repository & AWS bootstrap

- [x] Initialize infra repo with README, `agent.md`, and `.gitignore`
- [x] Terraform scaffolding (`versions`, `providers`, `variables`, bootstrap outputs)
- [x] Environments layout (`environments/prod` root + `environments/common`)
- [x] Local AWS credentials via gitignored `config` (temporary)
- [x] Validate `terraform init` / `plan` against a real AWS account
- [x] Remote state on S3 with native S3 locking (`use_lockfile`)

### 2. Networking foundation

- [x] VPC, public/private subnets across AZs
- [x] NAT, route tables, security group baselines (single NAT for cost; `enable_nat_gateway` to toggle)
- [x] Tagging and naming conventions (`docs/tagging-and-naming.md`, `local.name_prefix`)

### 3. Data layer

- [x] RDS PostgreSQL (cheap sizing: `db.t4g.micro`, single-AZ, private, Secrets Manager password)
- [x] Local RDS access via SSM port-forward through the ECS host (no public RDS / bastion)
- [ ] Backup / retention policy (currently 1-day automated backups — free-tier max)

Schema / migrations live in **[teacher-wang-app](https://github.com/mazarsju/teacher-wang-app)** (DB URL config + Alembic); this repo only provisions the empty PostgreSQL database.

### 4. Container platform

- [x] ECR repositories for backend and frontend
- [x] ECS cluster + EC2 capacity (gated by `enable_ecs`, default off; prod uses on-demand via `ecs_use_spot = false`; no EKS)
- [x] ECS task definitions and services (frontend + backend)
- [x] ALB ingress (public frontend only; backend VPC-local)
- [x] Task env wiring: backend `DB_*` / `DB_PASSWORD`, frontend `BACKEND_UPSTREAM`

App runtime integration (DB connection, reverse-proxy to `BACKEND_UPSTREAM`, CORS) lives in **[teacher-wang-app](https://github.com/mazarsju/teacher-wang-app)** — infra already injects the env vars.

### 5. Public DNS & TLS

- [x] Route 53 hosted zone + apex alias for `teacherwang.xyz`
- [x] ACM certificate (DNS validation) and ALB HTTPS listener
- [x] CloudFront in front of ALB (viewer HTTPS) + S3 maintenance page on origin 5xx

### 6. Multi-user auth & data isolation _(in progress)_

Decision record: [`docs/multi-user-archi-decision.md`](docs/multi-user-archi-decision.md) (Cognito; shared schema + RLS + partitions; shared read-only catalog).

- [x] Choose identity + tenancy + shared-data model
- [x] Provision Cognito (user pool, app client, optional Google IdP) and wire `COGNITO_*` into ECS
- [x] App JWT verification (Cognito JWKS) + `GET /auth/me` probe — in [teacher-wang-app](https://github.com/mazarsju/teacher-wang-app)
- [x] GCP project `teacher-wang` + billing + APIs (`module.gcp`) for Google SSO scaffolding
- [ ] Create Google OAuth Web client in Console → `TF_VAR_cognito_google_client_*` → `cognito_google_enabled = true`
- [ ] App schema: per-user private tables (`user_id` + RLS + partitions) + shared read-only catalog; `app` / `migrator` DB roles

### 7. Secrets & CI/CD _(later)_

- [ ] Replace local `config` keys with IAM roles / AWS SSO / OIDC
- [x] Store app secrets in Secrets Manager (`LLM_API_KEY`; RDS + Google OAuth already)
- [ ] Pipeline to build images, push to ECR, and apply Terraform / deploy

### 8. Observability _(later)_

- [ ] Health checks on ALB / ECS tasks
- [ ] Basic CloudWatch dashboards and alarms

### 9. Hardening & cost _(later)_

- [ ] Cost guards, budgets / alerts
- [ ] Least-privilege IAM review
- [ ] Additional environments (`staging` / `dev`)