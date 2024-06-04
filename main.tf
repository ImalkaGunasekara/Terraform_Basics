# Configure the AWS Provider

provider "aws" {
  region = "us-east-1"
  access_key = ""
  secret_key = ""
}

# Create a resource

# resource "<provider>_<resource_type>" "name" {
#     config options....
#     key="value"
# }


# Create an EC2 instance

resource "aws_instance" "my-first-server" {
    ami = "ami-04b70fa74e45c3917"
    instance_type = "t2.micro"
    tags = {
    #   name="ubuntu"
    #   Name="ubuntu"
    }
}

# Create a VPC

resource "aws_vpc" "first-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name="production"
  }
}

# Create a subnet

resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.first-vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name="prod-subnet"
  }
}

# ----------------------------------------------------------------------------------------------------------------------------------- #

# Practice Project

# 1. Create a VPC

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
  tags={
    Name="production"
  }
}

# 2. Create Internet Gateway


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# 3. Create Custom Route Table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Prod"
  }
}

# 4. Create a Subnet

# Subnet for the project

resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix[0].cidr_block
  availability_zone = "us-east-1a"
  tags={
    Name= var.subnet_prefix[0].name
  }
}

variable "subnet_prefix" {
  description = "cidr block for the subnet"
  # default = ""
  # type = string
}

# Subnet for demo

resource "aws_subnet" "subnet-2" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix[1].cidr_block
  availability_zone = "us-east-1b"
  tags={
    Name=var.subnet_prefix[1].name
  }
}

# 5. Associate subnet with Route Table

resource "aws_route_table_association" "web-route-table" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. Create Security Group to alow port 22,80,443

# # (i) Method 1

# resource "aws_security_group" "allow_web" {
#   name        = "allow_web_traffic"
#   description = "Allow web inbound traffic"
#   vpc_id      = aws_vpc.prod-vpc.id

#   tags = {
#     Name = "allow_web"
#   }
# }

# resource "aws_vpc_security_group_ingress_rule" "allow_https" {
#   security_group_id = aws_security_group.allow_web.id
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 443
#   ip_protocol       = "tcp"
#   to_port           = 443
# }

# resource "aws_vpc_security_group_ingress_rule" "allow_http" {
#   security_group_id = aws_security_group.allow_web.id
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 80
#   ip_protocol       = "tcp"
#   to_port           = 80
# }

# resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
#   security_group_id = aws_security_group.allow_web.id
#   cidr_ipv4         = "0.0.0.0/0"
#   from_port         = 22
#   ip_protocol       = "tcp"
#   to_port           = 22
# }

# resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
#   security_group_id = aws_security_group.allow_web.id
#   cidr_ipv4         = "0.0.0.0/0"
#   ip_protocol       = "-1" # semantically equivalent to all ports
# }

# resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv6" {
#   security_group_id = aws_security_group.allow_web.id
#   cidr_ipv6         = "::/0"
#   ip_protocol       = "-1" # semantically equivalent to all ports
# }


# (ii) Method 2


resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS" # This won't actually connect with HTTPS because for that we need to have a SSL Certificate
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}


# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# 8. Assign an elastic IP to the network interface created in step 7

resource "aws_eip" "one" {
  domain = "vpc"
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.gw ]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

# 9. Create Ubuntu server and install/enable apache2

resource "aws_instance" "web-server-instance" {
  ami="ami-04b70fa74e45c3917"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

  network_interface {
    network_interface_id = aws_network_interface.web-server-nic.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF
  
  tags = {
    Name = "web-server"
  }
}


# ----------------------------------------------------------------------------------------------------------------------------------- #


