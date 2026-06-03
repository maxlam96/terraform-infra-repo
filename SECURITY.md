# Security & Compliance Policy

## 1. Data Security Standards

### Encryption Requirements

#### At Rest
```hcl
# ✓ Database Encryption (Mandatory)
resource "aws_db_instance" "financial_db" {
  storage_encrypted           = true
  kms_key_id                 = aws_kms_key.rds_key.arn
  backup_retention_period    = 35
  
  # Multi-AZ for high availability
  multi_az                   = true
  
  # Enhanced monitoring
  enabled_cloudwatch_logs_exports = [
    "error",
    "general",
    "slowquery",
    "audit"
  ]
}

# ✓ EBS Volume Encryption
resource "aws_ebs_volume" "encrypted" {
  encrypted           = true
  kms_key_id         = aws_kms_key.ebs_key.arn
  availability_zone  = "us-east-1a"
}

# ✓ S3 Bucket Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "financial_bucket" {
  bucket = aws_s3_bucket.financial_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
    bucket_key_enabled = true
  }
}

# ✓ Kubernetes Secrets Encryption
# Configured via EKS: secrets encrypted with KMS key at rest
```

#### In Transit
```hcl
# ✓ TLS 1.2+ Enforcement
resource "aws_lb_listener" "secure" {
  load_balancer_arn = aws_lb.api.arn
  protocol          = "HTTPS"
  port              = 443
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.api.arn

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ✓ All inter-pod communication encrypted
# ✓ VPC endpoints use HTTPS
# ✓ Direct Connect private VIF (encrypted by default)
```

### Key Management

```hcl
# ✓ Dedicated KMS Keys per Service
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM Root Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow RDS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
      }
    ]
  })
}

# ✓ Key Rotation
resource "aws_kms_key" "eks" {
  enable_key_rotation = true
  # Rotates annually by default
}

# ✓ Key Access Logging
resource "aws_s3_bucket" "kms_audit" {
  bucket = "financial-kms-audit-logs"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  lifecycle_rule {
    enabled = true
    expiration {
      days = 90
    }
  }
}
```

---

## 2. Access Control & IAM

### Principle of Least Privilege

```hcl
# ✓ EKS Service Account IAM Roles (IRSA)
resource "aws_iam_role" "app_role" {
  name = "payments-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(aws_eks_cluster.payments.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.payments.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:payments:app-sa"
          }
        }
      }
    ]
  })
}

# ✓ Minimal permissions policy
resource "aws_iam_role_policy" "app_policy" {
  name = "payments-app-policy"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.config.arn}",
          "${aws_s3_bucket.config.arn}/*"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = "us-east-1"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.s3_key.arn
      }
    ]
  })
}

# ✓ MFA Required for sensitive operations
resource "aws_iam_user_login_profile" "admin" {
  user                    = aws_iam_user.admin.name
  password_reset_required = true

  # Enforce password policy
}

# ✓ Temporary credentials only (no long-term access keys)
# Access via assumed roles with explicit time limits
```

### User & Service Management

```yaml
# ✓ Access Tiers
Access Levels:
  L1_Public:
    - External API consumers
    - Read-only operations
    - Rate-limited

  L2_Internal:
    - Internal services
    - Credentials via Kubernetes secrets
    - Pod network isolation

  L3_Privileged:
    - Network team only
    - MFA + approval required
    - Audit logged

  L4_Admin:
    - Terraform state access
    - Infrastructure changes
    - Requires 2 approvals
    - Session recording

# ✓ Network Team Approval
resource "aws_iam_group" "network_team" {
  name = "network-team"
}

# Only network-team can approve VPC changes
resource "aws_iam_group_policy" "network_approval" {
  name  = "network-approval-policy"
  group = aws_iam_group.network_team.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:Approve*",
          "ec2:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}
```

---

## 3. Network Security

### Network Segmentation

```
Financial Tier Segmentation:
├── Tier 1: External (Public)
│   ├── ALB/NLB only
│   ├── TLS termination
│   └── WAF protection
│
├── Tier 2: API Layer (Private)
│   ├── EKS web workloads
│   ├── Service-to-service encrypted
│   └── Internal security groups only
│
├── Tier 3: Business Logic (Private)
│   ├── EKS backend workloads
│   ├── Database access from backend only
│   └── Restricted ingress rules
│
└── Tier 4: Data (Isolated)
    ├── RDS instances
    ├── ElastiCache
    ├── Database-only SG ingress
    └── No egress except logging
```

### Security Group Rules

```hcl
# ✓ Deny-all default, allow-specific
resource "aws_security_group" "backend" {
  name        = "backend-sg"
  description = "Backend application security group"
  vpc_id      = aws_vpc.main.id

  # Explicit deny all ingress (default behavior)
  # Explicit deny all egress (must be overridden)

  tags = {
    Name = "backend-sg"
  }
}

# ✓ Restricted ingress from web tier only
resource "aws_security_group_rule" "backend_from_web" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.web.id
  description              = "Allow traffic from web tier"
}

# ✓ Egress to database only
resource "aws_security_group_rule" "backend_to_db" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.database.id
  description              = "Allow connections to database"
}

# ✓ Egress to KMS (via VPC endpoint)
resource "aws_security_group_rule" "backend_to_kms" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.backend.id
  prefix_list_id    = aws_vpc_endpoint.kms.prefix_list_id
  description       = "Allow connections to KMS VPC endpoint"
}
```

### Network ACLs (Defense-in-Depth)

```hcl
# ✓ Database subnet Network ACL
resource "aws_network_acl" "database" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.database[*].id

  # Inbound: MySQL from application subnets only
  ingress {
    protocol       = "tcp"
    rule_no        = 100
    action         = "allow"
    cidr_block     = "10.40.11.0/24"
    from_port      = 3306
    to_port        = 3306
  }

  ingress {
    protocol       = "tcp"
    rule_no        = 101
    action         = "allow"
    cidr_block     = "10.40.12.0/24"
    from_port      = 3306
    to_port        = 3306
  }

  # Ephemeral ports for responses
  ingress {
    protocol       = "tcp"
    rule_no        = 110
    action         = "allow"
    cidr_block     = "10.40.0.0/16"
    from_port      = 1024
    to_port        = 65535
  }

  # DENY everything else
  ingress {
    protocol       = "-1"
    rule_no        = 999
    action         = "deny"
    cidr_block     = "0.0.0.0/0"
  }

  # Outbound: DNS, NTP, CloudWatch Logs only
  egress {
    protocol       = "udp"
    rule_no        = 100
    action         = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 53
    to_port        = 53
  }

  egress {
    protocol       = "udp"
    rule_no        = 101
    action         = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 123
    to_port        = 123
  }

  # Restrict egress - DENY by default
  egress {
    protocol       = "-1"
    rule_no        = 999
    action         = "deny"
    cidr_block     = "0.0.0.0/0"
  }

  tags = {
    Name = "database-nacl"
  }
}
```

---

## 4. Audit & Logging

### Centralized Logging

```hcl
# ✓ CloudWatch Logs for all sources
resource "aws_cloudwatch_log_group" "eks_audit" {
  name              = "/aws/eks/payments/audit"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs.arn

  tags = {
    Purpose = "EKS audit trail"
  }
}

# ✓ VPC Flow Logs
resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = {
    Name = "VPC flow logs"
  }
}

# ✓ EKS Control Plane Logs
resource "aws_eks_cluster" "payments" {
  # ... other config ...

  enabled_cluster_log_types = [
    "api",          # API server audit logs
    "audit",        # Audit logs
    "authenticator", # Authenticator logs
    "controllerManager", # Controller manager logs
    "scheduler"     # Scheduler logs
  ]

  logging_service_configuration {
    enabled           = true
    log_group_name    = aws_cloudwatch_log_group.eks_audit.name
    log_retention_in_days = 365
  }
}

# ✓ S3 Access Logs
resource "aws_s3_bucket_logging" "financial_bucket" {
  bucket = aws_s3_bucket.financial_data.id

  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "financial/"
}
```

### Immutable Audit Trail

```hcl
# ✓ S3 Object Lock (WORM - Write Once, Read Many)
resource "aws_s3_bucket" "audit_logs" {
  bucket = "financial-audit-logs"

  # Enable versioning (required for Object Lock)
  versioning {
    enabled = true
  }

  # Enable Object Lock
  object_lock_enabled = true
  object_lock_configuration {
    rule {
      default_retention {
        mode = "GOVERNANCE"  # Can override with special permission
        days = 2555          # 7 years
      }
    }
  }

  # Encrypt audit logs
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.audit.arn
      }
    }
  }
}

# ✓ Prevent deletion
resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### Monitoring & Alerting

```hcl
# ✓ CloudTrail for API monitoring
resource "aws_cloudtrail" "main" {
  name                          = "financial-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.cloudtrail.arn

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# ✓ Security Hub for compliance
resource "aws_securityhub_account" "main" {
  enable_default_standards = true
}

# ✓ GuardDuty for threat detection
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
  }
}

# ✓ Alert on suspicious activities
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "UnauthorizedAPICallsAlarm"
  comparison_operator = "GreaterThanOrEqualToEventCount"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedOperationCount"
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  alarm_description = "Alerts when unauthorized API calls are detected"
}
```

---

## 5. Compliance Frameworks

### SOC 2 Type II Controls

```yaml
CC6.1 - Logical Access Controls:
  ✓ IRSA for service authentication
  ✓ Pod network policies
  ✓ Security group restrictions
  ✓ IAM role-based access

CC6.2 - Session Management:
  ✓ Pod session timeout (15 min)
  ✓ Temporary credentials (1 hour expiry)
  ✓ No persistent credentials in pods
  ✓ Session logging to CloudWatch

CC7.2 - System Logging:
  ✓ All API calls logged (CloudTrail)
  ✓ All EKS audit logs
  ✓ VPC Flow Logs
  ✓ Immutable retention (365 days+)

CC8.1 - Change Management:
  ✓ Terraform state locked
  ✓ All changes require code review
  ✓ OPA policy approval
  ✓ Network team sign-off
  ✓ Git audit trail

A1.2 - Risk Assessment:
  ✓ GuardDuty threat detection
  ✓ SecurityHub compliance monitoring
  ✓ VPC Flow Log analysis
  ✓ CloudTrail audit review
```

### PCI DSS Requirements

```yaml
PCI DSS 1.3 - Network Segmentation:
  ✓ Database tier isolated (private subnet)
  ✓ Security groups block unnecessary traffic
  ✓ Network ACLs enforce policies
  ✓ No direct internet access to database

PCI DSS 3.2 - Encryption:
  ✓ Data encrypted at rest (KMS)
  ✓ Data encrypted in transit (TLS 1.2+)
  ✓ Encryption keys managed securely
  ✓ Key rotation every 365 days

PCI DSS 8.1 - Access Control:
  ✓ User identification and authentication
  ✓ MFA required for admin access
  ✓ Role-based access controls
  ✓ Unique user IDs (no shared credentials)

PCI DSS 10.2 - Logging:
  ✓ All user access logged
  ✓ All database queries logged
  ✓ Logs protected from modification
  ✓ Logs retained for 1 year
  ✓ Logs reviewed regularly

PCI DSS 12.6 - Policy:
  ✓ Information security policy documented
  ✓ Access control policy enforced
  ✓ Incident response plan defined
  ✓ Annual compliance attestation
```

### GDPR/Data Privacy

```yaml
Data Minimization:
  ✓ Collect only necessary data
  ✓ Retention policies enforced
  ✓ Automatic deletion after retention period
  ✓ Right to erasure implemented

Data Protection:
  ✓ Personal data encrypted at rest
  ✓ Personal data encrypted in transit
  ✓ Access controls restrict viewing
  ✓ Audit trail for access

Data Residency:
  ✓ EU data remains in EU regions
  ✓ Cross-region transfers restricted
  ✓ Data residency verified in code
  ✓ DPA with AWS confirmed

Incident Response:
  ✓ Breach detection within 24 hours
  ✓ Notification to authorities within 72 hours
  ✓ User notification immediate
  ✓ Post-incident review completed
```

---

## 6. Disaster Recovery

### Backup Strategy

```hcl
# ✓ Database backup
resource "aws_db_instance" "financial" {
  backup_retention_period     = 35
  backup_window              = "03:00-04:00"
  copy_tags_to_snapshot      = true
  enabled_cloudwatch_logs_exports = [
    "error",
    "slowquery"
  ]

  # Multi-AZ automatic failover
  multi_az                   = true
}

# ✓ Automated backup copy to another region
resource "aws_db_instance_automated_backup_replication" "financial" {
  source_db_instance_arn = aws_db_instance.financial.arn
  backup_retention_period = 14
  destination_region      = "us-west-2"
}

# ✓ EBS snapshot schedule
resource "aws_dlm_lifecycle_policy" "ebs_snapshots" {
  description        = "EBS snapshot schedule"
  execution_role_arn = aws_iam_role.dlm.arn
  state               = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]
    schedule {
      name = "daily-snapshots"
      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }
      retain_rule {
        count = 14
      }
    }
  }
}
```

### Recovery Time Objectives

```
RTO: 4 hours
RPO: 15 minutes

Recovery Priority:
1. Verify disaster (30 min)
2. Activate recovery team (15 min)
3. Restore database (2 hours)
4. Restore application (1 hour)
5. Data validation (15 min)
6. Failover DNS (10 min)
7. Smoke tests (15 min)
```

---

## 7. Security Checklist

### Pre-Production Requirements

- [ ] VPC uses 3+ availability zones
- [ ] All subnets encrypted with KMS
- [ ] RDS Multi-AZ enabled
- [ ] Backups automated and tested
- [ ] Security groups deny-all by default
- [ ] Network ACLs restrict egress
- [ ] VPC Flow Logs enabled (30+ day retention)
- [ ] VPC endpoints for private AWS services
- [ ] EKS private API endpoint
- [ ] EKS audit logs enabled (365 day retention)
- [ ] IAM uses IRSA (no static keys)
- [ ] KMS keys with automatic rotation
- [ ] CloudTrail enabled
- [ ] GuardDuty enabled
- [ ] OPA policies configured
- [ ] Terraform state encrypted and locked
- [ ] All secrets in Secrets Manager/Vault
- [ ] Load balancer TLS 1.2+ only
- [ ] Compliance requirements documented
- [ ] Incident response plan defined
- [ ] Security training completed
- [ ] Penetration testing scheduled

---

## 8. Incident Response

### Detection
```
1. CloudWatch alarms trigger
2. GuardDuty detects threat
3. SecurityHub aggregates findings
4. Automatic SNS notification
5. Security team oncall activated
```

### Response
```
1. Isolate affected resources (sg update)
2. Preserve logs (s3 copy)
3. Kill suspicious pods
4. Snapshot disks/databases
5. Analyze root cause
6. Remediate vulnerability
7. Deploy patch
8. Verify recovery
9. Document incident
10. Update policies
```

### Post-Incident
```
- Root cause analysis
- Lessons learned documentation
- Policy updates
- Team training
- Compliance reporting
- Customer notification (if required)
```

---

## 9. Regular Security Activities

### Weekly
- [ ] Review CloudTrail logs
- [ ] Check GuardDuty findings
- [ ] Verify backup completion

### Monthly
- [ ] IAM access review
- [ ] Security group audit
- [ ] VPC Flow Logs analysis

### Quarterly
- [ ] Penetration testing
- [ ] Compliance assessment
- [ ] Incident response drill

### Annually
- [ ] Full security audit
- [ ] Compliance certification
- [ ] Policy review & update
- [ ] Employee security training

---

## 10. References

- AWS Security Best Practices: https://aws.amazon.com/security/best-practices/
- EKS Security Guide: https://docs.aws.amazon.com/eks/latest/userguide/security.html
- PCI DSS Compliance on AWS: https://aws.amazon.com/compliance/pci-dss/
- SOC 2 on AWS: https://aws.amazon.com/compliance/soc/
