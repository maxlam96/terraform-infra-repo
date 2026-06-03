# Disaster Recovery Plan

## 1. Recovery Objectives

### RTO & RPO

```
RTO (Recovery Time Objective): 4 hours
RPO (Recovery Point Objective): 15 minutes

Service Level:
├── Critical Systems: RTO 1 hour, RPO 5 minutes
├── Important Systems: RTO 4 hours, RPO 15 minutes
└── Standard Systems: RTO 8 hours, RPO 1 hour
```

---

## 2. Backup Strategy

### Database Backups

```hcl
# ✓ RDS Automated Backups
resource "aws_db_instance" "financial" {
  backup_retention_period     = 35        # 35 days
  backup_window              = "03:00-04:00"
  copy_tags_to_snapshot      = true
  
  # Multi-AZ automatic failover
  multi_az                   = true
}

# ✓ Cross-Region Backup Replication
resource "aws_db_instance_automated_backup_replication" "financial" {
  source_db_instance_arn      = aws_db_instance.financial.arn
  backup_retention_period     = 14
  destination_region          = "us-west-2"
}
```

### EBS Snapshots

```hcl
# ✓ Automated daily snapshots
resource "aws_dlm_lifecycle_policy" "ebs_snapshots" {
  description        = "Daily EBS snapshots with 14-day retention"
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

### S3 Data Protection

```hcl
# ✓ S3 Versioning
resource "aws_s3_bucket_versioning" "financial_data" {
  bucket = aws_s3_bucket.financial_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ✓ Cross-Region Replication
resource "aws_s3_bucket_replication_configuration" "financial_data" {
  bucket = aws_s3_bucket.financial_data.id

  role = aws_iam_role.s3_replication.arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket       = aws_s3_bucket.financial_data_replica.arn
      storage_class = "STANDARD_IA"
    }
  }
}
```

---

## 3. Failure Scenarios

### Scenario 1: Single AZ Failure

**Detection:**
- CloudWatch alarms detect unhealthy instances
- EKS auto-scaling launches replacements
- RDS automatic failover to standby

**Recovery Time:** < 5 minutes

```
AZ-1 (Down)     AZ-2 (Active)    AZ-3 (Active)
  X               ✓               ✓

Action: Auto failover
- EKS: Reschedule pods to AZ-2 and AZ-3
- RDS: Failover to standby in different AZ
- ALB: Remove unhealthy targets

Result: Service continues with reduced capacity
```

### Scenario 2: Region Failure

**Detection:**
- Multiple health checks fail across region
- SNS alert triggers DR team
- Automated failover to secondary region

**Recovery Time:** 30-60 minutes

```
Primary Region (Down)       Secondary Region (Standby)
  X                              ACTIVATE

Manual Steps:
1. Verify backup integrity (10 min)
2. Restore database in secondary region (15 min)
3. Deploy application stack (20 min)
4. Update DNS records (5 min)
5. Smoke tests & validation (10 min)

Total: ~60 minutes
```

### Scenario 3: Database Corruption

**Detection:**
- Scheduled integrity checks fail
- Automated alerts to DBA team

**Recovery Steps:**
1. Identify last-known-good backup (automated check)
2. Restore to point-in-time (within 15 minutes)
3. Validate data integrity
4. Switch applications to restored database
5. Keep corrupted DB for forensics

**Recovery Time:** < 30 minutes

### Scenario 4: Ransomware/Malicious Activity

**Detection:**
- GuardDuty threat detection
- Unusual file encryption patterns
- Unauthorized privilege escalation

**Immediate Response:**
```
1. ISOLATE (< 5 min)
   - Kill affected pods
   - Update security groups (deny all)
   - Preserve logs/evidence

2. INVESTIGATE (1-2 hours)
   - Analyze CloudTrail logs
   - Review VPC Flow Logs
   - Identify attack vector

3. RESTORE (30-60 min)
   - Restore from clean backup
   - Re-deploy with patches
   - Update security policies

4. VALIDATE (30 min)
   - Full smoke tests
   - Security scan
   - Performance validation
```

---

## 4. Recovery Procedures

### Database Recovery

```bash
# Step 1: Identify backup
aws rds describe-db-snapshots \
  --db-instance-identifier payments-prod \
  --query 'DBSnapshots[0]'

# Step 2: Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier payments-prod-restored \
  --db-snapshot-identifier payments-prod-snapshot \
  --db-subnet-group-name financial-db-subnet \
  --vpc-security-group-ids sg-12345678

# Step 3: Verify connectivity
mysql -h <restored-db-endpoint> -u admin -p \
  --execute "SELECT COUNT(*) FROM transactions;"

# Step 4: Update application endpoint
kubectl set env deployment/api-server \
  DATABASE_HOST=<restored-db-endpoint>

# Step 5: Validate data consistency
./scripts/validate-data-integrity.sh
```

### EKS Cluster Recovery

```bash
# Step 1: Verify cluster status
aws eks describe-cluster --name payments-prod

# Step 2: Check node status
kubectl get nodes -o wide

# Step 3: If needed, scale node groups
aws eks update-nodegroup-config \
  --cluster-name payments-prod \
  --nodegroup-name backend-nodes \
  --scaling-config minSize=3,maxSize=15,desiredSize=5

# Step 4: Verify workload status
kubectl get pods -n payments

# Step 5: Run smoke tests
kubectl apply -f tests/smoke-tests.yaml
```

### DNS/Failover

```bash
# Step 1: Update Route 53
aws route53 change-resource-record-sets \
  --hosted-zone-id Z12345 \
  --change-batch file:///tmp/failover.json

# failover.json:
# {
#   "Changes": [
#     {
#       "Action": "UPSERT",
#       "ResourceRecordSet": {
#         "Name": "api.payments.com",
#         "Type": "A",
#         "TTL": 60,
#         "ResourceRecords": [
#           { "Value": "<secondary-region-ALB-IP>" }
#         ]
#       }
#     }
#   ]
# }

# Step 2: Verify DNS propagation
nslookup api.payments.com

# Step 3: Monitor traffic
watch 'kubectl logs -f deployment/api-server'
```

---

## 5. Testing & Validation

### Quarterly DR Drill

```yaml
DR Drill Checklist:
  Week 1: Plan & Prepare
    - [ ] Select failure scenario
    - [ ] Define success criteria
    - [ ] Brief team
    - [ ] Allocate resources

  Week 2: Execute
    - [ ] Initiate failover
    - [ ] Monitor metrics
    - [ ] Track recovery time
    - [ ] Document issues

  Week 3: Validate
    - [ ] Verify data integrity
    - [ ] Confirm service levels
    - [ ] Run full test suite
    - [ ] Performance validation

  Week 4: Review
    - [ ] After-action report
    - [ ] Update procedures
    - [ ] Fix identified issues
    - [ ] Team training
```

### Backup Validation

```bash
#!/bin/bash
# Weekly backup validation script

echo "=== Weekly Backup Validation ==="

# Check RDS backup age
BACKUP_AGE=$(aws rds describe-db-snapshots \
  --db-instance-identifier payments-prod \
  --query 'DBSnapshots[0].SnapshotCreateTime' \
  --output text)

echo "Latest RDS Backup: $BACKUP_AGE"

# Check EBS snapshot count
SNAPSHOT_COUNT=$(aws ec2 describe-snapshots \
  --owner-ids self \
  --query "Snapshots[?Tags[?Key=='Name' && Value=='payments-snapshot']].SnapshotId" \
  --output json | jq 'length')

echo "EBS Snapshots: $SNAPSHOT_COUNT"

# Check S3 replication status
REPL_STATUS=$(aws s3api get-bucket-replication \
  --bucket financial-data \
  --query 'ReplicationConfiguration.Role')

echo "S3 Replication Status: $REPL_STATUS"

# Alert if any check fails
if [ "$SNAPSHOT_COUNT" -lt 7 ]; then
  echo "ERROR: Insufficient snapshots"
  exit 1
fi

echo "=== Backup Validation PASSED ==="
```

---

## 6. Runbook Quick Reference

### 1-Hour Critical Failure

```
T+0: Alert received
├─ T+2: Incident commander activated
├─ T+5: Initial assessment complete
├─ T+10: Decision to failover (if needed)
├─ T+30: Recovery in progress
└─ T+60: Service restored, monitoring enabled
```

### Contact Information

```
Incident Commander: [FILL IN]
Database Admin: [FILL IN]
Network Team: [FILL IN]
Security Team: [FILL IN]
Management: [FILL IN]

Escalation Line: [PHONE NUMBER]
War Room: [VIDEO CONFERENCE LINK]
Status Page: [URL]
```

---

## 7. Regular Maintenance

### Monthly
- [ ] Review backup logs
- [ ] Verify all snapshots exist
- [ ] Test restore procedure (non-prod)
- [ ] Update runbooks if needed

### Quarterly
- [ ] Full DR drill
- [ ] Failover testing
- [ ] Team training
- [ ] Update contact list

### Annually
- [ ] Review RTO/RPO targets
- [ ] Update architecture
- [ ] Re-baseline recovery times
- [ ] Executive review
