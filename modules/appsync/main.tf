resource "aws_appsync_graphql_api" "main" {
  name                = "${var.project}-${var.environment}"
  authentication_type = "API_KEY"
  schema              = file("${path.module}/schema.graphql")

  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ALL"
  }

  tags = {
    Name        = "${var.project}-${var.environment}"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_appsync_api_key" "main" {
  api_id  = aws_appsync_graphql_api.main.id
  expires = timeadd(timestamp(), "${var.api_key_expiry_days * 24}h")

  lifecycle {
    ignore_changes = [expires]
  }
}

# CloudWatch logging role for AppSync
resource "aws_iam_role" "appsync_logs" {
  name = "${var.project}-${var.environment}-appsync-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "appsync.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "appsync_logs" {
  role       = aws_iam_role.appsync_logs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppSyncPushToCloudWatchLogs"
}

# IAM role for AppSync to invoke Lambda
resource "aws_iam_role" "appsync_lambda" {
  name = "${var.project}-${var.environment}-appsync-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "appsync.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "appsync_lambda" {
  name = "${var.project}-${var.environment}-appsync-lambda-policy"
  role = aws_iam_role.appsync_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = "arn:aws:lambda:eu-west-1:*:function:${var.project}-${var.environment}-*"
    }]
  })
}

# IAM role for AppSync to access DynamoDB
resource "aws_iam_role" "appsync_dynamodb" {
  name = "${var.project}-${var.environment}-appsync-dynamodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "appsync.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "appsync_dynamodb" {
  name = "${var.project}-${var.environment}-appsync-dynamodb-policy"
  role = aws_iam_role.appsync_dynamodb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      Resource = var.parking_signals_table_arn
    }]
  })
}


# Lambda data source for leave-signal-handler
resource "aws_appsync_datasource" "leave_signal_handler" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "LeaveSignalHandler"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda.arn

  lambda_config {
    function_arn = var.leave_signal_handler_arn
  }
}

# None data source for stub mutations
resource "aws_appsync_datasource" "none" {
  api_id = aws_appsync_graphql_api.main.id
  name   = "NoneDataSource"
  type   = "NONE"
}

# DynamoDB data source
resource "aws_appsync_datasource" "parking_signals" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "ParkingSignalsTable"
  type             = "AMAZON_DYNAMODB"
  service_role_arn = aws_iam_role.appsync_dynamodb.arn

  dynamodb_config {
    table_name = var.parking_signals_table_name
    region     = "eu-west-1"
  }
}

# createParkingSignal resolver → leave-signal-handler Lambda
resource "aws_appsync_resolver" "create_parking_signal" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Mutation"
  field       = "createParkingSignal"
  data_source = aws_appsync_datasource.leave_signal_handler.name

  request_template = <<-EOT
    {
      "version": "2018-05-29",
      "operation": "Invoke",
      "payload": {
        "field": "createParkingSignal",
        "arguments": $util.toJson($ctx.args)
      }
    }
  EOT

  response_template = "$util.toJson($ctx.result)"

}

# Stub resolver — registerLookingDriver
resource "aws_appsync_resolver" "register_looking_driver" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Mutation"
  field       = "registerLookingDriver"
  data_source = aws_appsync_datasource.look_signal_handler.name

  request_template = <<-EOT
    {
      "version": "2018-05-29",
      "operation": "Invoke",
      "payload": {
        "field": "registerLookingDriver",
        "arguments": $util.toJson($ctx.args)
      }
    }
  EOT

  response_template = "$util.toJson($ctx.result)"
}

# requestSpot resolver → request-spot-handler Lambda
resource "aws_appsync_resolver" "request_spot" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Mutation"
  field       = "requestSpot"
  data_source = aws_appsync_datasource.request_spot_handler.name

  request_template = <<-EOT
    {
      "version": "2018-05-29",
      "operation": "Invoke",
      "payload": {
        "field": "requestSpot",
        "arguments": $util.toJson($ctx.args)
      }
    }
  EOT

  response_template = "$util.toJson($ctx.result)"
}

# confirmExchange resolver → confirm-exchange-handler Lambda
resource "aws_appsync_resolver" "confirm_exchange" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Mutation"
  field       = "confirmExchange"
  data_source = aws_appsync_datasource.confirm_exchange_handler.name

  request_template = <<-EOT
    {
      "version": "2018-05-29",
      "operation": "Invoke",
      "payload": {
        "field": "confirmExchange",
        "arguments": $util.toJson($ctx.args)
      }
    }
  EOT

  response_template = "$util.toJson($ctx.result)"
}

# cancelExchange resolver → cancel-exchange-handler Lambda
resource "aws_appsync_resolver" "cancel_exchange" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Mutation"
  field       = "cancelExchange"
  data_source = aws_appsync_datasource.cancel_exchange_handler.name

  request_template = <<-EOT
    {
      "version": "2018-05-29",
      "operation": "Invoke",
      "payload": {
        "field": "cancelExchange",
        "arguments": $util.toJson($ctx.args)
      }
    }
  EOT

  response_template = "$util.toJson($ctx.result)"
}

# submitRating resolver → submit-rating-handler Lambda
resource "aws_appsync_resolver" "submit_rating" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Mutation"
  field       = "submitRating"
  data_source = aws_appsync_datasource.submit_rating_handler.name

  request_template = <<-EOT
    {
      "version": "2018-05-29",
      "operation": "Invoke",
      "payload": {
        "field": "submitRating",
        "arguments": $util.toJson($ctx.args)
      }
    }
  EOT

  response_template = "$util.toJson($ctx.result)"
}

# getSignal query resolver → DynamoDB
resource "aws_appsync_resolver" "get_signal" {
  api_id      = aws_appsync_graphql_api.main.id
  type        = "Query"
  field       = "getSignal"
  data_source = aws_appsync_datasource.parking_signals.name

  request_template = <<-EOT
    {
      "version": "2018-05-29",
      "operation": "GetItem",
      "key": {
        "signalId": $util.dynamodb.toDynamoDBJson($ctx.args.signalId)
      }
    }
  EOT

  response_template = "$util.toJson($ctx.result)"

}

resource "aws_appsync_datasource" "look_signal_handler" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "LookSignalHandler"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda.arn

  lambda_config {
    function_arn = var.look_signal_handler_arn
  }
}

resource "aws_appsync_datasource" "request_spot_handler" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "RequestSpotHandler"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda.arn

  lambda_config {
    function_arn = var.request_spot_handler_arn
  }
}

resource "aws_appsync_datasource" "confirm_exchange_handler" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "ConfirmExchangeHandler"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda.arn

  lambda_config {
    function_arn = var.confirm_exchange_handler_arn
  }
}

resource "aws_appsync_datasource" "cancel_exchange_handler" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "CancelExchangeHandler"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda.arn

  lambda_config {
    function_arn = var.cancel_exchange_handler_arn
  }
}

resource "aws_appsync_datasource" "submit_rating_handler" {
  api_id           = aws_appsync_graphql_api.main.id
  name             = "SubmitRatingHandler"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.appsync_lambda.arn

  lambda_config {
    function_arn = var.submit_rating_handler_arn
  }
}