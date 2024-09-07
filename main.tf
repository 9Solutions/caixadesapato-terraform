terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


resource "aws_vpc" "vpc_terraform" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "vpc-caixadesapato"
  }
}

resource "aws_subnet" "public_subnet" {
  depends_on = [aws_vpc.vpc_terraform]

  vpc_id                  = aws_vpc.vpc_terraform.id
  cidr_block              = "10.0.0.0/25"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "sub-pub-caixadesapato"
  }
}

resource "aws_subnet" "private_subnet" {
  depends_on = [aws_vpc.vpc_terraform]

  vpc_id            = aws_vpc.vpc_terraform.id
  cidr_block        = "10.0.0.128/25"
  availability_zone = "us-east-1b"

  tags = {
    Name = "sub-pri-caixadesapato"
  }
}

resource "aws_internet_gateway" "igw-caixadesapato" {
  depends_on = [
    aws_vpc.vpc_terraform,
    aws_subnet.public_subnet,
    aws_subnet.private_subnet
  ]

  vpc_id = aws_vpc.vpc_terraform.id

  tags = {
    Name = "igw-caixadesapato"
  }
}

resource "aws_eip" "lb" {
  tags = {
    Name = "eip-caixadesapato"
  }
}

resource "aws_nat_gateway" "ngw-caixadesapato" {
  depends_on = [aws_subnet.public_subnet]

  subnet_id     = aws_subnet.public_subnet.id
  allocation_id = aws_eip.lb.id
  tags = {
    Name = "ngw-caixadesapato"
  }
}


# create route table
resource "aws_route_table" "rtb_main_caixadesapato" {
  depends_on = [
    aws_vpc.vpc_terraform,
    aws_subnet.public_subnet,
    aws_internet_gateway.igw-caixadesapato
  ]

  vpc_id = aws_vpc.vpc_terraform.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw-caixadesapato.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.igw-caixadesapato.id
  }

  tags = {
    Name = "rtb-main-caixadesapato"
  }
}

resource "aws_route_table" "rtb_private_caixadesapato" {
  depends_on = [
    aws_vpc.vpc_terraform,
    aws_nat_gateway.ngw-caixadesapato,
    aws_subnet.private_subnet
  ]

  vpc_id = aws_vpc.vpc_terraform.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ngw-caixadesapato.id
  }

  tags = {
    Name = "rtb-private-caixadesapato"
  }
}

resource "aws_route_table_association" "rta_public_subnet" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.rtb_main_caixadesapato.id
}

resource "aws_route_table_association" "rta_private_subnet" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.rtb_private_caixadesapato.id
}


# create security groups
resource "aws_security_group" "sg_access_webserver" {
  name        = "access-webserver-caixadesapato"
  description = "Acesso ao site do projeto"
  vpc_id      = aws_vpc.vpc_terraform.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }


  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "access-webserver-caixadesapato"
  }
}

# TODO: quem estiver dentro da vcp, pode acessar o spring boot
resource "aws_security_group" "sg_access_api_rest" {
  name        = "access-api-rest-caixadesapato"
  description = "Acesso a API Spring Boot na porta 8080"
  vpc_id      = aws_vpc.vpc_terraform.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/24"]
  }

#ficaria mais seguro se eu definir a saida para a vpc?
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "access-api-rest-caixadesapato"
  }

}

resource "aws_security_group" "sg_access_database" {
  name        = "access-database-caixadesapato"
  description = "Acesso ao banco de dados"
  vpc_id      = aws_vpc.vpc_terraform.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.128/25"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.128/25"]
  }

  tags = {
    Name = "access-database-caixadesapato"
  }

}





