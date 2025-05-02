resource "aws_cloudwatch_log_group" "guacamole_logs" {
  name              = "/ecs/tsvikli/guacamole"
  retention_in_days = 30
}
