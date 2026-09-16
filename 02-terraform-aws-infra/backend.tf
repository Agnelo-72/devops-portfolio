# state.tf
terraform {
  backend "s3" {
    bucket = "terraform-state-agnelo" 
    key    = "site/terraform.tfstate"        #caminho do arquivo de estado
    region = "us-east-1"  
    encrypt = "true"                         #encriptar os dados
  }
}

#serve para configurar o backend do Terraform para armazenar o estado da infraestrutura (tfstate) em um bucket S3 na AWS. 
#O bloco "backend" especifica o tipo de backend (neste caso, "s3") onde o estado será armazenado.