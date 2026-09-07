# IAM policy containing the AWS permissions required by
# the AWS Load Balancer Controller.
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "petclinic-aws-load-balancer-controller"

  policy = file("${path.module}/aws-load-balancer-controller.json")

  tags = {
    Name = "petclinic-aws-load-balancer-controller"
  }
}


# Trust policy for EKS Pod Identity.
# Allows EKS pods to assume this IAM role.
data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}


# IAM role used by the AWS Load Balancer Controller pods.
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "petclinic-aws-load-balancer-controller"

  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json

  tags = {
    Name = "petclinic-aws-load-balancer-controller"
  }
}


# Attach the controller permissions to its IAM role.
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}


# Connect the Kubernetes ServiceAccount with the IAM role
# using EKS Pod Identity.
resource "aws_eks_pod_identity_association" "aws_load_balancer_controller" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_load_balancer_controller.arn
}
