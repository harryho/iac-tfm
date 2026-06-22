output "group_names" {
  description = "IAM group names by role"
  value = {
    admin     = aws_iam_group.admin.name
    developer = aws_iam_group.developer.name
    tester    = aws_iam_group.tester.name
  }
}

output "group_arns" {
  description = "IAM group ARNs by role"
  value = {
    admin     = aws_iam_group.admin.arn
    developer = aws_iam_group.developer.arn
    tester    = aws_iam_group.tester.arn
  }
}

output "user_names" {
  description = "Created IAM user names"
  value       = [for u in aws_iam_user.members : u.name]
}

output "user_arns" {
  description = "Created IAM user ARNs with their roles"
  value = {
    for k, u in aws_iam_user.members : k => {
      arn  = u.arn
      role = u.tags.Role
    }
  }
}

output "github_content_role_arn" {
  description = "GitHub Actions content deploy role ARN (empty if OIDC not configured)"
  value       = var.github_org != "" && var.github_repo != "" ? aws_iam_role.github_content[0].arn : ""
}

output "github_infra_role_arn" {
  description = "GitHub Actions infra role ARN (empty if OIDC not configured)"
  value       = var.github_org != "" && var.github_repo != "" ? aws_iam_role.github_infra[0].arn : ""
}
