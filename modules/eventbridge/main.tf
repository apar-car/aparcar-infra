resource "aws_cloudwatch_event_bus" "main" {
  name = "${var.project}-${var.environment}-event-bus"

  tags = {
    Name        = "${var.project}-${var.environment}-event-bus" 
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }  
}

resource "aws_cloudwatch_event_archive" "main" {
  name             = "${var.project}-${var.environment}-archive"
  event_source_arn =  aws_cloudwatch_event_bus.main.arn
  retention_days   =  7

  event_pattern = jsonenconde({
    source = ["aparcar.leave-signal"]
  })
}

resource "aws_schema_discoverer" "main" {
  source_arn  = aws_cloudwatch_event_bus.main.arn
  description = "Auto-discover schemas for AparCar events"

  tags = {
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }
}
