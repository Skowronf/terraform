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

# Add pod identity agent add-on to the EKS cluster.
resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "eks-pod-identity-agent"
}
