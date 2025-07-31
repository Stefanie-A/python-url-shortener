data "aws_vpc" "default" {
  default = true
}


#Lambda Funciton
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_policy.json
}


data "archive_file" "lambda_zip" {
  excludes = [
    ".git/*",
    ".terraform/*",
    ".vscode/*",
    "terraform.tfstate*",
    "terraform.tfvars*",
    "*.tf",
    "*.tfvars",
    "*.gitignore",
    "*.gitmodules",
    "*.DS_Store",
    "*.zip",
    "*.tar.gz",
    "*.tar",
    "*.exe",
    "*.bin",
    "*.tf",
    "*.tfstate",
    "*.tfstate.backup",
    "*.tfstate.backup.*",
    ".terraform",
    ".git",
    ".gitignore",
  ]
  type        = "zip"
  source_dir  = "${path.module}/./app"
  output_path = "${path.module}/deployment-package.zip"
}

resource "aws_lambda_function" "lambda_func" {
  function_name = var.lambda_name
  role          = aws_iam_role.lambda_role.arn
  handler       = var.lambda_handler
  runtime       = "python3.12"

  filename = data.archive_file.lambda_zip.output_path

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      foo = "bar"
    }
  }
}

#API Gateway
resource "aws_api_gateway_rest_api" "api_gateway" {
  name = var.api_gateway_name
}

resource "aws_api_gateway_resource" "api_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "shorten"
}

resource "aws_api_gateway_method" "api_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.api_resource.id
  http_method             = aws_api_gateway_method.api_method.http_method
  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_func.invoke_arn
}

resource "aws_api_gateway_method_response" "api_response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.api_method.http_method
  status_code = "200"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.api_gateway.execution_arn}/*/*/*"
}

resource "aws_api_gateway_api_key" "api_key" {
  name        = "url-shortener-api-key"
  description = "API Key for URL Shortener"
  enabled     = true
}

resource "aws_ecr_repository" "ecr_repository" {
  name                 = "url-repo"
  image_tag_mutability = "IMMUTABLE"
  tags = {
    Name = "url-repo"
  }
  lifecycle {
    prevent_destroy = false
  }

}

# ECS Cluster and Service
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "white-hart"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  depends_on = [aws_iam_role_policy.ecs_task_policy]

  container_definitions = jsonencode([
    {
      name      = "first",
      image     = "service-first",
      cpu       = 10,
      memory    = 512,
      essential = true,
      portMappings = [
        {
          containerPort = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "ecs_service" {
  name            = "mongodb"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  launch_type     = "FARGATE"
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 3
  scheduling_strategy = "REPLICA"

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }
  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }
  
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecstask_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "ecstask_policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}