
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

resource "aws_acm_certificate" "vpncrt" {
  private_key = file("${path.module}/crt/srv.key")
  certificate_body = file("${path.module}/crt/srv.crt")
  certificate_chain = file("${path.module}/crt/ca.crt")
}

resource "aws_security_group" "vpnsg" {
  name = "vpnsg"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_egress_rule" "vpneg" {
  ip_protocol              = "-1"
  cidr_ipv4 = aws_vpc.vpc.cidr_block
  security_group_id        = aws_security_group.vpnsg.id
}

resource "aws_ec2_client_vpn_endpoint" "vpne" {
  server_certificate_arn = aws_acm_certificate.vpncrt.arn
  client_cidr_block      = "10.50.0.0/16"
  security_group_ids = [aws_security_group.vpnsg.id]
  vpc_id = aws_vpc.vpc.id

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.vpncrt.arn
  }

  split_tunnel = true

  dns_servers = [
    "10.0.0.2"
  ]

  connection_log_options {
    enabled               = false
  }
}

resource "aws_ec2_client_vpn_network_association" "vpna" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpne.id
  subnet_id              = aws_subnet.prs1.id
}

resource "aws_ec2_client_vpn_authorization_rule" "vpnar" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpne.id
  target_network_cidr    = aws_vpc.vpc.cidr_block
  authorize_all_groups   = true
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
