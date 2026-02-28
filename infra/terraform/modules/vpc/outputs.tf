output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.mogambo_vpc.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.mogambo_vpc.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [
    aws_subnet.mogambo_public_subnet_1.id,
    aws_subnet.mogambo_public_subnet_2.id
  ]
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = [
    aws_subnet.mogambo_public_subnet_1.cidr_block,
    aws_subnet.mogambo_public_subnet_2.cidr_block
  ]
}

output "public_subnet_azs" {
  description = "Availability Zones of the public subnets"
  value       = [
    aws_subnet.mogambo_public_subnet_1.availability_zone,
    aws_subnet.mogambo_public_subnet_2.availability_zone
  ]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [
    aws_subnet.mogambo_private_subnet_1.id,
    aws_subnet.mogambo_private_subnet_2.id
  ]
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets"
  value       = [
    aws_subnet.mogambo_private_subnet_1.cidr_block,
    aws_subnet.mogambo_private_subnet_2.cidr_block
  ]
}

output "private_subnet_azs" {
  description = "Availability Zones of the private subnets"
  value       = [
    aws_subnet.mogambo_private_subnet_1.availability_zone,
    aws_subnet.mogambo_private_subnet_2.availability_zone
  ]
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.mogambo_internet_gateway.id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway"
  value       = aws_nat_gateway.mogambo_nat_gateway.id
}

output "nat_gateway_eip" {
  description = "The Elastic IP associated with the NAT Gateway"
  value       = aws_eip.mogambo_eip.public_ip
}

output "public_route_table_id" {
  description = "The ID of the public route table"
  value       = aws_route_table.mogambo_public_route_table.id
}

output "private_route_table_id" {
  description = "The ID of the private route table"
  value       = aws_route_table.mogambo_private_route_table.id
}