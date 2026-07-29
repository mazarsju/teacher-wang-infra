# Architecture

Living overview of the AWS layout provisioned by this repository.
Update this file whenever components are added, removed, or rewired.

## Current state (networking foundation)

Provisioned today: remote state, VPC, subnets, IGW, single NAT, route tables, and security group baselines.
Not yet provisioned (shown dashed in the target view): EKS, ECR, RDS, ALB, CloudFront.

### High-level AWS account

```mermaid
flowchart TB
  subgraph Account["AWS account"]
    TF["Terraform operators<br/>(local credentials for now)"]
    S3State["S3 state bucket<br/>teacher-wang-tfstate-&lt;account&gt;<br/>versioned · AES256 · use_lockfile"]

    subgraph Region["Region: eu-west-1 (default)"]
      VPC["VPC 10.0.0.0/16"]
    end
  end

  TF -->|plan / apply| S3State
  TF --> VPC
```

### VPC networking

Cost choice: **one NAT Gateway** in the first public subnet, shared by all private subnets (`enable_nat_gateway`).

```mermaid
flowchart TB
  Internet((Internet))

  IGW[Internet Gateway]
  NAT["NAT Gateway + EIP<br/>(single, public AZ-a)"]

  subgraph VPC["VPC 10.0.0.0/16"]
    direction TB

    subgraph Public["Public subnets"]
      PubA["public AZ-a<br/>10.0.0.0/20"]
      PubB["public AZ-b<br/>10.0.1.0/20"]
    end

    subgraph Private["Private subnets"]
      PrivA["private AZ-a<br/>10.0.8.0/20"]
      PrivB["private AZ-b<br/>10.0.9.0/20"]
    end

    RTPub["Public route table<br/>0.0.0.0/0 → IGW"]
    RTPriv["Private route table<br/>0.0.0.0/0 → NAT"]
  end

  Internet <--> IGW
  IGW --- RTPub
  RTPub --- PubA
  RTPub --- PubB
  PubA --- NAT
  NAT --- RTPriv
  RTPriv --- PrivA
  RTPriv --- PrivB
  NAT --> IGW
```

### Security group baselines

Traffic is constrained by SG references (not CIDR between tiers).

```mermaid
flowchart LR
  Users((Users / Internet))

  SGALB["SG: alb<br/>ingress 80, 443 from 0.0.0.0/0"]
  SGApp["SG: app<br/>ingress TCP from alb SG"]
  SGDb["SG: db<br/>ingress 5432 from app SG"]

  Users -->|HTTP/HTTPS| SGALB
  SGALB -->|future ALB → targets| SGApp
  SGApp -->|future RDS| SGDb
```

| Security group | Purpose | Ingress | Egress |
| --- | --- | --- | --- |
| `alb` | Future public ALB | TCP 80, 443 from internet | all |
| `app` | Future EKS / app workloads | TCP 1–65535 from `alb` | all (NAT for pulls / AWS APIs) |
| `db` | Future RDS PostgreSQL | TCP 5432 from `app` | none defined |

### Terraform remote state

```mermaid
flowchart LR
  Dev[Developer / CI] -->|terraform init/plan/apply| Backend[S3 backend]
  Backend --> Bucket["Bucket: teacher-wang-tfstate-&lt;account_id&gt;"]
  Bucket --> State["Key: teacher-wang/terraform.tfstate"]
  Bucket --> Lock["Native lock file (.tflock)<br/>use_lockfile = true"]
```

## Target architecture (planned)

Shows how upcoming roadmap pieces attach to the network already in place.

```mermaid
flowchart TB
  Users((Users))

  CF["CloudFront + S3<br/>(frontend — planned)"]
  R53["Route 53 — planned"]

  Users --> R53
  R53 --> CF
  Users --> ALB

  subgraph VPC["VPC"]
    ALB["ALB — planned<br/>public subnets · SG alb"]

    subgraph Private["Private subnets"]
      EKS["EKS + node group — planned<br/>SG app"]
      RDS["RDS PostgreSQL — planned<br/>SG db"]
    end

    NAT["Single NAT Gateway"]
  end

  ECR["ECR — planned"]
  SM["Secrets Manager / SSM — planned"]

  ALB --> EKS
  EKS --> RDS
  EKS --> NAT
  EKS -.-> ECR
  EKS -.-> SM
  CF -.->|API calls| ALB
```

## Cost posture (current networking)

| Component | Cost impact | Notes |
| --- | --- | --- |
| VPC, subnets, route tables, SGs, IGW | Free | — |
| Single NAT Gateway + EIP | Paid (~$32/mo + data) | Toggle with `enable_nat_gateway` |
| Per-AZ NAT | Avoided in `dev` | Would multiply NAT cost |

## Related docs

- [README.md](../README.md) — roadmap, getting started, tech choices
- [agent.md](../agent.md) — agent rules (keep README + this file in sync)
