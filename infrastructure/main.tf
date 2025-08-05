resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyVPC"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MyVpc_Igw"
  }
}

resource "aws_subnet" "public_subnet_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet_1a"
  }
}

resource "aws_subnet" "public_subnet_1b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet_1b"
  }
}
resource "aws_route_table" "new_rt_table" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "new route table"
  }
}
resource "aws_route_table_association" "rt_table_association_a" {
  route_table_id = aws_route_table.new_rt_table.id
  subnet_id      = aws_subnet.public_subnet_1a.id
}
resource "aws_route_table_association" "rt_table_association_b" {
  route_table_id = aws_route_table.new_rt_table.id
  subnet_id      = aws_subnet.public_subnet_1b.id
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
  name                 = "url-image"
  image_tag_mutability = "IMMUTABLE"
  tags = {
    Name = "url-repo"
  }
  lifecycle {
    prevent_destroy = false
  }

}

# ECS Cluster and Service
resource "aws_security_group" "ecs_security_group" {
  name        = "ecs_security_group"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "url-repo-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs_execution_role"
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
resource "aws_iam_role_policy" "ecs_execution_policy" {
  name = "ecs_execution_policy"
  role = aws_iam_role.ecs_execution_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ],
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  depends_on = [
    aws_iam_role.ecs_execution_role
  ]

  container_definitions = jsonencode([
    {
      name      = "uri-image",
      image     = "902839103466.dkr.ecr.us-east-1.amazonaws.com/url-image:latest",
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
  name                = "url-repo-service"
  cluster             = aws_ecs_cluster.ecs_cluster.id
  launch_type         = "FARGATE"
  task_definition     = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count       = 2
  scheduling_strategy = "REPLICA"
  network_configuration {
    subnets          = [aws_subnet.public_subnet_1a.id, aws_subnet.public_subnet_1b.id]
    security_groups  = [aws_security_group.ecs_security_group.id]
    assign_public_ip = true
  }

}