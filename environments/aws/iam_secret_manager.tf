# Permissions granted to the External Secrets Operator.
data "aws_iam_policy_document" "external_secrets_permissions" {
  statement {
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      aws_secretsmanager_secret.petclinic_database.arn
    ]
  }
}

# Trust policy for EKS Pod Identity.
# Allows Pods using the associated ServiceAccount to assume this role.
data "aws_iam_policy_document" "external_secrets_assume_role" {
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

# IAM role used by the External Secrets Operator.
resource "aws_iam_role" "external_secrets" {
  name = "petclinic-external-secrets"

  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json

  tags = {
    Name = "petclinic-external-secrets"
  }
}

# Attach the Secrets Manager permissions to the role.
resource "aws_iam_role_policy" "external_secrets" {
  name = "petclinic-external-secrets"
  role = aws_iam_role.external_secrets.id

  policy = data.aws_iam_policy_document.external_secrets_permissions.json
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn
}