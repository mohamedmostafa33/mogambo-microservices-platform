data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "mogambo_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "mogambo-vpc"
  }
}

resource "aws_subnet" "mogambo_public_subnet_1" {
  vpc_id                  = aws_vpc.mogambo_vpc.id
  cidr_block              = var.public_subnet_cidr_block_1
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "mogambo-public-subnet_1"
  }
}

resource "aws_subnet" "mogambo_public_subnet_2" {
  vpc_id                  = aws_vpc.mogambo_vpc.id
  cidr_block              = var.public_subnet_cidr_block_2
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "mogambo-public-subnet_2"
  }
}

resource "aws_subnet" "mogambo_private_subnet_1" {
  vpc_id                  = aws_vpc.mogambo_vpc.id
  cidr_block              = var.private_subnet_cidr_block_1
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "mogambo-private-subnet_1"
  }
}

resource "aws_subnet" "mogambo_private_subnet_2" {
  vpc_id                  = aws_vpc.mogambo_vpc.id
  cidr_block              = var.private_subnet_cidr_block_2
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "mogambo-private-subnet_2"
  }
}

resource "aws_internet_gateway" "mogambo_internet_gateway" {
  vpc_id = aws_vpc.mogambo_vpc.id

  tags = {
    Name = "mogambo-internet-gateway"
  }
}

resource "aws_eip" "mogambo_eip" {
  domain = "vpc"

  tags = {
    Name = "mogambo-eip"
  }
}

resource "aws_nat_gateway" "mogambo_nat_gateway" {
  allocation_id = aws_eip.mogambo_eip.id
  subnet_id     = aws_subnet.mogambo_public_subnet_1.id

  tags = {
    Name = "mogambo-nat-gateway"
  }
  depends_on = [aws_internet_gateway.mogambo_internet_gateway]
}

resource "aws_route_table" "mogambo_public_route_table" {
  vpc_id = aws_vpc.mogambo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mogambo_internet_gateway.id
  }

  tags = {
    Name = "mogambo-public-route-table"
  }
}

resource "aws_route_table_association" "mogambo_public_subnet_1_route_table_association" {
  subnet_id      = aws_subnet.mogambo_public_subnet_1.id
  route_table_id = aws_route_table.mogambo_public_route_table.id
}

resource "aws_route_table_association" "mogambo_public_subnet_2_route_table_association" {
  subnet_id      = aws_subnet.mogambo_public_subnet_2.id
  route_table_id = aws_route_table.mogambo_public_route_table.id
}

resource "aws_route_table" "mogambo_private_route_table" {
  vpc_id = aws_vpc.mogambo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mogambo_nat_gateway.id
  }

  tags = {
    Name = "mogambo-private-route-table"
  }
}

resource "aws_route_table_association" "mogambo_private_subnet_1_route_table_association" {
  subnet_id      = aws_subnet.mogambo_private_subnet_1.id
  route_table_id = aws_route_table.mogambo_private_route_table.id
}

resource "aws_route_table_association" "mogambo_private_subnet_2_route_table_association" {
  subnet_id      = aws_subnet.mogambo_private_subnet_2.id
  route_table_id = aws_route_table.mogambo_private_route_table.id
}