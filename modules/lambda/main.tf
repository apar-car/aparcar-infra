
# Lambda IAM Role
resource "aws_iam_role" "lambda" {
  name = "${var.project}-${var.environment}-${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

locals {
  base_statements = [
    {
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:eu-west-1:*:log-group:/aws/lambda/${var.project}-${var.environment}-${var.function_name}:*"
    },
    {
      Effect   = "Allow"
      Action   = ["sqs:SendMessage"]
      Resource = aws_sqs_queue.dlq.arn
    }
  ]

  ec2_statement = {
    Effect = "Allow"
    Action = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces"
    ]
    Resource = "*"
  }

  custom_statements = [for stmt in var.policy_statements : {
    Effect   = stmt.effect
    Action   = stmt.actions
    Resource = stmt.resources
  }]
}

resource "aws_iam_role_policy" "lambda" {
  name = "${var.project}-${var.environment}-${var.function_name}-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      local.base_statements,
      length(var.subnet_ids) > 0 ? [local.ec2_statement] : [],
      local.custom_statements
    )
  })
}


# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.project}-${var.environment}-${var.function_name}"
  retention_in_days = 365

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# Lambda function
resource "aws_lambda_function" "main" {
  function_name                  = "${var.project}-${var.environment}-${var.function_name}"
  role                           = aws_iam_role.lambda.arn
  handler                        = var.handler
  runtime                        = var.runtime
  filename                       = var.zip_path
  source_code_hash               = filebase64sha256(var.zip_path)
  timeout                        = var.timeout
  memory_size                    = var.memory_size
  reserved_concurrent_executions = var.reserved_concurrent_executions

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  environment {
    variables = var.environment_variables
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda,
    aws_cloudwatch_log_group.lambda
  ]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# SQS DLQ 
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project}-${var.environment}-${var.function_name}-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = "alias/aws/sqs"

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

