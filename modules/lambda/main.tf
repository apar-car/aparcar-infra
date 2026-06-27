data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/builds/${var.function_name}.zip"
}

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

resource "aws_iam_role_policy" "lambda" {
  name = "${var.project}-${var.environment}-${var.function_name}-policy"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:eu-west-1:*:log-group:/aws/lambda/${var.project}-${var.environment}-${var.function_name}:*"
        }
      ],
      length(var.subnet_ids) > 0 ? [
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DeleteNetworkInterface"
          ]
          Resource = [
            "arn:aws:ec2:eu-west-1:*:network-interface/*",
            "arn:aws:ec2:eu-west-1:*:subnet/*",
            "arn:aws:ec2:eu-west-1:*:security-group/*"
          ]
        },
        {
          Effect = "Allow"
          Action = [
            "ec2:DescribeNetworkInterfaces"
          ]
          Resource = "*"
        }
      ] : [],
      [for stmt in var.policy_statements : {
        Effect   = stmt.effect
        Action   = stmt.actions
        Resource = stmt.resources
      }]
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
  function_name    = "${var.project}-${var.environment}-${var.function_name}"
  role             = aws_iam_role.lambda.arn
  handler          = var.handler
  runtime          = var.runtime
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = var.timeout
  memory_size      = var.memory_size

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

