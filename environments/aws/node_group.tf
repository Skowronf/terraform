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
    desired_size = 5
    min_size     = 5
    max_size     = 6
  }

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  tags = {
    Name = "petclinic-eks-node"
  }
}

# additional configuration for the EKS node group to use a launch template
resource "aws_launch_template" "eks_nodes" {
  name_prefix = "petclinic-eks-nodes-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    # Set to 2 to allow the node to retrieve instance metadata 
    # in order for the AWS Load Balancer Controller be able to retrieve the vpc-id
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "petclinic-eks-node"
    }
  }
}