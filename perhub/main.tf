locals {
  public_bucket_name = "perhub-public-bad-example"
  fake_lb_arn        = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:loadbalancer/app/perhub-bad/50dc6c495c0c9188"
  fake_target_arn    = "arn:aws:elasticloadbalancing:ap-southeast-1:123456789012:targetgroup/perhub-bad/6d0ecf831eec9f09"
  fake_backup_vault  = "perhub-backup-vault-bad"

  common_tags = {
    Environment = var.environment
    Owner       = "platform"
    Project     = "perhub"
    ManagedBy   = "terraform"
  }
}

# Good resource dùng để chứng minh tag hợp lệ không bị policy bắt nhầm.
resource "aws_s3_bucket" "private_good" {
  bucket              = "perhub-private-good-example"
  object_lock_enabled = true
  tags                = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "private_good" {
  bucket = aws_s3_bucket.private_good.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "public_bad" {
  bucket = local.public_bucket_name
  acl    = "public-read"
}

resource "aws_s3_bucket_acl" "public_acl_bad" {
  bucket = local.public_bucket_name
  acl    = "public-read-write"
}

resource "aws_s3_bucket_public_access_block" "public_bad" {
  bucket = aws_s3_bucket.public_bad.id

  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_bad" {
  bucket = local.public_bucket_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${local.public_bucket_name}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_versioning" "disabled_bad" {
  bucket = local.public_bucket_name

  versioning_configuration {
    status = "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "no_kms_bad" {
  bucket = local.public_bucket_name

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_object_lock_configuration" "governance_bad" {
  bucket = local.public_bucket_name

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 30
    }
  }
}

resource "aws_cloudtrail" "bad" {
  name                          = "perhub-cloudtrail-bad"
  s3_bucket_name                = local.public_bucket_name
  is_multi_region_trail         = false
  enable_log_file_validation    = false
  include_global_service_events = false
  tags                          = local.common_tags
}

resource "aws_config_configuration_recorder" "bad" {
  name     = "perhub-config-bad"
  role_arn = "arn:aws:iam::123456789012:role/perhub-config-role"

  recording_group {
    all_supported                 = false
    include_global_resource_types = false
    resource_types                = ["AWS::S3::Bucket"]
  }
}

resource "aws_guardduty_detector" "bad" {
  enable = false
}

resource "aws_securityhub_account" "bad" {
  enable_default_standards = false
}

resource "aws_iam_policy" "admin_bad" {
  name = "perhub-admin-bad"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "kms_wildcard_bad" {
  name = "perhub-kms-wildcard-bad"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "passrole_bad" {
  name = "perhub-passrole-bad"
  role = "perhub-example-role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "external_trust_bad" {
  name = "perhub-external-trust-bad"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::999999999999:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "admin_attach_bad" {
  role       = aws_iam_role.external_trust_bad.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_access_key" "user_key_bad" {
  user = "legacy-user"
}

resource "aws_kms_key" "weak_bad" {
  description             = "Intentionally weak KMS key for policy test"
  deletion_window_in_days = 7
  enable_key_rotation     = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_security_group" "public_ssh_bad" {
  name        = "perhub-public-ssh-bad"
  description = "Intentionally bad SG for policy test"
  vpc_id      = "vpc-00000000000000000"

  ingress {
    description = "Public SSH should be denied by policy"
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_vpc" "no_flow_logs_bad" {
  cidr_block = "10.90.0.0/16"
  tags       = local.common_tags
}

resource "aws_vpc_endpoint" "s3_only_bad" {
  vpc_id       = aws_vpc.no_flow_logs_bad.id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  tags         = local.common_tags
}

resource "aws_subnet" "public_auto_ip_bad" {
  vpc_id                  = aws_vpc.no_flow_logs_bad.id
  cidr_block              = "10.90.1.0/24"
  map_public_ip_on_launch = true
  tags                    = local.common_tags
}

resource "aws_instance" "public_ip_bad" {
  ami                         = "ami-1234567890abcdef0"
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  monitoring                  = false
  subnet_id                   = aws_subnet.public_auto_ip_bad.id

  metadata_options {
    http_tokens = "optional"
  }

  root_block_device {
    encrypted = false
  }

  ebs_block_device {
    device_name = "/dev/sdh"
    volume_size = 10
    encrypted   = false
  }

  tags = local.common_tags
}

resource "aws_instance" "oversized_bad" {
  ami           = "ami-1234567890abcdef0"
  instance_type = "m7i.4xlarge"
  monitoring    = true
  subnet_id     = aws_subnet.public_auto_ip_bad.id

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = local.common_tags
}

resource "aws_security_group_rule" "public_rdp_bad" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 3389
  to_port           = 3389
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "sg-00000000000000000"
}

resource "aws_lb" "bad" {
  name                       = "perhub-alb-bad"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = ["subnet-00000000000000000", "subnet-11111111111111111"]
  enable_deletion_protection = false
  tags                       = local.common_tags
}

resource "aws_lb_listener" "http_bad" {
  load_balancer_arn = local.fake_lb_arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "ok"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener" "https_weak_bad" {
  load_balancer_arn = local.fake_lb_arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = "arn:aws:acm:ap-southeast-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    type             = "forward"
    target_group_arn = local.fake_target_arn
  }
}

resource "aws_wafv2_web_acl" "bad" {
  name  = "perhub-waf-bad"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "perhub-waf-bad"
    sampled_requests_enabled   = false
  }

  tags = local.common_tags
}

resource "aws_ebs_volume" "unencrypted_bad" {
  availability_zone = "${var.aws_region}a"
  size              = 10
  encrypted         = false
  tags              = local.common_tags
}

resource "aws_ebs_snapshot_copy" "unencrypted_bad" {
  source_snapshot_id = "snap-00000000000000000"
  source_region      = var.aws_region
  description        = "Intentionally bad unencrypted snapshot copy for policy test"
  encrypted          = false
  tags               = local.common_tags
}

resource "aws_ecr_repository" "bad" {
  name                 = "perhub-ecr-bad"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_lambda_function" "bad" {
  function_name = "perhub-lambda-bad"
  role          = "arn:aws:iam::123456789012:role/perhub-lambda-role"
  handler       = "index.handler"
  runtime       = "python3.8"
  filename      = "lambda.zip"
  tags          = local.common_tags
}

resource "aws_ecs_task_definition" "bad" {
  family                   = "perhub-ecs-bad"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name                   = "app"
      image                  = "nginx:latest"
      essential              = true
      privileged             = true
      readonlyRootFilesystem = false
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "oversized_bad" {
  family                   = "perhub-ecs-oversized-bad"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "4096"
  memory                   = "8192"

  container_definitions = jsonencode([
    {
      name                   = "app"
      image                  = "nginx:latest"
      essential              = true
      privileged             = false
      readonlyRootFilesystem = true
      logConfiguration = {
        logDriver = "awslogs"
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "bad" {
  name            = "perhub-ecs-bad"
  cluster         = "arn:aws:ecs:ap-southeast-1:123456789012:cluster/perhub"
  task_definition = "arn:aws:ecs:ap-southeast-1:123456789012:task-definition/perhub-ecs-bad:1"
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-00000000000000000"]
    security_groups  = ["sg-00000000000000000"]
    assign_public_ip = true
  }

  tags = local.common_tags
}

resource "aws_s3_bucket" "empty_tags_bad" {
  bucket = "perhub-empty-tags-bad-example"

  tags = {
    Environment = "staging"
    Owner       = ""
    Project     = "perhub"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket" "invalid_environment_bad" {
  bucket = "perhub-invalid-env-bad-example"

  tags = {
    Environment = "prod"
    Owner       = "platform"
    Project     = "perhub"
    ManagedBy   = "terraform"
  }
}

resource "aws_db_instance" "unencrypted_bad" {
  identifier          = "perhub-rds-unencrypted-bad"
  allocated_storage   = 20
  engine              = "mysql"
  instance_class      = "db.t3.micro"
  username            = "admin"
  password            = "Password123456!"
  storage_encrypted   = false
  skip_final_snapshot = true
  publicly_accessible = false
  deletion_protection = false
  tags                = local.common_tags
}

resource "aws_rds_cluster" "unencrypted_bad" {
  cluster_identifier  = "perhub-cluster-unencrypted-bad"
  engine              = "aurora-mysql"
  master_username     = "admin"
  master_password     = "Password123456!"
  storage_encrypted   = false
  skip_final_snapshot = true
  tags                = local.common_tags
}

resource "aws_sqs_queue" "unencrypted_bad" {
  name = "perhub-sqs-unencrypted-bad"
  tags = local.common_tags
}

resource "aws_sqs_queue_policy" "public_bad" {
  queue_url = aws_sqs_queue.unencrypted_bad.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "sqs:SendMessage"
        Resource  = "*"
      }
    ]
  })
}

resource "aws_route53_zone" "public_no_logs_bad" {
  name = "bad.example.com"
  tags = local.common_tags
}

resource "aws_route53_record" "wildcard_bad" {
  zone_id = aws_route53_zone.public_no_logs_bad.zone_id
  name    = "*.bad.example.com"
  type    = "A"
  ttl     = 300
  records = ["192.0.2.10"]
}

resource "aws_dynamodb_table" "unencrypted_bad" {
  name         = "perhub-dynamodb-unencrypted-bad"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled = false
  }

  tags = local.common_tags
}

resource "aws_efs_file_system" "unencrypted_bad" {
  encrypted = false
  tags      = local.common_tags
}

resource "aws_efs_mount_target" "no_sg_bad" {
  file_system_id = aws_efs_file_system.unencrypted_bad.id
  subnet_id      = "subnet-00000000000000000"
}

resource "aws_eks_cluster" "bad" {
  name     = "perhub-eks-bad"
  role_arn = "arn:aws:iam::123456789012:role/perhub-eks-cluster-role"

  enabled_cluster_log_types = ["api"]

  vpc_config {
    subnet_ids              = ["subnet-00000000000000000", "subnet-11111111111111111"]
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  tags = local.common_tags
}

resource "aws_eks_node_group" "bad" {
  cluster_name    = "perhub-eks-bad"
  node_group_name = "perhub-nodegroup-bad"
  node_role_arn   = "arn:aws:iam::123456789012:role/perhub-eks-node-role"
  subnet_ids      = ["subnet-00000000000000000"]
  instance_types  = ["m7i.4xlarge"]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  remote_access {
    ec2_ssh_key = "perhub-key"
  }

  tags = local.common_tags
}

resource "aws_elasticache_replication_group" "unencrypted_bad" {
  replication_group_id       = "perhub-redis-unencrypted-bad"
  description                = "Intentionally bad ElastiCache for policy test"
  engine                     = "redis"
  node_type                  = "cache.t3.micro"
  num_cache_clusters         = 1
  port                       = 6379
  at_rest_encryption_enabled = false
  transit_encryption_enabled = false
  tags                       = local.common_tags
}

resource "aws_opensearch_domain" "unencrypted_bad" {
  domain_name    = "perhub-os-unencrypted-bad"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type  = "t3.small.search"
    instance_count = 1
  }

  encrypt_at_rest {
    enabled = false
  }

  tags = local.common_tags
}

resource "aws_redshift_cluster" "unencrypted_bad" {
  cluster_identifier  = "perhub-redshift-unencrypted-bad"
  database_name       = "perhub"
  master_username     = "admin"
  master_password     = "Password123456!"
  node_type           = "dc2.large"
  cluster_type        = "single-node"
  encrypted           = false
  skip_final_snapshot = true
  tags                = local.common_tags
}

resource "aws_kinesis_stream" "unencrypted_bad" {
  name        = "perhub-kinesis-unencrypted-bad"
  shard_count = 1
  tags        = local.common_tags
}

resource "aws_cloudwatch_log_group" "no_kms_bad" {
  name = "/aws/perhub/no-kms-bad"
  tags = local.common_tags
}

resource "aws_secretsmanager_secret" "bad" {
  name                    = "perhub/secret/bad"
  recovery_window_in_days = 7
  tags                    = local.common_tags
}

resource "aws_backup_vault" "bad" {
  name = local.fake_backup_vault
  tags = local.common_tags
}

resource "aws_backup_plan" "bad" {
  name = "perhub-backup-plan-bad"

  rule {
    rule_name         = "short-retention"
    target_vault_name = local.fake_backup_vault

    lifecycle {
      delete_after = 7
    }
  }

  tags = local.common_tags
}
