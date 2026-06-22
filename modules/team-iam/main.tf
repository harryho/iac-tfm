data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  iam_path   = "/${var.project_name}/"
  group_names = {
    admin     = "${var.project_name}-admins"
    developer = "${var.project_name}-developers"
    tester    = "${var.project_name}-testers"
  }
  common_tags = merge(var.common_tags, { ManagedBy = "terraform" })

  oidc_sub_condition = var.oidc_environment != "" ? (
    "repo:${var.github_org}/${var.github_repo}:environment:${var.oidc_environment}:*"
    ) : (
    "repo:${var.github_org}/${var.github_repo}:*"
  )
}

resource "terraform_data" "oidc_placeholders_replaced" {
  count = var.github_org != "" && var.github_repo != "" ? 1 : 0

  input = {
    org  = var.github_org
    repo = var.github_repo
  }

  lifecycle {
    precondition {
      condition     = !startswith(var.github_org, "YOUR_")
      error_message = "github_org is still the placeholder '${var.github_org}'. Replace it (e.g. in envs/<env>/terraform.tfvars) before applying."
    }
    precondition {
      condition     = !startswith(var.github_repo, "YOUR_")
      error_message = "github_repo is still the placeholder '${var.github_repo}'. Replace it before applying."
    }
  }
}

resource "aws_iam_group" "admin" {
  name = local.group_names.admin
  path = local.iam_path
}

resource "aws_iam_group" "developer" {
  name = local.group_names.developer
  path = local.iam_path
}

resource "aws_iam_group" "tester" {
  name = local.group_names.tester
  path = local.iam_path
}

resource "aws_iam_group_policy_attachment" "admin" {
  group      = aws_iam_group.admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_group_policy" "admin_mfa" {
  count = var.enable_mfa_enforcement ? 1 : 0
  name  = "enforce-mfa"
  group = aws_iam_group.admin.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyWithoutMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "sts:GetSessionToken"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_iam_group_policy" "developer" {
  name  = "developer-permissions"
  group = aws_iam_group.developer.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ContentAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudFrontAccess"
        Effect = "Allow"
        Action = [
          "cloudfront:GetDistribution",
          "cloudfront:GetDistributionConfig",
          "cloudfront:ListDistributions",
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsRead"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaRead"
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:GetFunctionUrlConfig",
          "lambda:ListFunctions"
        ]
        Resource = "*"
      },
      {
        Sid    = "SESRead"
        Effect = "Allow"
        Action = [
          "ses:DescribeActiveReceiptRuleSet",
          "ses:GetIdentityVerificationAttributes",
          "ses:ListIdentities"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyStateBucket"
        Effect = "Deny"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::${var.project_name}-state-*",
          "arn:aws:s3:::${var.project_name}-state-*/*"
        ]
      },
      {
        Sid    = "DenyLockTable"
        Effect = "Deny"
        Action = "dynamodb:*"
        Resource = [
          "arn:aws:dynamodb:*:*:table/${var.project_name}-terraform-locks"
        ]
      },
      {
        Sid      = "DenyIAM"
        Effect   = "Deny"
        Action   = "iam:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_group_policy" "tester_viewonly" {
  name  = "read-only-${var.project_name}"
  group = aws_iam_group.tester.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadIacTfmResources"
        Effect = "Allow"
        Action = [
          "s3:Describe*",
          "s3:GetBucket*",
          "s3:GetObject",
          "s3:ListAllMyBuckets",
          "s3:ListBucket",
          "cloudfront:Get*",
          "cloudfront:List*",
          "lambda:Get*",
          "lambda:List*",
          "logs:Describe*",
          "logs:Get*",
          "logs:List*",
          "logs:FilterLogEvents",
          "ses:Get*",
          "ses:Describe*",
          "ses:List*",
          "dynamodb:Describe*",
          "dynamodb:Get*",
          "dynamodb:List*",
          "dynamodb:Scan",
          "dynamodb:Query",
          "sns:Get*",
          "sns:List*",
          "acm:Describe*",
          "acm:List*",
          "iam:Get*",
          "iam:List*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_group_policy" "tester_invoke" {
  name  = "lambda-invoke"
  group = aws_iam_group.tester.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeContactForms"
        Effect = "Allow"
        Action = ["lambda:InvokeFunction", "lambda:InvokeFunctionUrl"]
        Resource = [
          "arn:aws:lambda:*:*:function:contact-*"
        ]
      }
    ]
  })
}

resource "aws_iam_user" "members" {
  for_each = { for m in var.team_members : m.name => m }

  name = each.value.name
  path = local.iam_path

  tags = merge(local.common_tags, {
    Role  = each.value.role
    Email = try(each.value.email, "n/a")
  })
}

resource "aws_iam_user_login_profile" "members" {
  for_each = var.enable_console_login ? { for m in var.team_members : m.name => m } : {}

  user                    = aws_iam_user.members[each.key].name
  password_reset_required = true
}

resource "aws_iam_user_group_membership" "members" {
  for_each = { for m in var.team_members : m.name => m }

  user   = aws_iam_user.members[each.key].name
  groups = [local.group_names[each.value.role]]
}

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 5
  max_password_age               = 90
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.github_org != "" && var.github_repo != "" ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "github_content" {
  count       = var.github_org != "" && var.github_repo != "" ? 1 : 0
  name        = "${var.role_name_prefix}-github-content"
  description = "GitHub Actions content deploy role (s3 sync + CloudFront invalidation)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.oidc_sub_condition
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "github_content" {
  count = var.github_org != "" && var.github_repo != "" ? 1 : 0
  name  = "content-deploy"
  role  = aws_iam_role.github_content[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-content-*",
          "arn:aws:s3:::${var.project_name}-content-*/*",
          "arn:aws:s3:::*-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::*-${data.aws_caller_identity.current.account_id}/*"
        ]
      },
      {
        Sid    = "TerraformStateReadOnly"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-state-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}",
          "arn:aws:s3:::${var.project_name}-state-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetDistribution",
          "cloudfront:ListDistributions"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "github_infra" {
  count       = var.github_org != "" && var.github_repo != "" ? 1 : 0
  name        = "${var.role_name_prefix}-github-infra"
  description = "GitHub Actions infrastructure role (terraform apply)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.oidc_sub_condition
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "github_infra" {
  count      = var.github_org != "" && var.github_repo != "" ? 1 : 0
  role       = aws_iam_role.github_infra[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
