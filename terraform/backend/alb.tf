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
