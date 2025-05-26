data "aws_vpc" "default" {
  default = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_subnet" "private_sub" {
  count             = 2
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "Main"
  }
}

resource "aws_eip" "nat" {
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = data.aws_subnets.default.ids[0]
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "privatesub-rt" {
  vpc_id = data.aws_vpc.default.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
}
resource "aws_route_table_association" "privatesub-rt-assoc" {
  count          = length(aws_subnet.private_sub)
  subnet_id      = aws_subnet.private_sub[count.index].id
  route_table_id = aws_route_table.privatesub-rt.id
}


resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private_sub[*].id
  security_group_ids = [aws_security_group.ecs_security_group.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private_sub[*].id
  security_group_ids = [aws_security_group.ecs_security_group.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.privatesub-rt.id]
}

resource "aws_security_group" "elb_security_group" {
  name        = "elb_security_group"
  description = "Allow traffic to ECS tasks"
  vpc_id      = data.aws_vpc.default.id

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

resource "aws_security_group" "ecs_security_group" {
  name        = "ecs_security_group"
  description = "Allow traffic to ECS tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.elb_security_group.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ecs_security_group"
  }
}

resource "aws_lb" "main_alb" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_security_group.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "app_tg" {
  name        = "app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
  health_check {
    path                = "/"
    matcher             = 200
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
resource "aws_dynamodb_table" "dynamodb_table" {
  name           = var.dynamodb_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "shorten-uri"

  # Define table attributes
  attribute {
    name = "shorten-uri"
    type = "S"
  }

  attribute {
    name = "original-uri"
    type = "S"
  }

  # Global Secondary Index for querying by original URI
  global_secondary_index {
    name            = "original-uri-index"
    hash_key        = "original-uri"
    write_capacity  = 10
    read_capacity   = 10
    projection_type = "ALL"
  }

  tags = {
    Name = "uriTable"
  }
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

resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.api_resource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.api_resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "GET"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_func.invoke_arn
}

resource "aws_api_gateway_method_response" "response" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  resource_id = aws_api_gateway_resource.api_resource.id
  http_method = aws_api_gateway_method.method.http_method
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




resource "aws_ecs_cluster" "ecs_cluster" {
  name = "url-cluster"
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task (Permissions your application needs, e.g., DynamoDB, S3)
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

# Attach policies for your application (e.g., DynamoDB,)
# IMPORTANT: Replace these with the actual ARNs or create custom policies for least privilege.
resource "aws_iam_role_policy_attachment" "ecs_task_dynamodb_access" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_access" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess" # Adjust for least privilege
}

# CloudWatch Log Group for ECS Task Logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ecs/ecs-task"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "task_definition" {
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  family                   = "url-repo-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([
    {
      name      = "url-container"
      image     = "${aws_ecr_repository.ecr_repository.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
          "awslogs-region"        = "us-east-1" # Change to your region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = [
        {
          name  = "DYNAMODB_TABLE_NAME"
          value = aws_dynamodb_table.dynamodb_table.name
        },
        {
          name  = "LAMBDA_NAME"
          value = aws_lambda_function.lambda_func.function_name
        }
      ]
    }
  ])
}
resource "aws_ecs_service" "ecs_service" {
  name            = "url-repo-service"
  task_definition = aws_ecs_task_definition.task_definition.arn
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 2
  launch_type     ="FARGATE"

  network_configuration {
    subnets          = aws_subnet.private_sub[*].id
    security_groups  = [aws_security_group.ecs_security_group.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "url-container"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.http_listener, aws_iam_role.ecs_task_execution_role]
}




