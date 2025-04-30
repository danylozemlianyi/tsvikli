data "aws_secretsmanager_secret_version" "db_creds" {
  secret_id = var.db_secret_arn
}

resource "aws_cloudwatch_log_group" "guacamole_logs" {
  name              = "/ecs/tsvikli/guacamole"
  retention_in_days = 30
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "tsvikli-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "tsvikli-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "secret_manager_access" {
  name        = "SecretManagerAccessPolicy"
  description = "Policy to access Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = var.db_secret_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_secret_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.secret_manager_access.arn
}

resource "aws_ecs_cluster" "tsvikli_cluster" {
  name = "tsvikli-cluster"
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
    description     = "Allow traffic from ALB only"
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
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "tsvikli-ecs-sg"
  }
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
      image     = "guacamole/guacamole:1.5.5"
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
      image     = "guacamole/guacd:1.5.5"
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

resource "aws_acm_certificate" "guacamole_backend_cert" {
  domain_name       = "backend.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = "Tsvikli Backend"
  }
}

resource "aws_route53_record" "guacamole_backend_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.guacamole_backend_cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = var.dns_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "guacamole_backend_cert_validation" {
  certificate_arn         = aws_acm_certificate.guacamole_backend_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.guacamole_backend_cert_validation : record.fqdn]
}

resource "aws_security_group" "alb_sg" {
  name        = "tsvikli-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

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

  tags = {
    Name = "tsvikli-alb-sg"
  }
}
resource "aws_lb" "guacamole_alb" {
  name               = "tsvikli-guacamole-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "guacamole_tg" {
  name        = "tsvikli-guacamole-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/guacamole"
    interval            = 30
    timeout             = 5
    unhealthy_threshold = 3
    healthy_threshold   = 2
    matcher             = "200-399"
  }

  stickiness {
    enabled         = true
    type            = "lb_cookie"
    cookie_duration = 3600
  }
}

resource "aws_lb_listener" "guacamole_listener" {
  load_balancer_arn = aws_lb.guacamole_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.guacamole_backend_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.guacamole_tg.arn
  }
}

resource "aws_route53_record" "backend_record" {
  zone_id = var.dns_zone_id
  name    = "backend.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.guacamole_alb.dns_name
    zone_id                = aws_lb.guacamole_alb.zone_id
    evaluate_target_health = true
  }
}
