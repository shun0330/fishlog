# ===== ログの保存先 =====
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7
}

# ===== ECSクラスター =====
resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"
}

# ===== タスク実行ロール（ECSがAWSの操作をするための権限） =====
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_db_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.main.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_role_policy" "read_db_secret" {
  name   = "${var.project}-read-db-secret"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.read_db_secret.json
}

# ===== タスク定義（コンテナの起動設定） =====
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true
      portMappings = [
        { containerPort = 8000, protocol = "tcp" }
      ]
      environment = [
        { name = "DB_HOST", value = aws_db_instance.main.address },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_NAME", value = aws_db_instance.main.db_name },
        { name = "DB_USER", value = aws_db_instance.main.username }
      ]
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_db_instance.main.master_user_secret[0].secret_arn}:password::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])
}

# ===== ECSサービス（タスクを動かし続ける） =====
resource "aws_ecs_service" "app" {
  name            = "${var.project}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.private_1a.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 8000
  }

  health_check_grace_period_seconds = 60

  depends_on = [aws_lb_listener.http]
}
