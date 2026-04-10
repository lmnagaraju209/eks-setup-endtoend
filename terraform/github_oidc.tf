# GitHub Actions OIDC role for CI/CD
#
# Lets GitHub Actions assume an AWS role (no long-lived access keys).
# This role is scoped to a single repo via "sub" condition.

locals {
  github_repo_full = (var.github_org != "" && var.github_repo != "") ? "${var.github_org}/${var.github_repo}" : ""

  # GitHub may return either of two intermediate certs; IAM needs both thumbprints.
  # https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/
  github_actions_tls_thumbprint = lower(replace(data.tls_certificate.github_actions.certificates[0].sha1_fingerprint, ":", ""))
  github_actions_oidc_thumbprints = distinct([
    local.github_actions_tls_thumbprint,
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ])
}

data "aws_iam_openid_connect_provider" "github" {
  # If your account already has the provider, we can reference it.
  # If not, create it below.
  count = 0
  arn   = ""
}

data "tls_certificate" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = local.github_actions_oidc_thumbprints

  tags = merge(var.tags, { Name = "${var.project_name}-github-oidc" })
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    # Restrict to this repo; if vars are left blank, this becomes permissive,
    # so we guard by requiring you to set github_org/github_repo.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_repo_full}:*"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "github_actions_permissions" {
  # Push/pull to the two ECR repos created by this stack
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:ListImages",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
    resources = [
      aws_ecr_repository.backend.arn,
      aws_ecr_repository.frontend.arn
    ]
  }

  # Needed for docker login to ECR
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Optional: allow reading EKS cluster info (useful for future "helm upgrade" deploy job)
  statement {
    effect = "Allow"
    actions = [
      "eks:DescribeCluster"
    ]
    resources = [module.eks.cluster_arn]
  }
}

resource "aws_iam_policy" "github_actions" {
  name   = "${var.project_name}-github-actions"
  policy = data.aws_iam_policy_document.github_actions_permissions.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}


