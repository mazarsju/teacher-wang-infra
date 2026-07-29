> 🚧 **Work in progress** — This repository is currently under active development. See the [roadmap](#roadmap) for planned features and progress.

# teacher-wang-infra

Infrastructure-as-code repository for hosting **[teacher-wang](https://github.com/mazarsju/teacher-wang)** on AWS.

The application is composed of:

| Component | Stack (app repo) | Target hosting |
| --- | --- | --- |
| Frontend | React, TypeScript, Vite | AWS (CDN / container) |
| Backend | Python, Flask, SQLAlchemy | AWS (Kubernetes on EKS) |
| Database | SQLite today → managed DB in cloud | AWS RDS (PostgreSQL planned) |

This repo provisions and wires those pieces together with **Terraform**.

## Technologies

| Layer | Choice |
| --- | --- |
| IaC | Terraform (>= 1.5) |
| Cloud | Amazon Web Services (AWS) |
| Orchestration | Kubernetes on **Amazon EKS** |
| Containers | **Amazon ECR** (image registry) |
| Networking | VPC, subnets, security groups, ALB/NLB |
| Database | **Amazon RDS** (PostgreSQL planned; replaces local SQLite for SaaS) |
| Frontend delivery | S3 + CloudFront and/or ingress on EKS (TBD) |
| Secrets (later) | AWS Secrets Manager / SSM Parameter Store, IAM roles, OIDC for CI |
| Credentials (now) | Local gitignored `config` file — temporary |

### AWS services (planned)

- **VPC** — network isolation for EKS, RDS, and load balancers
- **EKS** — run the Flask API (and optionally the frontend) as containers
- **ECR** — store backend/frontend container images
- **RDS** — managed PostgreSQL for the knowledge base and app data
- **ALB** — HTTP(S) ingress to Kubernetes services
- **S3 / CloudFront** — static frontend hosting (if not served from the cluster)
- **IAM** — least-privilege roles for Terraform, nodes, and workloads
- **Route 53** — DNS (when a public domain is configured)

## Repository structure

```
teacher-wang-infra/
├── agent.md                 # Instructions for coding agents (keep README in sync)
├── README.md                # Source of truth for status, stack, and layout
├── .gitignore               # Ignores local secrets, Terraform state, OS junk
├── config.example           # Template for local AWS credentials
├── config                   # Your secrets (gitignored) — copy from config.example
└── terraform/
    ├── .terraform.lock.hcl  # Provider version lock (committed)
    ├── versions.tf          # Terraform + provider version constraints
    ├── providers.tf         # AWS provider (region, default tags)
    ├── variables.tf         # Root input variables
    ├── main.tf              # Bootstrap resources / data sources
    └── outputs.tf           # Useful outputs (account ID, region, caller ARN)
```

## Getting started

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- An AWS account and IAM user/role with permissions to create the resources you plan to manage
- AWS CLI optional but useful for debugging (`aws sts get-caller-identity`)

### Configure credentials (temporary)

```bash
cp config.example config
# Edit `config` with your AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and region
source ./config
```

`config` is gitignored. Do not commit real keys. A safer approach (SSO, roles, CI OIDC) is planned in the roadmap.

### Initialize and verify AWS connectivity

```bash
cd terraform
terraform init
terraform plan
```

If credentials are valid, the plan should succeed and show outputs for the caller account/region once applied:

```bash
terraform apply
terraform output
```

At this stage the only “resources” are read-only data sources used to confirm the Terraform ↔ AWS connection.

## Roadmap

### 1. Repository & AWS bootstrap

- [x] Initialize infra repo with README, `agent.md`, and `.gitignore`
- [x] Terraform scaffolding (`versions`, `providers`, `variables`, bootstrap outputs)
- [x] Local AWS credentials via gitignored `config` (temporary)
- [ ] Validate `terraform init` / `plan` against a real AWS account
- [ ] Decide on remote state (S3 + DynamoDB locking)

### 2. Networking foundation

- [ ] VPC, public/private subnets across AZs
- [ ] NAT, route tables, security group baselines
- [ ] Tagging and naming conventions

### 3. Data layer

- [ ] RDS PostgreSQL (dev sizing first)
- [ ] Migrations path from SQLite schema used in the app
- [ ] Backup / retention policy

### 4. Container platform

- [ ] ECR repositories for backend (and frontend if containerized)
- [ ] EKS cluster + node group
- [ ] Cluster networking (CNI, ingress controller / ALB)

### 5. Application deployment

- [ ] Kubernetes manifests / Helm charts for the Flask API
- [ ] Frontend hosting (S3+CloudFront or in-cluster)
- [ ] Wire backend ↔ RDS and frontend ↔ backend URLs / CORS
- [ ] Health checks and basic observability (CloudWatch)

### 6. Secrets & CI/CD

- [ ] Replace local `config` keys with IAM roles / AWS SSO / OIDC
- [ ] Store app secrets in Secrets Manager or SSM
- [ ] Pipeline to build images, push to ECR, and apply Terraform / deploy

### 7. Hardening & production readiness

- [ ] TLS certificates, custom domain
- [ ] Environments (`dev` / `staging` / `prod`)
- [ ] Cost guards, monitoring alerts, least-privilege IAM review

