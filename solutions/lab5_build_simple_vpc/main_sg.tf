resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.Lab3_VPC.id

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
   
  }

  tags = {
    Name = "allow_web_http"
  }
}

resource "aws_security_group" "allow_mssql" {
  name        = "allow_sql"
  description = "Allow 1433 MS SQL inbound traffic"
  vpc_id      = aws_vpc.Lab3_VPC.id

  ingress {
    description      = "sql traffic inbound"
    from_port        = 1433
    to_port          = 1433
    protocol         = "tcp"
    security_groups  = ["${aws_security_group.allow_web.id}"]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  tags = {
    Name = "allow_MSSQL"
  }
}
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow port 22 ssh inbound traffic"
  vpc_id      = aws_vpc.Lab3_VPC.id

  ingress {
    description      = "ssh traffic inbound"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  tags = {
    Name = "allow_SSH"
  }
}