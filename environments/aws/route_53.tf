data "aws_route53_zone" "petclinic" {
  name         = "petclinic.website"
  private_zone = false
}
