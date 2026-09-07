
### IAM FOR CLUSTER

# Trust policy: defines who can assume the EKS cluster role.
data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"

    # EKS service is allowed to assume this role.
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    # AWS STS action used to assume the IAM role.
    actions = [
      "sts:AssumeRole"
    ]
  }
}


# IAM role used by the EKS control plane.
resource "aws_iam_role" "eks_cluster" {
  name = "petclinic-eks-cluster-role"

  # Attach the trust policy to the role.
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = {
    Name = "petclinic-eks-cluster-role"
  }
}


# Grants the EKS control plane the required AWS permissions.
resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


### IAM FOR NODES

# Trust policy for EKS worker nodes.
data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"

    # EC2 instances are allowed to assume this role.
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    # Allows EC2 to obtain temporary credentials for the role.
    actions = [
      "sts:AssumeRole"
    ]
  }
}


# IAM role used by EKS worker nodes.
resource "aws_iam_role" "eks_node" {
  name = "petclinic-eks-node-role"

  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

  tags = {
    Name = "petclinic-eks-node-role"
  }
}

# Allows worker nodes to perform required EKS operations.
resource "aws_iam_role_policy_attachment" "eks_node_worker" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}


# Allows nodes to pull container images from Amazon ECR
resource "aws_iam_role_policy_attachment" "eks_node_ecr" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}
