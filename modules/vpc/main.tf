data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subneta_cidr
  map_public_ip_on_launch = "true"
  availability_zone = data.aws_availability_zones.available.names[0]
}

resource "aws_subnet" "subnet_z" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnetz_cidr
  map_public_ip_on_launch = "true"
  availability_zone = data.aws_availability_zones.available.names[1]
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_default_route_table" "route_table" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_eip" "nat_gw_ip" {
  vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_gw_ip.id
  subnet_id = aws_subnet.subnet_a.id
  depends_on = [aws_eip.nat_gw_ip]
}

resource "aws_route_table" "nat_gw_rt" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "nat_gw_def_route" {
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gw.id
  route_table_id = aws_route_table.nat_gw_rt.id
}

resource "aws_subnet" "private_subnet_a" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.subnetpa_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
}

resource "aws_route_table_association" "private_subnet_a_rt_assoc" {
  route_table_id = aws_route_table.nat_gw_rt.id
  subnet_id = aws_subnet.private_subnet_a.id
}

resource "aws_subnet" "private_subnet_z" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.subnetpz_cidr
  availability_zone = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false
}

resource "aws_route_table_association" "private_subnet_z_rt_assoc" {
  route_table_id = aws_route_table.nat_gw_rt.id
  subnet_id = aws_subnet.private_subnet_z.id
}
