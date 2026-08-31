# IAM role used by the Amazon VPC CNI add-on.
resource "aws_iam_role" "vpc_cni" {
  name = "petclinic-vpc-cni-role"

  # Trust policy: allows EKS Pod Identity to assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "pods.eks.amazonaws.com"
        }

        # AssumeRole gives the pod the role.
        # TagSession allows session tags.
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = {
    Name = "petclinic-vpc-cni-role"
  }
}


# Permission policy: allows the VPC CNI to manage AWS networking resources.
resource "aws_iam_role_policy_attachment" "vpc_cni" {
  role       = aws_iam_role.vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


# Connects the Kubernetes ServiceAccount with the IAM role.
resource "aws_eks_pod_identity_association" "vpc_cni" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "aws-node"
  role_arn        = aws_iam_role.vpc_cni.arn
}