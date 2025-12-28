output "vpcid" {
  value = aws_vpc.vpc.id
}

output "prs1" {
  value = aws_subnet.prs1.id
}

output "prs2" {
  value = aws_subnet.prs2.id
}

output "prrtid" {
  value = aws_route_table.pr_rt.id
}


