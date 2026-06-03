# Architecture Overview

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Financial Organization                        │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │                         │
            ┌───────▼──────────┐    ┌────────▼─────────┐
            │  Jenkins CI/CD   │    │  OPA Policy      │
            │  Pipeline        │    │  Validator       │
            └────────┬─────────┘    └────────┬─────────┘
                     │                       │
                     └───────────┬───────────┘
                                 │
            ┌────────────────────▼────────────────────┐
            │    Terraform Infrastructure Code        │
            │  (floci-vpc + floci-eks)               │
            └────────────────────┬────────────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
   ┌────▼────────────┐  ┌────────▼─────────┐  ┌──────────▼──────────┐
   │  AWS VPC Layer  │  │  EKS Cluster    │  │  Security & Auth    │
   │  (Networking)   │  │  (Orchestration)│  │  (IAM, KMS, Logs)   │
   └────┬────────────┘  └────────┬────────┘  └──────────┬──────────┘
        │                        │                      │
        │ Multi-AZ             │ Multi-Tier          │ Encrypted
        │ NAT Gateway          │ Node Groups         │ Audit Logs
        │ VPC Endpoints        │ (web/backend/       │
        │ Flow Logs            │  worker)            │
        │                      │ Karpenter           │
        └────────────┬─────────┴────────────────────┬───┘
                     │                             │
         ┌───────────▼───────────────────────────▼──────────┐
         │  Production Workloads                            │
         │  ├── Payment Processing                          │
         │  ├── API Services                                │
         │  ├── Data Processing                             │
         │  └── Compliance Monitoring                       │
         └───────────────────────────────────────────────────┘
```

---

## Layer 1: VPC (Networking & Infrastructure)

### Components:
```
VPC: 10.40.0.0/16 (Production) / 10.50.0.0/16 (Example)
├── Public Subnets (1 per AZ)
│   ├── Internet Gateway
│   └── NAT Gateways (1 per AZ in production)
│
├── Private Subnets (1 per AZ)
│   ├── Application Layer
│   ├── EKS Node Groups
│   └── NAT Gateway Routes
│
└── Database Subnets (1 per AZ)
    ├── RDS Instances
    ├── Database Security Group
    └── RDS Enhanced Monitoring
```

### Multi-AZ Strategy:
```
Availability Zone A         Availability Zone B         Availability Zone C
┌──────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ Public: 10.40.1.0/24 │   │ Public: 10.40.2.0/24 │   │ Public: 10.40.3.0/24 │
│ NAT GW 1             │   │ NAT GW 2             │   │ NAT GW 3             │
├──────────────────────┤   ├──────────────────────┤   ├──────────────────────┤
│ Private: 10.40.11/24 │   │ Private: 10.40.12/24 │   │ Private: 10.40.13/24 │
│ EKS Nodes            │   │ EKS Nodes            │   │ EKS Nodes            │
├──────────────────────┤   ├──────────────────────┤   ├──────────────────────┤
│ DB: 10.40.21.0/24    │   │ DB: 10.40.22.0/24    │   │ DB: 10.40.23.0/24    │
│ RDS / ElastiCache    │   │ RDS / ElastiCache    │   │ RDS / ElastiCache    │
└──────────────────────┘   └──────────────────────┘   └──────────────────────┘
```

### VPC Endpoints (Secure Connectivity):
```
Interface Endpoints:
├── EC2              (for instance management)
├── ECR API          (for container image pull)
├── ECR DKR          (for docker push/pull)
├── S3               (for configuration & backups)
├── Secrets Manager  (for credential management)
├── CloudWatch Logs  (for centralized logging)
├── KMS              (for key management)
└── STS              (for temporary credentials)

Benefits:
✓ No internet gateway required
✓ PrivateLink-based connections
✓ No data egress costs
✓ Network policy enforcement
✓ Full audit logging
```

### Network Security:
```
Security Groups:
├── VPC Default SG
│   └── Restricted (managed)
├── EKS Control Plane SG
│   ├── Ingress: 443 from worker nodes
│   └── Egress: All allowed
├── EKS Worker Nodes SG
│   ├── Ingress: 443,10250 from control plane
│   ├── Ingress: Kubelet metrics from monitoring
│   └── Egress: All allowed to VPC endpoints
└── Database SG
    ├── Ingress: 3306 (MySQL) from app layer
    ├── Ingress: 6379 (Redis) from app layer
    └── Egress: None

Network ACLs:
├── Stateless rules for defense-in-depth
├── Deny rule at end (explicit deny)
└── Monitored by VPC Flow Logs
```

---

## Layer 2: EKS Cluster (Container Orchestration)

### Cluster Architecture:
```
EKS Cluster: payments-production
├── Control Plane (AWS-managed)
│   ├── High Availability across 3 AZs
│   ├── Auto-scaling (handled by AWS)
│   ├── Fully audited
│   └── Encrypted etcd
│
├── Data Plane (Managed Node Groups)
│   ├── Web Tier Nodes
│   │   ├── Instance Type: m6i.large (2 vCPU, 8GB RAM)
│   │   ├── Min: 3, Max: 9, Desired: 3
│   │   ├── Workload: Public-facing APIs
│   │   └── Taints: workload=web:NoSchedule
│   │
│   ├── Backend Tier Nodes
│   │   ├── Instance Type: m6i.large
│   │   ├── Min: 3, Max: 12, Desired: 3
│   │   ├── Workload: Business logic services
│   │   └── Taints: workload=backend:NoSchedule
│   │
│   └── Worker Tier Nodes
│       ├── Instance Type: m6i.large
│       ├── Min: 3, Max: 15, Desired: 3
│       ├── Workload: Batch jobs, background tasks
│       └── Taints: workload=worker:NoSchedule
│
└── Add-ons
    ├── VPC CNI (networking)
    ├── CoreDNS (service discovery)
    ├── kube-proxy (load balancing)
    ├── AWS CloudWatch Observability
    ├── AWS Load Balancer Controller
    └── Karpenter (advanced autoscaling)
```

### Security Hardening:
```
Control Plane Security:
✓ Private API endpoint (no public access)
✓ Security groups restrict access
✓ VPC endpoint access only
✓ Full audit logging enabled:
  ├── API Server audit logs
  ├── Authenticator logs
  ├── Control Manager logs
  └── Scheduler logs
✓ CloudWatch log retention: 365 days

Data Plane Security:
✓ No SSH remote access on worker nodes
✓ Private subnets only
✓ Nodes use IMDSv2 (session tokens)
✓ Instance Metadata Service v2 enforced
✓ VPC Flow Logs capture all traffic
✓ Security groups limit egress

Encryption:
✓ Kubernetes secrets encrypted with dedicated KMS key
✓ EBS volumes encrypted at rest
✓ All inter-node communication encrypted
✓ TLS for all API communication
```

### Auto-Scaling Modes:
```
1. Cluster Autoscaler Mode:
   ├── Monitors pending pods
   ├── Scales up when needed
   ├── Scales down after 10 minutes idle
   └── Conservative scaling policy

2. Karpenter Mode (Advanced):
   ├── Sub-second pod launch times
   ├── Real-time consolidation
   ├── Bin-packing optimization
   ├── Interruption handling
   └── Cost-optimized instance selection

3. Both Mode (Recommended for Production):
   ├── Karpenter as primary scaler
   ├── Cluster Autoscaler as fallback
   └── Provides high availability & cost optimization
```

---

## Layer 3: Connectivity & Hybrid

### Site-to-Site VPN (Backup):
```
On-Premises Network          AWS VPC
    │                            │
    └── Customer Gateway    ┌────┴────┐
        (BGP Enabled)       │ VPN GW  │
                            └────┬────┘
                                 │
                         IPSec Tunnel 1
                         IPSec Tunnel 2
                         (Active-Backup)

Configuration:
├── BGP ASN: 65010 (On-Prem)
├── BGP ASN: 64512 (AWS)
├── Static routes disabled (dynamic BGP)
├── Two tunnels for redundancy
└── Automatic failover on tunnel down
```

### Direct Connect (Primary):
```
On-Premises             AWS Direct Connect
    │                        │
    └─ Dedicated        ┌─────┴─────┐
       Network Link     │ DCX GW    │
       (1Gbps+)         └─────┬─────┘
                              │
                         Direct Access
                         (Private VIF)

Benefits:
✓ Dedicated network link
✓ Consistent network performance
✓ Lower latency (<100ms)
✓ No internet bandwidth charges
✓ Enhanced security
```

### Transit Gateway:
```
Multiple VPCs / On-Premises Networks
        │
    ┌───▼────────────────┐
    │  Transit Gateway   │
    │  (Central Hub)     │
    └───┬────────────────┘
        │
    ┌───┴──────┬──────────┬──────────┐
    │          │          │          │
┌───▼──┐  ┌───▼──┐  ┌───▼──┐  ┌───▼──┐
│ VPC1 │  │ VPC2 │  │ VPC3 │  │On-Prem
└──────┘  └──────┘  └──────┘  └──────┘

Use Cases:
├── Multi-VPC deployments
├── Shared services access
├── On-premises connectivity
└── Centralized network management
```

---

## Layer 4: Compliance & Governance

### Policy Validation (OPA):
```
Terraform Plan
       │
       ▼
Terraform JSON Plan
       │
       ▼
┌──────────────────┐
│ OPA Policy Check │
└────────┬─────────┘
         │
    ┌────┴────┐
    │          │
   Pass      Fail
    │          │
    ▼          ▼
 Approve    Reject
 Changes    Changes

Policies:
├── VPC Policies
│   ├── Multi-AZ enforcement
│   ├── NAT gateway configuration
│   ├── VPC endpoint requirements
│   └── Flow logs requirement
├── EKS Policies
│   ├── Private API endpoint
│   ├── Encryption requirement
│   ├── Logging requirement
│   └── Node group sizing
├── Security Policies
│   ├── KMS key enforcement
│   ├── Network ACL rules
│   └── Security group restrictions
└── Compliance Policies
    ├── Financial data handling
    ├── Audit trail requirements
    └── Data residency
```

### Approval Workflow:
```
Developer           Network Team         Finance Compliance
    │                    │                      │
    ▼                    ▼                      ▼
Push Code → Terraform Plan → Network Review → Compliance Check
                             (Manual)          (Automated)
                              │                 │
                              └────────┬────────┘
                                       │
                                   Approved?
                                    /    \
                                Yes      No
                                 │        │
                                 ▼        ▼
                            Apply    Reject
                            to Prod  Changes
```

---

## Data Flow Example: Payment Transaction

```
1. Client Request
   ┌──────────────────┐
   │ External Request │ (HTTPS only)
   └────────┬─────────┘
            │ (via ALB in public subnet)
            ▼
2. ALB/NLB Layer
   ┌────────────────────────────────┐
   │ Application Load Balancer      │
   │ (in public subnets)            │
   │ ├── TLS Termination            │
   │ ├── Rate Limiting              │
   │ └── WAF (optional)             │
   └────────────┬────────────────────┘
                │ (via internal security group)
                ▼
3. Web Tier (EKS)
   ┌────────────────────────────────┐
   │ Web Tier Pods (3 replicas)     │
   │ ├── API Gateway                │
   │ ├── Request Validation         │
   │ └── Auth Verification          │
   └────────────┬────────────────────┘
                │ (via service mesh / inter-pod comms)
                ▼
4. Backend Tier (EKS)
   ┌────────────────────────────────┐
   │ Backend Tier Pods (3 replicas) │
   │ ├── Payment Processing         │
   │ ├── Business Logic             │
   │ └── Transaction Coordination   │
   └────────────┬────────────────────┘
                │ (via VPC endpoints)
                ▼
5. Data Layer
   ┌────────────────────────────────┐
   │ Database Tier (Private)        │
   │ ├── Primary RDS (ap-southeast-1a)
   │ ├── Replica 1 (ap-southeast-1b)
   │ └── Replica 2 (ap-southeast-1c)
   │ (All encrypted with AWS KMS)   │
   └────────────┬────────────────────┘
                │
                ▼
6. Logging & Audit
   ┌────────────────────────────────┐
   │ CloudWatch Logs                │
   │ VPC Flow Logs                  │
   │ EKS Audit Logs                 │
   │ Application Logs               │
   │ (All encrypted & immutable)    │
   └────────────────────────────────┘
```

---

## Disaster Recovery & Business Continuity

### RTO/RPO Targets:
```
RTO (Recovery Time Objective): 4 hours
RPO (Recovery Point Objective): 15 minutes

Backup Strategy:
├── Database
│   ├── Automated daily snapshots
│   ├── Transaction log backups (15min)
│   ├── Cross-region replication
│   └── 30-day retention
├── Configuration
│   ├── Infrastructure as Code (Git)
│   ├── State files (encrypted S3)
│   ├── 90-day versioning
│   └── Cross-region backup
└── Application Data
    ├── EBS snapshots (daily)
    ├── S3 versioning enabled
    ├── Cross-region replication
    └── 60-day retention

Recovery Procedure:
1. Detect failure (monitoring)
2. Notify operations team (SNS)
3. Initiate recovery scripts
4. Verify data integrity
5. Restore to alternative AZ/region
6. Run smoke tests
7. Switch DNS records
8. Notify stakeholders
```

---

## Monitoring & Observability

### Three Pillars:

#### 1. Metrics
```
Collected from:
├── EKS Control Plane Metrics
├── Node Metrics (CPU, Memory, Disk)
├── Pod Metrics (via Metrics Server)
├── Application Metrics (Prometheus)
├── AWS CloudWatch Metrics
└── Custom Financial Metrics

Retention: 13 months (CloudWatch)
```

#### 2. Logs
```
Sources:
├── EKS Audit Logs (365 days)
├── Application Logs
├── VPC Flow Logs (30 days)
├── Container Logs (7 days)
└── API Gateway Logs (90 days)

Destination: CloudWatch Logs
Encryption: AES-256
```

#### 3. Traces
```
Implementation:
├── X-Ray integration
├── Distributed tracing
├── Service map visualization
├── Latency tracking
└── Error tracking
```

---

## Cost Optimization

### Instance Selection:
```
Dev/Test:
├── t3.medium instances
├── On-demand (no commitment)
└── Single AZ

Production:
├── m6i.large instances
├── Mix of On-Demand + Savings Plans
├── Multi-AZ (3 AZs minimum)
└── Karpenter for auto-optimization
```

### Data Transfer Costs:
```
Minimized by:
├── VPC Endpoints (no NAT/IGW)
├── Within-AZ communication preferred
├── S3 Gateway Endpoints
├── CloudFront caching
└── Direct Connect for hybrid
```

---

## Compliance Mapping

### Financial Regulations:
```
SOC 2 Type II:
✓ Access controls
✓ Change management
✓ Incident response
✓ Audit logging

PCI DSS:
✓ Network segmentation
✓ Encryption in transit/at rest
✓ Access controls
✓ Regular monitoring & testing

GDPR/Data Privacy:
✓ Data residency control
✓ Encryption at rest
✓ Data retention policies
✓ Audit trails
```

---

## Summary

This infrastructure provides:

| Aspect | Capability |
|--------|-----------|
| **Availability** | 99.99% (4x 9s) with multi-AZ |
| **Scalability** | Auto-scaling 2-15 nodes per tier |
| **Security** | Defense-in-depth with encryption & audit logs |
| **Compliance** | Financial-grade controls & monitoring |
| **Disaster Recovery** | 4-hour RTO, 15-minute RPO |
| **Cost Efficiency** | $X/month (varies by usage) |
