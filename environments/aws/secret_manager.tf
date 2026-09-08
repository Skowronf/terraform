resource "aws_secretsmanager_secret" "petclinic_database" {
  name        = "petclinic/database"
  description = "PetClinic RDS database credentials"
  recovery_window_in_days = 0
  tags = {
    Name = "petclinic-database"
  }
}

resource "aws_secretsmanager_secret_version" "petclinic_database" {
  secret_id = aws_secretsmanager_secret.petclinic_database.id

  secret_string = jsonencode({
    host     = aws_db_instance.postgres.address
    port     = 5432
    database = "petclinic"
    username = "petclinic"
    # TODO - For now we use a static password, 
    # but in the future we will generate a random password and store it in the secret.
    password = "petclinic"
  })
}

