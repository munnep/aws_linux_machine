resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.tag_prefix}-vpc"
  }
}

resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = local.az1
  tags = {
    Name = "${var.tag_prefix}-public"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.tag_prefix}-gw"
  }
}

resource "aws_route_table" "publicroutetable" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.tag_prefix}-route-table-gw"
  }
}

resource "aws_route_table_association" "PublicRT1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.publicroutetable.id
}



resource "aws_security_group" "default-sg" {
  vpc_id      = aws_vpc.main.id
  name        = "${var.tag_prefix}-sg"
  description = "${var.tag_prefix}-sg"


  ingress {
    description = "ssh from the world"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.tag_prefix}-tfe_sg"
  }
}

resource "aws_network_interface" "linux_client-priv" {
  subnet_id   = aws_subnet.public1.id
  private_ips = [cidrhost(cidrsubnet(var.vpc_cidr, 8, 1), 23)]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_network_interface_sg_attachment" "sg2_attachment" {
  security_group_id    = aws_security_group.default-sg.id
  network_interface_id = aws_network_interface.linux_client-priv.id
}

resource "aws_key_pair" "default-key" {
  key_name   = "${var.tag_prefix}-key"
  public_key = var.public_key
}


resource "aws_eip" "terraform_linux-eip" {
  vpc = true

  instance                  = aws_instance.linux_client.id
  associate_with_private_ip = aws_network_interface.linux_client-priv.private_ip
  depends_on                = [aws_internet_gateway.gw]

  tags = {
    Name = "${var.tag_prefix}-eip"
  }
}

resource "aws_instance" "linux_client" {
  ami           = var.ami
  instance_type = "t3.medium"
  key_name      = "${var.tag_prefix}-key"

  network_interface {
    network_interface_id = aws_network_interface.linux_client-priv.id
    device_index         = 0
  }

  user_data = templatefile("${path.module}/scripts/cloudinit_tfe_client.yaml", {})

  tags = {
    Name = "${var.tag_prefix}-client"
  }

  depends_on = [
    aws_network_interface_sg_attachment.sg2_attachment
  ]
}


