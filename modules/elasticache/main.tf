resource "aws_security_group" "redis" {
  name        = "${var.project}-${var.environment}-redis-sg"
  description = "Allow Redis access from Lambda functions"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
    description     = "Redis TLS from Lambda"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-redis-sg"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-redis-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}

resource "aws_elasticache_cluster" "main" {
  cluster_id                 = "${var.project}-${var.environment}-redis"
  engine                     = "redis"
  node_type                  = "cache.t3.micro"
  num_cache_nodes            = 1
  parameter_group_name       = "default.redis7"
  engine_version             = "7.1"
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  transit_encryption_enabled = true

  tags = {
    Name        = "${var.project}-${var.environment}-redis"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}