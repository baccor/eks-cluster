
data "aws_availability_zones" "avz" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

}

resource "aws_subnet" "ps1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.avz.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name                         = "ps1"
    "kubernetes.io/role/elb"     = "1"
    "kubernetes.io/cluster/eksc" = "shared"
  }

}

resource "aws_subnet" "ps2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.avz.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name                         = "ps2"
    "kubernetes.io/role/elb"     = "1"
    "kubernetes.io/cluster/eksc" = "shared"
  }

}

resource "aws_subnet" "prs1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = data.aws_availability_zones.avz.names[0]
  map_public_ip_on_launch = false

  tags = {
    Name                         = "prs1"
    "kubernetes.io/cluster/eksc" = "shared"
  }
}


resource "aws_subnet" "prs2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = data.aws_availability_zones.avz.names[1]
  map_public_ip_on_launch = false
  tags = {
    Name                         = "prs2"
    "kubernetes.io/cluster/eksc" = "shared"
  }
}

resource "aws_route_table" "p_rt" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "p_rta1" {
  subnet_id      = aws_subnet.ps1.id
  route_table_id = aws_route_table.p_rt.id
}
resource "aws_route_table_association" "p_rta2" {
  subnet_id      = aws_subnet.ps2.id
  route_table_id = aws_route_table.p_rt.id
}

resource "aws_route" "pr" {
  route_table_id         = aws_route_table.p_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table" "pr_rt" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "pr_rta1" {
  subnet_id      = aws_subnet.prs1.id
  route_table_id = aws_route_table.pr_rt.id
}

resource "aws_route_table_association" "pr_rta2" {
  subnet_id      = aws_subnet.prs2.id
  route_table_id = aws_route_table.pr_rt.id
}
