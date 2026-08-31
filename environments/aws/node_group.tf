# Managed worker nodes for the EKS cluster.
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "petclinic-nodes"

  # IAM role used by the EC2 worker nodes.
  node_role_arn = aws_iam_role.eks_node.arn

  # Run nodes in private subnets across two Availability Zones.
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  # EC2 instance type used by the nodes.
  instance_types = ["t3.small"]

  # Scaling configuration for the node group.
  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 3
  }

  tags = {
    Name = "petclinic-eks-node"
  }
}
