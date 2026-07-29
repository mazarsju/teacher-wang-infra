# Networking foundation: VPC + public/private subnets across AZs.
# Route tables, NAT, and security groups come in the next roadmap step.
#
# Cost notes (dev-first):
# - VPC/subnets themselves are free; keep az_count at the minimum (2) for HA.
# - map_public_ip_on_launch is false to avoid accidental public IPv4 charges.
# - When adding NAT: prefer a single NAT Gateway (or NAT instance) in one public
#   subnet for dev — one NAT per AZ is much more expensive.

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /16 VPC → /20 subnets (4094 usable IPs each). Public uses indexes 0..N-1;
  # private uses 8..8+N-1 so room remains for future subnet tiers.
  public_subnet_cidrs  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-private-${local.azs[count.index]}"
    Tier = "private"
  }
}
