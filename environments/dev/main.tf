module "vpc" {
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/vpc?ref=d0febd947de35c17cd0c46217da09131c4108403"

  environment          = "dev"
  vpc_cidr             = "10.16.0.0/16"
  private_subnet_cidrs = ["10.16.1.0/24", "10.16.2.0/24"]
  availability_zones   = ["eu-west-1a", "eu-west-1b"]
  project              = "aparcar"
  enable_nat_gateway   = false
}

# Lambda Module
data "archive_file" "leave_signal_handler" {
  type        = "zip"
  source_dir  = "${path.root}/../../src/leave-signal-handler"
  output_path = "${path.root}/builds/leave-signal-handler.zip"
}


module "leave_signal_handler" {
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/lambda?ref=d0febd947de35c17cd0c46217da09131c4108403"

  function_name                  = "leave-signal-handler"
  zip_path                       = data.archive_file.leave_signal_handler.output_path
  environment                    = "dev"
  project                        = "aparcar"
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = -1

  environment_variables = {
    PARKING_TABLE  = "aparcar-dev-parking-signals"
    EVENT_BUS_NAME = "aparcar-dev-event-bus"
  }

  policy_statements = [
    {
      effect    = "Allow"
      actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem"]
      resources = ["arn:aws:dynamodb:eu-west-1:945475931696:table/aparcar-dev-parking-signals"]
    },
    {
      effect    = "Allow"
      actions   = ["events:PutEvents"]
      resources = ["arn:aws:events:eu-west-1:945475931696:event-bus/aparcar-dev-event-bus"]
    }
  ]
}

module "parking_signals_table" {
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/dynamodb?ref=d0febd947de35c17cd0c46217da09131c4108403"

  table_name  = "parking-signals"
  environment = "dev"
  project     = "aparcar"
}

module "github_oidc" {
  source       = "../../modules/github-oidc"
  environment  = "dev"
  project      = "aparcar"
  account_id   = "945475931696"
  state_bucket = "aparcar-terraform-state-022079552075"
  lock_table   = "aparcar-terraform-locks"
}

module "eventbridge" {
  source = "../../modules/eventbridge"

  environment = "dev"
  project     = "aparcar"
}

# AppSync

module "appsync" {
  source = "../../modules/appsync"

  environment                = "dev"
  project                    = "aparcar"
  leave_signal_handler_arn   = module.leave_signal_handler.function_arn
  parking_signals_table_arn  = module.parking_signals_table.table_arn
  parking_signals_table_name = module.parking_signals_table.table_name
  look_signal_handler_arn    = module.look_signal_handler.function_arn
}

module "cloudwatch_alarms" {
  source = "../../modules/cloudwatch-alarms"

  environment          = "dev"
  project              = "aparcar"
  slack_webhook_url    = var.slack_webhook_url
  lambda_function_name = module.leave_signal_handler.function_name
  dlq_name             = "aparcar-dev-leave-signal-handler-dlq"
  appsync_api_id       = module.appsync.api_id
}

module "elasticache" {
  source = "../../modules/elasticache"

  environment = "dev"
  project     = "aparcar"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids
  vpc_cidr    = "10.16.0.0/16"
}

# Shared security group for VPC-bound Lambdas
resource "aws_security_group" "lambda_vpc" {
  name        = "aparcar-dev-lambda-vpc-sg"
  description = "Security group for VPC-bound Lambda functions"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr]
    description = "Allow outbound to VPC"
  }

  tags = {
    Name        = "aparcar-dev-lambda-vpc-sg"
    Environment = "dev"
    Project     = "aparcar"
    ManagedBy   = "terraform"
  }
}

# Archive for look-signal-handler
data "archive_file" "look_signal_handler" {
  type        = "zip"
  source_dir  = "${path.root}/../../src/look-signal-handler"
  output_path = "${path.root}/builds/look-signal-handler.zip"
}

module "look_signal_handler" {
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/lambda?ref=d0febd947de35c17cd0c46217da09131c4108403"

  function_name                  = "look-signal-handler"
  zip_path                       = data.archive_file.look_signal_handler.output_path
  environment                    = "dev"
  project                        = "aparcar"
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = -1
  subnet_ids                     = module.vpc.private_subnet_ids
  security_group_ids             = [aws_security_group.lambda_vpc.id]

  environment_variables = {
    PARKING_TABLE     = "aparcar-dev-parking-signals"
    REDIS_HOST        = module.elasticache.redis_endpoint
    REDIS_PORT        = "6379"
    DYNAMODB_ENDPOINT = module.vpc.dynamodb_endpoint_url
  }

  policy_statements = [
    {
      effect    = "Allow"
      actions   = ["dynamodb:PutItem", "dynamodb:GetItem"]
      resources = ["arn:aws:dynamodb:eu-west-1:945475931696:table/aparcar-dev-parking-signals"]
    }
  ]
}

resource "aws_security_group_rule" "redis_from_lambda" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda_vpc.id
  security_group_id        = module.elasticache.redis_security_group_id
  description              = "Redis access from VPC Lambda functions"
}

# Archive for notification-dispatcher
data "archive_file" "notification_dispatcher" {
  type        = "zip"
  source_dir  = "${path.root}/../../src/notification-dispatcher"
  output_path = "${path.root}/builds/notification-dispatcher.zip"
}

module "notification_dispatcher" {
  source = "../../modules/lambda"

  function_name                  = "notification-dispatcher"
  zip_path                       = data.archive_file.notification_dispatcher.output_path
  environment                    = "dev"
  project                        = "aparcar"
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = -1

  environment_variables = {
    PARKING_TABLE = "aparcar-dev-parking-signals"
  }

  policy_statements = []
}

# Archive for radius-matcher
data "archive_file" "radius_matcher" {
  type        = "zip"
  source_dir  = "${path.root}/../../src/radius-matcher"
  output_path = "${path.root}/builds/radius-matcher.zip"
}

module "radius_matcher" {
  source = "../../modules/lambda"

  function_name                  = "radius-matcher"
  zip_path                       = data.archive_file.radius_matcher.output_path
  environment                    = "dev"
  project                        = "aparcar"
  timeout                        = 30
  memory_size                    = 128
  reserved_concurrent_executions = -1
  subnet_ids                     = module.vpc.private_subnet_ids
  security_group_ids             = [aws_security_group.lambda_vpc.id]

  environment_variables = {
    REDIS_HOST                  = module.elasticache.redis_endpoint
    REDIS_PORT                  = "6379"
    DYNAMODB_ENDPOINT           = module.vpc.dynamodb_endpoint_url
    LAMBDA_ENDPOINT             = module.vpc.lambda_endpoint_url
    NOTIFICATION_DISPATCHER_ARN = module.notification_dispatcher.function_arn
  }

  policy_statements = [
    {
      effect    = "Allow"
      actions   = ["lambda:InvokeFunction"]
      resources = [module.notification_dispatcher.function_arn]
    }
  ]
}

# EventBridge rule — ParkingSpotLeaving → radius-matcher
resource "aws_cloudwatch_event_rule" "parking_spot_leaving" {
  name           = "aparcar-dev-parking-spot-leaving"
  description    = "Route ParkingSpotLeaving events to radius-matcher"
  event_bus_name = module.eventbridge.event_bus_name

  event_pattern = jsonencode({
    source      = ["aparcar.leave-signal"]
    detail-type = ["ParkingSpotLeaving"]
  })

  tags = {
    Environment = "dev"
    Project     = "aparcar"
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_event_target" "radius_matcher" {
  rule           = aws_cloudwatch_event_rule.parking_spot_leaving.name
  event_bus_name = module.eventbridge.event_bus_name
  target_id      = "radius-matcher"
  arn            = module.radius_matcher.function_arn
}

resource "aws_lambda_permission" "eventbridge_radius_matcher" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.radius_matcher.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.parking_spot_leaving.arn
}

resource "aws_lambda_permission" "radius_matcher_invoke_notifier" {
  statement_id  = "AllowRadiusMatcherInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.notification_dispatcher.function_name
  principal     = "lambda.amazonaws.com"
  source_arn    = module.radius_matcher.function_arn
}