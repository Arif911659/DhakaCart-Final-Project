# ============================================
# Backend Target Group and ALB Listener Rules
# ============================================
# This file adds backend target group and path-based routing
# for /api* requests to backend service
# 
# Note: Frontend target group already exists in main.tf as aws_lb_target_group.app
# This file adds backend target group and listener rules

# Backend Target Group (Port 30081) - with WebSocket support
resource "aws_lb_target_group" "backend" {
  name     = "${var.cluster_name}-backend-tg"
  port     = 30081  # Fixed Backend NodePort
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Enable WebSocket support
  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  # Enable connection draining
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"  # Backend health endpoint (ALB checks target directly)
    port                = "30081"
    protocol            = "HTTP"
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.cluster_name}-backend-tg"
  }
}

# Register Worker nodes to Backend Target Group
resource "aws_lb_target_group_attachment" "backend_workers" {
  count = var.worker_count

  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.workers[count.index].id
  port             = 30081
}

# ALB Listener Rule: /api* and /ws* → Backend Target Group (for WebSocket support)
resource "aws_lb_listener_rule" "backend_api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  condition {
    path_pattern {
      values = ["/api*", "/ws", "/ws/*"]
    }
  }
}

# Note: Default action (all other paths → Frontend) is already configured
# in main.tf as aws_lb_listener.http.default_action pointing to aws_lb_target_group.app

