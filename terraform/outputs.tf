output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  value = data.aws_caller_identity.current.arn
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public_1a.id, aws_subnet.public_1c.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.private_1a.id, aws_subnet.private_1c.id]
}

output "nat_public_ip" {
  value = aws_eip.nat.public_ip
}
