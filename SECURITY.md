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
}
```

### Key Management

```hcl
# ✓ Dedicated KMS Keys per Service
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

# ✓ Key Rotation
resource "aws_kms_key" "eks" {
  enable_key_rotation = true
  # Rotates annually by default
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
          aws_s3_bucket.config.arn,
          "${aws_s3_bucket.config.arn}/*"
        ]
      }
    ]
  })
}
```

---

## 3. Network Security

### Security Group Strategy

```hcl
# ✓ Deny-all default, allow-specific
resource "aws_security_group" "backend" {
  name        = "backend-sg"
  description = "Backend application security group"
  vpc_id      = aws_vpc.main.id
}

# ✓ Restricted ingress from web tier only
resource "aws_security_group_rule" "backend_from_web" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.backend.id
  source_security_group_id = aws_security_group.web.id
  description              = "Allow traffic from web tier only"
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
}

# ✓ VPC Flow Logs
resource "aws_flow_log" "vpc" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}

# ✓ Immutable audit trail with S3 Object Lock
resource "aws_s3_bucket" "audit_logs" {
  bucket = "financial-audit-logs"
  object_lock_enabled = true
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

CC7.2 - System Logging:
  ✓ All API calls logged (CloudTrail)
  ✓ All EKS audit logs
  ✓ VPC Flow Logs
  ✓ Immutable retention (365+ days)

CC8.1 - Change Management:
  ✓ Terraform state locked
  ✓ All changes require code review
  ✓ OPA policy approval
```

### PCI DSS Requirements

```yaml
PCI DSS 1.3 - Network Segmentation:
  ✓ Database tier isolated (private subnet)
  ✓ Security groups block unnecessary traffic
  ✓ Network ACLs enforce policies

PCI DSS 3.2 - Encryption:
  ✓ Data encrypted at rest (KMS)
  ✓ Data encrypted in transit (TLS 1.2+)
  ✓ Key rotation every 365 days

PCI DSS 8.1 - Access Control:
  ✓ User identification and authentication
  ✓ Role-based access controls

PCI DSS 10.2 - Logging:
  ✓ All user access logged
  ✓ Logs protected from modification
  ✓ Logs retained for 1 year
```

---

## 6. Pre-Production Security Checklist

- [ ] VPC uses 3+ availability zones
- [ ] All subnets encrypted with KMS
- [ ] RDS Multi-AZ enabled
- [ ] Backups automated and tested
- [ ] Security groups deny-all by default
- [ ] VPC Flow Logs enabled (30+ day retention)
- [ ] EKS private API endpoint
- [ ] EKS audit logs enabled (365 day retention)
- [ ] IAM uses IRSA (no static keys)
- [ ] KMS keys with automatic rotation
- [ ] CloudTrail enabled
- [ ] GuardDuty enabled
- [ ] OPA policies configured
- [ ] Terraform state encrypted and locked
- [ ] All secrets in AWS Secrets Manager
- [ ] Load balancer TLS 1.2+ only
- [ ] Compliance requirements documented
- [ ] Incident response plan defined

---

## 7. Regular Security Activities

### Weekly
- [ ] Review CloudTrail logs
- [ ] Check GuardDuty findings
- [ ] Verify backup completion

### Monthly
- [ ] IAM access review
- [ ] Security group audit

### Quarterly
- [ ] Penetration testing
- [ ] Compliance assessment

### Annually
- [ ] Full security audit
- [ ] Compliance certification
- [ ] Policy review & update
