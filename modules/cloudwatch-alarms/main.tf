# ─── SNS Topic ────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "alarms" {
  name              = "${var.project}-${var.environment}-alarms"
  kms_master_key_id = "alias/aws/sns"

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_sns_topic_subscription" "slack" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
}

# ─── DLQ Alarms ───────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "dlq_messages_visible" {
  alarm_name          = "${var.project}-${var.environment}-dlq-messages-visible"
  alarm_description   = "Messages in DLQ - Lambda invocation failed permanently"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = var.dlq_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ─── Lambda Alarms ────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project}-${var.environment}-lambda-${var.lambda_function_name}-errors"
  alarm_description   = "Lambda function errors - invocation failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project}-${var.environment}-lambda-${var.lambda_function_name}-throttles"
  alarm_description   = "Lambda throttles - hitting concurrency limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project}-${var.environment}-lambda-${var.lambda_function_name}-duration"
  alarm_description   = "Lambda duration approaching timeout (${var.lambda_timeout_ms}ms threshold)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p99"
  threshold           = var.lambda_timeout_ms
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_concurrent_executions" {
  alarm_name          = "${var.project}-${var.environment}-lambda-${var.lambda_function_name}-concurrency"
  alarm_description   = "Lambda concurrent executions approaching account limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ConcurrentExecutions"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.lambda_concurrent_executions_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

# ─── AppSync Alarms ───────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "appsync_5xx" {
  alarm_name          = "${var.project}-${var.environment}-appsync-5xx-errors"
  alarm_description   = "AppSync 5XX errors - resolver failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/AppSync"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    GraphQLAPIId = var.appsync_api_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "appsync_4xx" {
  alarm_name          = "${var.project}-${var.environment}-appsync-4xx-errors"
  alarm_description   = "AppSync 4XX errors - auth failures or bad requests (threshold: ${var.appsync_4xx_threshold} per 5min)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4XXError"
  namespace           = "AWS/AppSync"
  period              = 300
  statistic           = "Sum"
  threshold           = var.appsync_4xx_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    GraphQLAPIId = var.appsync_api_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_metric_alarm" "appsync_latency" {
  alarm_name          = "${var.project}-${var.environment}-appsync-latency"
  alarm_description   = "AppSync p99 latency above ${var.appsync_latency_threshold_ms}ms"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Latency"
  namespace           = "AWS/AppSync"
  period              = 60
  extended_statistic  = "p99"
  threshold           = var.appsync_latency_threshold_ms
  treat_missing_data  = "notBreaching"

  dimensions = {
    GraphQLAPIId = var.appsync_api_id
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}