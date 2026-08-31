# Managed Kubernetes control plane.
resource "aws_eks_cluster" "main" {
  name     = "petclinic-eks"
  role_arn = aws_iam_role.eks_cluster.arn

  # Subnets where AWS will place the EKS control plane network interfaces.
  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
  }

  tags = {
    Name = "petclinic-eks"
  }
}
