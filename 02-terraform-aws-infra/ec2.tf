
resource "aws_instance" "website_server" {
  ami                    = "ami-0354c98ae10b02961"              #Amazon Linux 2 AMI
  instance_type          = "t3.micro"
  key_name               = "chave-site-prod"                    #Nome da chave SSH pra acessar a instância
  vpc_security_group_ids = [aws_security_group.website_sh.id]   #IDs dos grupos de segurança associados à instância
  iam_instance_profile   = "ECR-EC2-Role"                       #Nome do perfil (ROLE) de instância criado no console da AWS

  tags = {
    Name       = "website-server"
    ProvidedBy = "Terraform"
    CreatedBy  = "Agnelo"
    Date       = "2024-09-14"
  }
}


#Security Group (quem entra e quem sai da instânciaf)
resource "aws_security_group" "website_sh" {
  name        = "website-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = "vpc-0f924f2820e419548"           # copiar o id da VPC criada no console da AWS por default: vpc-0f924f2820e419548

  tags = {
    Name       = "website-sg"
    ProvidedBy = "Terraform"
    CreatedBy  = "Agnelo"
    Date       = "2024-09-14"
  }
}


#####Ingress (INBOUND) Rules: 

#Allow SSH from my computer
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.website_sh.id

  cidr_ipv4   = "188.82.120.251/32"          #IP do meu computador
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

#Allow HTTP from anywhere
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.website_sh.id

  cidr_ipv4   = "0.0.0.0/0"           #Permitir tráfego HTTP de qualquer lugar
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

#Allow HTTPS from anywhere
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.website_sh.id

  cidr_ipv4   = "0.0.0.0/0"             #Permitir tráfego HTTPS de qualquer lugar
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}



##### Egress (OUTBOUND) Rules: 

resource "aws_vpc_security_group_egress_rule" "allow_all_outbound" {
  security_group_id = aws_security_group.website_sh.id

  cidr_ipv4   = "0.0.0.0/0" #Permitir tráfego de saída para qualquer lugar
  ip_protocol = -1          #Permitir todos os protocolos
}

