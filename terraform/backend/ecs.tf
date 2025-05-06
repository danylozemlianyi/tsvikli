resource "aws_ecs_cluster" "tsvikli_cluster" {
  name = "tsvikli-cluster"
}

resource "aws_ecs_task_definition" "guacamole_task" {
  family                   = "tsvikli-guacamole"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "guacamole"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/tsvikli/guacamole:latest"
      essential = true
      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
      }]
      environment = [
        { name = "GUACD_HOSTNAME", value = "localhost" },
        { name = "MYSQL_HOSTNAME", value = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["host"] },
        { name = "MYSQL_DATABASE", value = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["dbname"] },
        { name = "MYSQL_USER", value = "guacamole_user" },
        { name = "MYSQL_PASSWORD", value = jsondecode(data.aws_secretsmanager_secret_version.db_creds.secret_string)["password"] }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.guacamole_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "guacamole"
        }
      }
    },
    {
      name      = "guacd"
      image     = "guacamole/guacd:1.5.5"  # Configuration is not necessary, thus original image is used
      essential = true
      portMappings = [{
        containerPort = 4822
        hostPort      = 4822
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.guacamole_logs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "guacd"
        }
      }
    }
  ])
}

resource "aws_security_group" "ecs_sg" {
  name        = "tsvikli-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port = 4822
    to_port   = 4822
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tsvikli-ecs-sg"
  }
}

resource "aws_ecs_service" "guacamole_service" {
  name            = "tsvikli-guacamole-service"
  cluster         = aws_ecs_cluster.tsvikli_cluster.id
  task_definition = aws_ecs_task_definition.guacamole_task.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_sg.id]
    subnets          = var.private_subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.guacamole_tg.arn
    container_name   = "guacamole"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.guacamole_listener]
}

resource "aws_appautoscaling_target" "guacamole_scaling_target" {
  max_capacity       = 6
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.tsvikli_cluster.name}/${aws_ecs_service.guacamole_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "guacamole_cpu_scaling_policy" {
  name               = "tsvikli-guacamole-cpu-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.guacamole_scaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.guacamole_scaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.guacamole_scaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 20
  }
}
