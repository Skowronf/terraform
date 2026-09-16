data "aws_iam_policy_document" "external_dns_permissions" {
  statement {
    effect = "Allow"

    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResources"
    ]

    resources = [
      "arn:aws:route53:::hostedzone/${data.aws_route53_zone.petclinic.zone_id}"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "route53:ListHostedZones"
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "external_dns_assume_role" {
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

resource "aws_iam_role" "external_dns" {
  name = "petclinic-external-dns"

  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json

  tags = {
    Name = "petclinic-external-dns"
  }
}


resource "aws_iam_role_policy" "external_dns" {
  name = "petclinic-external-dns"
  role = aws_iam_role.external_dns.id

  policy = data.aws_iam_policy_document.external_dns_permissions.json
}

resource "aws_eks_pod_identity_association" "external_dns" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "external-dns"
  service_account = "external-dns"
  role_arn        = aws_iam_role.external_dns.arn
}
