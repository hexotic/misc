# Locking with dynamo-db


Code for dynamod-db table:
```terraform
resource "aws_dynamodb_table" "lock-table" {
  name           = "datanode-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  stream_enabled = false

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }
}
```
