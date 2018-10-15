provider "aws" {
  region                  = "eu-central-1"
  shared_credentials_file = "/Users/maxx/.aws/credentials"
  profile                 = "default"
}

# Create a VPC
resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Create a subnet
resource "aws_subnet" "default" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Security group to access the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "webapp"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.default.id}"

  # inbound SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # inbound HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# Create ec2 instance
resource "aws_instance" "default" {
  # use ubuntu 18.04 server ami
  ami = "ami-0bdf93799014acdc4"
  instance_type = "t2.micro"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id = "${aws_subnet.default.id}"

  # Configure the instance with ansible-playbook
  provisioner "local-exec" {
    command = "ansible-playbook -u ubuntu --private-key ${var.public_key_path} -i '${aws_instance.default.public_ip},' provision.yml"
  }
}

# Create rds instance
resource "aws_db_instance" "default" {
  identifier = "webapp-rds"
  allocated_storage = "10"
  engine = "postgres"
  engine_version = "10.4"
  instance_class = "db.t2.micro"
  name = "webappdb"
  username = "webapp_user"
  password = "${var.password}"
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name = "webapp_rds_sg"

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }
}