output "ci_role_arn" {
  description = "GitHub Actions CI role ARN"
  value       = aws_iam_role.ci.arn
}

output "cd_role_arn" {
  description = "GitHub Actions CD role ARN"
  value       = aws_iam_role.cd.arn
}
