module "vpc" {
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/vpc?ref=cadcd9a72e23fb68d22ded10c047650d81d38e15"

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
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/lambda?ref=cadcd9a72e23fb68d22ded10c047650d81d38e15"

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
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/dynamodb?ref=cadcd9a72e23fb68d22ded10c047650d81d38e15"

  table_name  = "parking-signals"
  environment = "dev"
  project     = "aparcar"
}

module "github_oidc" {
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/github-oidc?ref=cadcd9a72e23fb68d22ded10c047650d81d38e15"

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

resource "aws_iam_role_policy" "cd_iam_bootstrap" {
  name = "CDRoleIAMBootstrap"
  role = "GitHubActions-TerraformCD"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ManageOwnPolicy"
      Effect = "Allow"
      Action = ["iam:*"]
      Resource = [
        "arn:aws:iam::945475931696:role/GitHubActions-TerraformCI",
        "arn:aws:iam::945475931696:role/GitHubActions-TerraformCD",
      ]
    }]
  })
}