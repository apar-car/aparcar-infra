locals {
  github_oidc_arn = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

resource "aws_iam_role" "ci" {
  name        = "GitHubActions-TerraformCI"
  description = "GitHub Actions OIDC role for Terraform CI plan-only"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.github_oidc_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role" "cd" {
  name        = "GitHubActions-TerraformCD"
  description = "GitHub Actions OIDC role for Terraform CD apply - main branch only"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.github_oidc_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy" "ci" {
  name = "TerraformPlanOnly"
  role = aws_iam_role.ci.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket}",
          "arn:aws:s3:::${var.state_bucket}/*"
        ]
      },
      {
        Sid    = "TerraformLockAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:eu-west-1:022079552075:table/${var.lock_table}"
      },
      {
        Sid    = "TerraformPlanRead"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:Get*",
          "ec2:List*",
          "lambda:Get*",
          "lambda:List*",
          "dynamodb:Describe*",
          "dynamodb:List*",
          "dynamodb:ListTagsOfResource",
          "elasticache:Describe*",
          "elasticache:List*",
          "appsync:Get*",
          "appsync:List*",
          "events:Describe*",
          "events:List*",
          "iam:Get*",
          "iam:List*",
          "s3:Get*",
          "s3:List*",
          "logs:Describe*",
          "logs:List*",
          "logs:Get*",
          "logs:ListTagsForResource",
          "sqs:Get*",
          "sqs:List*",
          "schemas:Describe*",
          "schemas:List*",
          "schemas:Get*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "cd" {
  name = "TerraformApply"
  role = aws_iam_role.cd.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket}",
          "arn:aws:s3:::${var.state_bucket}/*"
        ]
      },
      {
        Sid    = "TerraformLockAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:eu-west-1:022079552075:table/${var.lock_table}"
      },
      {
        Sid    = "LambdaManage"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListFunctions",
          "lambda:ListVersionsByFunction",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags",
          "lambda:PutFunctionConcurrency",
          "lambda:DeleteFunctionConcurrency",
          "lambda:GetPolicy",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:InvokeFunction",
          "lambda:GetFunctionCodeSigningConfig",
          "lambda:GetRuntimeManagementConfig"
        ]
        Resource = "arn:aws:lambda:eu-west-1:${var.account_id}:function:${var.project}-*"
      },
      {
        Sid    = "IAMManage"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:ListRoles",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListOpenIDConnectProviders",
          "iam:GetOpenIDConnectProvider",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::${var.account_id}:role/${var.project}-*",
          "arn:aws:iam::${var.account_id}:role/GitHubActions-*"
        ]
      },
      {
        Sid    = "DynamoDBManage"
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeTable",
          "dynamodb:UpdateTable",
          "dynamodb:ListTables",
          "dynamodb:TagResource",
          "dynamodb:UntagResource",
          "dynamodb:ListTagsOfResource",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:UpdateTimeToLive",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:UpdateContinuousBackups",
          "dynamodb:DescribeContributorInsights",
          "dynamodb:DescribeKinesisStreamingDestination",
          "dynamodb:DescribeTableReplicaAutoScaling"
        ]
        Resource = "arn:aws:dynamodb:eu-west-1:${var.account_id}:table/${var.project}-*"
      },
      {
        Sid    = "EC2VPCManage"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:DescribeVpcs",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:DescribeSubnets",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:DescribeRouteTables",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:DescribeInternetGateways",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:DescribeNatGateways",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:DescribeAddresses",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateVpcEndpoint",
          "ec2:DeleteVpcEndpoints",
          "ec2:DescribeVpcEndpoints",
          "ec2:ModifyVpcEndpoint",
          "ec2:DescribeFlowLogs",
          "ec2:CreateFlowLogs",
          "ec2:DeleteFlowLogs",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeTags",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribePrefixLists",
          "ec2:ModifySubnetAttribute",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeVpcAttribute"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchManage"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy",
          "logs:DeleteRetentionPolicy",
          "logs:TagLogGroup",
          "logs:UntagLogGroup",
          "logs:ListTagsLogGroup",
          "logs:ListTagsForResource",
          "logs:TagResource",
          "logs:UntagResource",
          "logs:CreateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:DescribeResourcePolicies",
          "logs:PutResourcePolicy",
          "logs:DeleteResourcePolicy"
        ]
        Resource = "*"
      },
      {
        Sid    = "SQSManage"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:SetQueueAttributes",
          "sqs:ListQueues",
          "sqs:TagQueue",
          "sqs:UntagQueue",
          "sqs:GetQueueUrl",
          "sqs:ListQueueTags"
        ]
        Resource = "arn:aws:sqs:eu-west-1:${var.account_id}:${var.project}-*"
      },
      {
        Sid    = "EventBridgeManage"
        Effect = "Allow"
        Action = [
          "events:CreateEventBus",
          "events:DeleteEventBus",
          "events:DescribeEventBus",
          "events:ListEventBuses",
          "events:PutRule",
          "events:DeleteRule",
          "events:DescribeRule",
          "events:ListRules",
          "events:PutTargets",
          "events:RemoveTargets",
          "events:ListTargetsByRule",
          "events:TagResource",
          "events:UntagResource",
          "events:ListTagsForResource",
          "events:DescribeArchive",
          "events:ListArchives",
          "schemas:CreateDiscoverer",
          "schemas:DeleteDiscoverer",
          "schemas:DescribeDiscoverer",
          "schemas:UpdateDiscoverer",
          "schemas:ListDiscoverers",
          "schemas:TagResource",
          "schemas:UntagResource",
          "schemas:ListTagsForResource"
          
        ]
        Resource = "arn:aws:events:eu-west-1:${var.account_id}:*"
      },
      {
        Sid    = "ElastiCacheManage"
        Effect = "Allow"
        Action = [
          "elasticache:CreateCacheCluster",
          "elasticache:DeleteCacheCluster",
          "elasticache:DescribeCacheClusters",
          "elasticache:ModifyCacheCluster",
          "elasticache:CreateReplicationGroup",
          "elasticache:DeleteReplicationGroup",
          "elasticache:DescribeReplicationGroups",
          "elasticache:ModifyReplicationGroup",
          "elasticache:CreateCacheSubnetGroup",
          "elasticache:DeleteCacheSubnetGroup",
          "elasticache:DescribeCacheSubnetGroups",
          "elasticache:AddTagsToResource",
          "elasticache:RemoveTagsFromResource",
          "elasticache:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "AppSyncManage"
        Effect = "Allow"
        Action = [
          "appsync:CreateGraphqlApi",
          "appsync:DeleteGraphqlApi",
          "appsync:GetGraphqlApi",
          "appsync:ListGraphqlApis",
          "appsync:UpdateGraphqlApi",
          "appsync:CreateDataSource",
          "appsync:DeleteDataSource",
          "appsync:GetDataSource",
          "appsync:ListDataSources",
          "appsync:CreateResolver",
          "appsync:DeleteResolver",
          "appsync:GetResolver",
          "appsync:UpdateResolver",
          "appsync:StartSchemaCreation",
          "appsync:GetSchemaCreationStatus",
          "appsync:TagResource",
          "appsync:UntagResource",
          "appsync:ListTagsForResource",
          "appsync:CreateApiKey",
          "appsync:DeleteApiKey",
          "appsync:ListApiKeys",
          "appsync:UpdateApiKey"
        ]
        Resource = "*"
      }
    ]
  })
}