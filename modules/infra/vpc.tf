# Networking foundation: VPC, subnets, IGW, single NAT, and route tables.
#
# Cost notes (dev-first):
# - VPC/subnets/IGW themselves are free; keep az_count at the minimum (2) for HA.
# - map_public_ip_on_launch is false to avoid accidental public IPv4 charges.
# - Single NAT Gateway in one public subnet for all private AZs (~$32/mo + data).
#   One NAT per AZ is much more expensive; enable only when private outbound is needed
#   (set enable_nat_gateway = false to avoid the charge; ECS currently uses public IPs instead).

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

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_subnet" "public" {
  count = var.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = var.az_count

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# --- NAT (single gateway for cost; all private subnets share it) ---

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-nat-eip"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

# --- Route tables ---

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = var.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# One private route table for all AZs — matches the single-NAT cost choice.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.resource_tags, {
    Name = "${local.name_prefix}-private-rt"
    Tier = "private"
  })
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route_table_association" "private" {
  count = var.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
