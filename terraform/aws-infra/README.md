# Terraform Infrastructure - DhakaCart K8s

Terraform configuration for DhakaCart Kubernetes cluster on AWS.

## Directory Structure

```
terraform/simple-k8s/
├── main.tf                      # Main infrastructure configuration
├── variables.tf                 # Input variables
├── outputs.tf                   # Output values
├── alb-backend-config.tf        # ALB backend configuration
├── terraform.tfstate            # Terraform state (DO NOT EDIT)
├── .terraform.lock.hcl          # Dependency lock file
├── dhakacart-k8s-key.pem        # SSH private key (KEEP SECURE)
│
├── scripts/                     # Automation scripts
│   ├── post-apply.sh            # Post-terraform apply automation
│   ├── register-workers-to-alb.sh  # Register workers to ALB
│   └── update-configmap-auto.sh    # Update ConfigMap with ALB DNS
│
├── docs/                        # Documentation
│   ├── README.md                # This file
│   ├── DEPLOYMENT_SUCCESS.md    # Deployment success guide
│   └── README_AUTOMATION_2025-12-01.md  # Automation documentation
│
├── outputs/                     # Output files
│   └── aws_instances_output.txt # EC2 instances information
│
└── backups/                     # Backup directory
    └── (terraform state backups)
```

## Quick Start

### 1. Initialize Terraform

```bash
cd /home/arif/DhakaCart-03-test/terraform/simple-k8s
terraform init
```

### 2. Plan Infrastructure

```bash
terraform plan
```

Review the plan to ensure it matches your expectations.

### 3. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

**Duration**: ~5-10 minutes

### 4. Run Post-Apply Automation

```bash
cd ../../scripts
./post-terraform-setup.sh
```

This will:
- Load infrastructure configuration
- Update all scripts with IPs
- Optionally change hostnames
- Setup Grafana ALB routing

## Important Files

### Configuration Files

| File | Purpose |
|------|---------|
| `main.tf` | Main infrastructure definition |
| `variables.tf` | Input variables (region, instance types, etc.) |
| `outputs.tf` | Output values (IPs, DNS, etc.) |
| `alb-backend-config.tf` | ALB backend target groups |

### State Files

| File | Purpose | Notes |
|------|---------|-------|
| `terraform.tfstate` | Current infrastructure state | **DO NOT EDIT MANUALLY** |
| `.terraform.lock.hcl` | Dependency versions | Commit to version control |

### Credentials

| File | Purpose | Security |
|------|---------|----------|
| `dhakacart-k8s-key.pem` | SSH private key | **KEEP SECURE** - chmod 600 |

## Common Commands

### View Outputs

```bash
# All outputs
terraform output

# Specific output
terraform output bastion_public_ip
terraform output load_balancer_dns

# JSON format
terraform output -json
```

### Refresh State

```bash
terraform refresh
```

### Destroy Infrastructure

⚠️ **Warning**: This will delete all resources!

```bash
terraform destroy
```

Type `yes` to confirm.

## Scripts

### post-apply.sh

Runs automatically after `terraform apply` (if configured) or manually:

```bash
./scripts/post-apply.sh
```

**Actions**:
- Displays infrastructure details
- Saves outputs to file
- Provides next steps

### register-workers-to-alb.sh

Registers worker nodes to ALB target groups:

```bash
./scripts/register-workers-to-alb.sh
```

**Required**: After Kubernetes cluster is deployed

### update-configmap-auto.sh

Updates Kubernetes ConfigMap with ALB DNS:

```bash
./scripts/update-configmap-auto.sh
```

**Required**: After application deployment

## Outputs

After `terraform apply`, you'll get:

```
bastion_public_ip = "54.251.183.40"
master_private_ips = [
  "10.0.10.10",
  "10.0.10.11"
]
worker_private_ips = [
  "10.0.10.20",
  "10.0.10.21",
  "10.0.10.22"
]
load_balancer_dns = "dhakacart-k8s-alb-xxxxx.ap-southeast-1.elb.amazonaws.com"
vpc_id = "vpc-xxxxx"
```

## Infrastructure Components

### Network

- **VPC**: 10.0.0.0/16
- **Public Subnets**: 10.0.1.0/24 (Bastion, NAT), 10.0.2.0/24 (ALB)
- **Private Subnets**: 10.0.10.0/24 (Masters, Workers)

### Compute (Static IPs)

- **Bastion**: 1x t3.small
  - Public IP: Dynamic
  - Private IP: `10.0.1.10`
- **Masters**: 2x t3.medium
  - Private IPs: `10.0.10.10`, `10.0.10.11`
- **Workers**: 3x t3.medium
  - Private IPs: `10.0.10.20`, `10.0.10.21`, `10.0.10.22`

### Load Balancer

- **ALB**: Application Load Balancer
- **Target Groups**:
  - Frontend (port 30080)
  - Backend (port 30081)
  - Grafana (port 30091)

## Troubleshooting

### Issue: Terraform State Lock

```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Issue: SSH Key Permissions

```bash
chmod 600 dhakacart-k8s-key.pem
```

### Issue: AWS Credentials

```bash
# Verify credentials
aws sts get-caller-identity

# Configure if needed
aws configure
```

### Issue: Resource Already Exists

```bash
# Import existing resource
terraform import <RESOURCE_TYPE>.<NAME> <RESOURCE_ID>
```

## Best Practices

1. **Always run `terraform plan` before `apply`**
2. **Keep terraform.tfstate secure** - contains sensitive data
3. **Use version control** - commit .tf files, not .tfstate
4. **Backup state regularly** - to backups/ directory
5. **Use workspaces** for multiple environments (optional)

## State Management

### Backup State

```bash
cp terraform.tfstate backups/terraform.tfstate.$(date +%Y%m%d_%H%M%S)
```

### Restore State

```bash
cp backups/terraform.tfstate.YYYYMMDD_HHMMSS terraform.tfstate
```

## Variables

Edit `variables.tf` to customize:

```hcl
variable "aws_region" {
  default = "ap-southeast-1"
}

variable "cluster_name" {
  default = "dhakacart-k8s"
}

variable "master_count" {
  default = 2
}

variable "worker_count" {
  default = 3
}
```

## Next Steps

After successful `terraform apply`:

1. **Run post-terraform setup**:
   ```bash
   cd ../../scripts
   ./post-terraform-setup.sh
   ```

2. **Deploy Kubernetes cluster**:
   ```bash
   cd scripts/k8s-deployment
   ./update-and-deploy.sh
   ```

3. **Access application**:
   - Frontend: http://\<ALB_DNS\>
   - Grafana: http://\<ALB_DNS\>/grafana/

## Documentation

- **Main Deployment Guide**: [../../DEPLOYMENT-GUIDE.md](../../DEPLOYMENT-GUIDE.md)
- **Quick Reference**: [../../QUICK-REFERENCE.md](../../QUICK-REFERENCE.md)
- **Troubleshooting**: [../../docs/TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)

## Support

For issues or questions:
1. Check [TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)
2. Review Terraform logs
3. Check AWS console for resource status

---

**Last Updated**: 2025-12-09  
**Terraform Version**: 1.0+  
**AWS Provider Version**: ~> 5.0
