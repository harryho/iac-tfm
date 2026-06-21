variables {
  project_name     = "iac-tfm"
  role_name_prefix = "iac-prod"
  oidc_environment = "production"
  github_org       = "myorg"
  github_repo      = "my-repo"
  common_tags      = { Project = "iac-tfm" }
}

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "ap-southeast-2"
    }
  }
}

run "creates_three_iam_groups" {
  command = plan

  assert {
    condition     = aws_iam_group.admin != null
    error_message = "must create admin group"
  }
  assert {
    condition     = aws_iam_group.developer != null
    error_message = "must create developer group"
  }
  assert {
    condition     = aws_iam_group.tester != null
    error_message = "must create tester group"
  }
}

run "no_oidc_roles_when_github_not_set" {
  command = plan

  variables {
    github_org  = ""
    github_repo = ""
  }

  assert {
    condition     = length(aws_iam_role.github_content) == 0
    error_message = "github_content role must not be created when github_org is empty"
  }
  assert {
    condition     = length(aws_iam_role.github_infra) == 0
    error_message = "github_infra role must not be created when github_org is empty"
  }
}

run "oidc_roles_use_role_name_prefix" {
  command = plan

  assert {
    condition     = aws_iam_role.github_content[0].name == "iac-prod-github-content"
    error_message = "content role name must use role_name_prefix"
  }
  assert {
    condition     = aws_iam_role.github_infra[0].name == "iac-prod-github-infra"
    error_message = "infra role name must use role_name_prefix"
  }
}

run "oidc_sub_includes_repo" {
  command = plan

  assert {
    condition     = strcontains(local.oidc_sub_condition, "repo:myorg/my-repo")
    error_message = "OIDC sub condition must pin to repo:myorg/my-repo"
  }
}

run "oidc_sub_includes_environment" {
  command = plan

  assert {
    condition     = strcontains(local.oidc_sub_condition, "environment:production")
    error_message = "OIDC sub condition must include environment when oidc_environment is set"
  }
}
