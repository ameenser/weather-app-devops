resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "golden-ami-vpc"
  }
}


resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = var.availability_zone_1
  map_public_ip_on_launch = true

  tags = {
    Name = "golden-ami-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = true

  tags = {
    Name = "golden-ami-public-subnet-2"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = var.availability_zone_1

  tags = {
    Name = "golden-ami-private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = var.availability_zone_2

  tags = {
    Name = "golden-ami-private-subnet-2"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "golden-ami-igw"
  }
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "golden-ami-public-rt"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "golden-ami-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "golden-ami-nat-gateway"
  }

  depends_on = [aws_internet_gateway.main]
}
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "golden-ami-private-rt"
  }
}

resource "aws_route" "private_nat_access" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

module "gitlab_sg_new" {
  source = "../security-group"

  name        = "${var.project_name}-gitlab-sg-v2"
  description = "Least privilege security group for GitLab instance"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "gitlab_new_all_out" {
  security_group_id = module.gitlab_sg_new.id
  description       = "Allow GitLab outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_security_group" "jenkins_agent" {
  name        = "golden-ami-jenkins-agent-sg"
  description = "Security group for Jenkins agent"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "SSH from Jenkins Controller"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [module.jenkins_controller_sg_new.id]
  }

  tags = {
    Name = "golden-ami-jenkins-agent-sg"
  }
}

resource "aws_instance" "gitlab" {
  ami           = var.gitlab_ami_id
  instance_type = var.gitlab_instance_type
  subnet_id     = aws_subnet.private_1.id
  vpc_security_group_ids = [
    module.gitlab_sg_new.id
  ]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ssm_ec2.name
  associate_public_ip_address = false

  tags = {
    Name = "golden-ami-gitlab"
  }
}

resource "aws_instance" "jenkins_agent" {
  ami                         = var.jenkins_agent_ami_id
  instance_type               = var.jenkins_agent_instance_type
  subnet_id                   = aws_subnet.private_2.id
  vpc_security_group_ids      = [aws_security_group.jenkins_agent.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ssm_ec2.name
  associate_public_ip_address = false

  tags = {
    Name = "golden-ami-jenkins-agent"
  }
}


module "jenkins_controller_sg_new" {
  source = "../security-group"

  name        = "${var.project_name}-jenkins-controller-sg-v2"
  description = "Least privilege security group for Jenkins controller"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "jenkins_controller_new_all_out" {
  security_group_id = module.jenkins_controller_sg_new.id
  description       = "Allow Jenkins controller outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}
resource "aws_instance" "jenkins_controller" {
  ami           = var.jenkins_controller_ami_id
  instance_type = var.jenkins_controller_instance_type
  subnet_id     = aws_subnet.private_1.id
  vpc_security_group_ids = [
    module.jenkins_controller_sg_new.id
  ]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ssm_ec2.name
  associate_public_ip_address = false

  tags = {
    Name = "golden-ami-jenkins-controller"
  }
}

resource "aws_volume_attachment" "gitlab_data" {
  device_name                    = "/dev/sdf"
  volume_id                      = local.gitlab_data_volume_id
  instance_id                    = aws_instance.gitlab.id
  stop_instance_before_detaching = true
}

resource "aws_volume_attachment" "jenkins_home" {
  device_name                    = "/dev/sdf"
  volume_id                      = local.jenkins_home_volume_id
  instance_id                    = aws_instance.jenkins_controller.id
  stop_instance_before_detaching = true
}

resource "aws_route53_zone" "private" {
  name = var.internal_domain

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Name = "golden-ami-private-zone"
  }
}

resource "aws_route53_record" "gitlab" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "gitlab.${var.internal_domain}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.gitlab.private_ip]
}

resource "aws_route53_record" "jenkins_controller" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "jenkins-controller.${var.internal_domain}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.jenkins_controller.private_ip]
}

resource "aws_route53_record" "jenkins_agent" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "jenkins-agent.${var.internal_domain}"
  type    = "A"
  ttl     = 60
  records = [aws_instance.jenkins_agent.private_ip]
}
