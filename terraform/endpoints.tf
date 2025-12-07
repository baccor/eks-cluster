resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.pr_rt.id]
}

resource "aws_vpc_endpoint" "ecr" {
  private_dns_enabled = true
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.eu-central-1.ecr.api"
  subnet_ids          = [aws_subnet.prs1.id, aws_subnet.prs2.id]
  security_group_ids  = [aws_security_group.vpce.id]
}

resource "aws_vpc_endpoint" "dkr" {
  private_dns_enabled = true
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.eu-central-1.ecr.dkr"
  subnet_ids          = [aws_subnet.prs1.id, aws_subnet.prs2.id]
  security_group_ids  = [aws_security_group.vpce.id]
}

resource "aws_vpc_endpoint" "lb" {
  private_dns_enabled = true
  vpc_endpoint_type   = "Interface"
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.eu-central-1.elasticloadbalancing"
  subnet_ids          = [aws_subnet.prs1.id, aws_subnet.prs2.id]
  security_group_ids  = [aws_security_group.vpce.id]
}

resource "aws_vpc_endpoint" "ec2" {
  private_dns_enabled = true
  vpc_id              = aws_vpc.vpc.id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.eu-central-1.ec2"
  subnet_ids          = [aws_subnet.prs1.id, aws_subnet.prs2.id]
  security_group_ids  = [aws_security_group.vpce.id]
}

resource "aws_vpc_endpoint" "sts" {
  private_dns_enabled = true
  vpc_id              = aws_vpc.vpc.id
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.eu-central-1.sts"
  subnet_ids          = [aws_subnet.prs1.id, aws_subnet.prs2.id]
  security_group_ids  = [aws_security_group.vpce.id]
}
