Risk Mitigation Entry 1: Hardcoded Secrets Exposure
Risk: Hardcoded production database credentials (DB_PASSWORD) in Terraform code expose database access keys to anyone with Git repository access.

Likelihood: High — Any developer, automated scanner, or CI/CD runner pulling this repository can read plain-text secrets directly from version control history.

Impact: Unauthenticated access to KijaniKiosk's core payment database leading to severe data breaches, ransomware risk, and compliance penalties.

Mitigation: Remove the hardcoded string from aws_lambda_function.receipt_processor. Replace DB_PASSWORD = "kijani-prod-password-2024" with dynamic secret lookup from AWS Secrets Manager:

Terraform
data "aws_secretsmanager_secret_version" "db_secret" {
  secret_id = "kk-payments/prod/db-password"
}

resource "aws_lambda_function" "receipt_processor" {
  # ...
  environment {
    variables = {
      DB_PASSWORD = data.aws_secretsmanager_secret_version.db_secret.secret_string
      NODE_ENV    = "production"
    }
  }
}
Residual Risk: IAM permissions governing access to kk-payments/prod/db-password in AWS Secrets Manager must be strictly restricted; anyone with secretsmanager:GetSecretValue rights can still view the password.
Risk Mitigation Entry 2: Overly Permissive IAM Policy (Wildcard Permissions)
Risk: Attaching Action: ["s3:*"] and Resource: ["*"] grants the Lambda function full administrative rights across every S3 bucket in the AWS account.

Likelihood: High — AI-generated templates regularly default to wildcards to guarantee execution without permissions errors during initial testing.

Impact: A remote code execution vulnerability in the Lambda runtime could allow an attacker to delete, tamper with, or exfiltrate all S3 data across the entire AWS organization.

Mitigation: Modify the aws_iam_role_policy.receipts_processor_policy inline policy block to enforce strict least-privilege scoping:

Terraform
resource "aws_iam_role_policy" "receipts_processor_policy" {
  name = "receipts-processor-policy"
  role = aws_iam_role.receipts_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = ["${aws_s3_bucket.payment_receipts.arn}/*"]
    }]
  })
}
Residual Risk: If the Lambda handler function is updated in the future to perform additional operations (such as listing bucket objects via s3:ListBucket), the pipeline execution will fail until an engineer manually updates the IAM policy statement.
