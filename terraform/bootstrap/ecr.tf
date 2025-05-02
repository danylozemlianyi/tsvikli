resource "aws_ecr_repository" "guacamole" {
  name                 = "tsvikli/guacamole"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "Tsvikli Guacamole Repository"
  }
}
