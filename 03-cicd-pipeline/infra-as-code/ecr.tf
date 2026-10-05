
resource "aws_ecr_repository" "ecr_site" {
  name                 = "site_prod"
  image_tag_mutability = "MUTABLE"

}



#ECR (Elastic Container Registry): serve pra armazenar imagens na AWS.
