resource "aws_dynamodb_table" "main" {
  name         = "${var.project}-${var.environment}-${var.table_name}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "signalId"

  attribute {
    name = "signalId"
    type = "S"
  }

  dynamic "attribute" {
    for_each = var.additional_attributes
    content {
        name = attribute.value.name
        type = attribute.value.type
    }
  }

  ttl {
    attribute_name = var.ttl_attribute
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  deletion_protection_enabled = true

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
        name               = global_secondary_indexes.value.name
        hash_key           = global_secondary_indexes.value.hash_key
        range_key          = global_secondary_indexes.value.range_key
        projection_type    = global_secondary_indexes.value.projection_type
        non_key_attributes = global_secondary_indexes.value.projection_type == "INCLUDE" ? global_secondary_indexes.value.non_key_attributes : null
    }
  }

  tags = {
    Name        = "${var.project}-${var.environment}-${var.table_name}"
    Environment = var.environment
    Project     = var.project
    ManagedBy   = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}