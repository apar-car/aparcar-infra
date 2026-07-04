module "vpc" {
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/vpc?ref=70ea4d903728a475f009f1ce2e4132604e288911"

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
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/lambda?ref=70ea4d903728a475f009f1ce2e4132604e288911"

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
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/dynamodb?ref=70ea4d903728a475f009f1ce2e4132604e288911"

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
  source = "../../modules/lambda"

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
    PARKING_TABLE = "aparcar-dev-parking-signals"
    REDIS_HOST    = module.elasticache.redis_endpoint
    REDIS_PORT    = "6379"
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