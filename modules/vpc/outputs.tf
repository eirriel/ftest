output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "subnet_a_id" {
  value = aws_subnet.subnet_a.id
}

output "subnet_z_id" {
  value = aws_subnet.subnet_z.id
}

output "private_subnet_a_id" {
  value = aws_subnet.private_subnet_a.id
}

output "private_subnet_z_id" {
  value = aws_subnet.private_subnet_z.id
}