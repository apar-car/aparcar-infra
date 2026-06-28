module "vpc" {
  source = "git::https://github.com/apar-car/aparcar-infra.git//modules/vpc?ref=24dfc78a0aea9f4125069bfee32c6c1af3275486"

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
  source = "../../modules/lambda"

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