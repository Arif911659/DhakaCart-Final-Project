# DhakaCart Kubernetes Deployment Guide

Complete step-by-step guide for deploying DhakaCart e-commerce application on AWS using Terraform and Kubernetes.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Phase 1: Infrastructure Setup (Terraform)](#phase-1-infrastructure-setup-terraform)
- [Phase 2: Post-Terraform Configuration](#phase-2-post-terraform-configuration)
- [Phase 3: Kubernetes Cluster Setup](#phase-3-kubernetes-cluster-setup)
- [Phase 4: Application Deployment](#phase-4-application-deployment)
- [Phase 5: Monitoring Setup](#phase-5-monitoring-setup)
- [Phase 6: Security Hardening](#phase-6-security-hardening)
- [Phase 7: Verification](#phase-7-verification)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

- ✅ **Terraform** (v1.0+): `terraform --version`
- ✅ **AWS CLI** (v2.0+): `aws --version`
- ✅ **jq**: `jq --version`
- ✅ **SSH client**: `ssh -V`

### AWS Credentials

Ensure AWS credentials are configured:
```bash
aws configure
# Or set environment variables:
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-southeast-1"
```

### Project Structure

```
DhakaCart-03-test/
├── terraform/simple-k8s/        # Infrastructure as Code
├── scripts/                      # Automation scripts
│   ├── security/                 # Security hardening
│   ├── monitoring/               # Monitoring & Alerting
│   ├── k8s-deployment/          # K8s deployment automation
│   ├── database/                 # Database utilities
│   └── hostname/                 # Hostname management
├── k8s/                          # Kubernetes manifests
│   ├── deployments/              # Application deployments
│   ├── services/                 # Kubernetes services
│   ├── configmaps/              # Configuration maps
│   ├── secrets/                  # Secrets management
│   ├── ingress/                  # Ingress configurations
│   ├── volumes/                  # Persistent volumes
│   ├── monitoring/              # Monitoring stack
│   └── security/                 # Network policies
├── frontend/                     # React frontend application
├── backend/                      # Node.js backend API
├── database/                     # Database initialization
├── security/                     # Security tools & policies
│   ├── scanning/                 # Vulnerability scanning
│   ├── network-policies/        # K8s network policies
│   └── ssl/                      # SSL/TLS automation
├── testing/                      # Load tests & benchmarks
│   ├── load-tests/              # K6 load testing
│   └── performance/             # Performance benchmarks
└── docs/                         # Documentation
```


---

## Phase 1: Infrastructure Setup (Terraform)

### Step 1.1: Navigate to Terraform Directory

```bash
cd /home/arif/DhakaCart-03-test/terraform/simple-k8s
```

### Step 1.2: Initialize Terraform

```bash
terraform init
```

**Expected output**: "Terraform has been successfully initialized!"

### Step 1.3: Review Infrastructure Plan

```bash
terraform plan
```

**Review**: Check that the plan includes:
- 1 Bastion host (public subnet)
- 2 Master nodes (private subnet)
- 3 Worker nodes (private subnet)
- 1 Application Load Balancer
- VPC, subnets, security groups

### Step 1.4: Apply Terraform Configuration

```bash
terraform apply
```

**Confirmation**: Type `yes` when prompted

**Duration**: ~5-10 minutes

**Expected output**:
```
Apply complete! Resources: 30+ added, 0 changed, 0 destroyed.

Outputs:
bastion_public_ip = "54.251.183.40"
load_balancer_dns = "dhakacart-k8s-alb-xxxxx.ap-southeast-1.elb.amazonaws.com"
...
```

### Step 1.5: Save Terraform Outputs

```bash
terraform output > infrastructure-outputs.txt
```

**Important**: Keep this file for reference!

---

## Phase 2: Automated Deployment (Recommended)
 
 ### Step 2.1: Run the Master Deployment Script
 
 We now use a single, resumable script that handles Infrastructure, Config, Node Setup, App Deployment, and Seeding.
 
 ```bash
 cd /home/arif/DhakaCart-03-test
 ./scripts/deploy-4-hour-window.sh
 ```
 
 **Features:**
 - **Auto-Resume**: If it fails, run it again; it picks up where it left off.
 - **Automated Seeding**: No need to run seeding scripts manually.
 - **Full Stack**: Deploys Infra + K8s + App + Monitoring.
 
 **Expected Time**: ~25-30 minutes.
 
 ---
 
 ## Phase 3: Kubernetes Cluster Setup (Manual Fallback)
 
 *Only follow this phase if you are NOT using the master script above.*
 
 ### Step 3.1: Deploy Kubernetes Cluster

```bash
cd ../../scripts/k8s-deployment
./update-and-deploy.sh
```

This script will:
1. Copy K8s manifests to Master-1
2. Apply all Kubernetes configurations
3. Deploy application pods
4. Configure monitoring stack

**Duration**: ~5-10 minutes

### Step 3.2: Verify Cluster Status

SSH to Master-1 and check:

```bash
ssh -i ../../terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@<BASTION_IP>
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@<MASTER1_IP>

# Check nodes
kubectl get nodes

# Expected output:
# NAME       STATUS   ROLES           AGE   VERSION
# Master-1   Ready    control-plane   10m   v1.28.x
# Master-2   Ready    control-plane   10m   v1.28.x
# Worker-1   Ready    <none>          10m   v1.28.x
# Worker-2   Ready    <none>          10m   v1.28.x
# Worker-3   Ready    <none>          10m   v1.28.x
```

### Step 3.3: Check Application Pods

```bash
# Check dhakacart namespace
kubectl get pods -n dhakacart

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# dhakacart-backend-xxxxx               1/1     Running   0          5m
# dhakacart-frontend-xxxxx              1/1     Running   0          5m
# dhakacart-db-xxxxx                    1/1     Running   0          5m
# dhakacart-redis-xxxxx                 1/1     Running   0          5m
```

---

## Phase 4: Application Deployment

### Step 4.1: Register Workers to ALB
 (Automated by `deploy-4-hour-window.sh`. If manual:)
 ```bash
 cd /home/arif/DhakaCart-03-test/terraform/simple-k8s
 ./register-workers-to-alb.sh
 ```

**Expected**: All workers registered and healthy

### Step 4.2: Seed Database (Automated)
 
 This is handled automatically by the master script.
 If you need to re-seed manually:
 ```bash
 cd ../../scripts
 ./seed-database.sh --automated
 ```

### Step 4.3: Access Application

**Frontend**: http://\<ALB_DNS\>

**Test**:
- Browse products
- Add items to cart
- Test checkout flow

---

## Phase 5: Monitoring Setup

### Step 5.1: Verify Monitoring Stack

```bash
# SSH to Master-1
kubectl get pods -n monitoring

# Expected output:
# NAME                                     READY   STATUS    RESTARTS   AGE
# grafana-xxxxx                            1/1     Running   0          10m
# loki-xxxxx                               1/1     Running   0          10m
# prometheus-deployment-xxxxx              1/1     Running   0          10m
# promtail-xxxxx                           1/1     Running   0          10m
# node-exporter-xxxxx                      1/1     Running   0          10m
```

### Step 5.2: Access Grafana

**URL**: http://\<ALB_DNS\>/grafana/

**Credentials**:
- Username: `admin`
- Password: `dhakacart123`

### Step 5.3: Verify Dashboards

1. **Prometheus Metrics**:
   - Go to Explore → Select Prometheus
   - Query: `up`
   - Should show all targets

2. **Loki Logs**:
   - Go to Explore → Select Loki
   - Query: `{job="kubernetes-pods"}`
   - Should show logs from all pods

### Step 5.4: Troubleshooting Monitoring
| Issue | Command | Fix |
|-------|---------|-----|
| **Pods Pending** | `kubectl get pods -n monitoring` | Check node resources |
| **Grafana 404** | `curl -I http://<ALB_DNS>/grafana/` | Run `scripts/monitoring/setup-grafana-alb.sh` |
| **No Logs (Loki)** | `kubectl logs -n monitoring ds/promtail` | `kubectl rollout restart ds/promtail -n monitoring` |
| **No Metrics** | Check Prometheus Target | Check ServiceMonitor or Pod Annotations |

### Step 5.5: Manual Setup (If Automated Fails)
If the master script fails to deploy monitoring:
```bash
# 1. Deploy Stack
kubectl apply -f k8s/monitoring/ --recursive

# 2. Setup ALB Ingress
cd scripts/monitoring
./setup-grafana-alb.sh
```

---

## Phase 6: Security Hardening

### Step 6.1: Run Automated Security Hardening
This single script applies network policies, scans images, and checks dependencies.

```bash
cd /home/arif/DhakaCart-03-test/scripts/security
./apply-security-hardening.sh
```

**Expected output**:
```
✅ Network policies applied
✅ Security scans completed
✅ Dependency check completed
✅ Network isolation verified
```

### Step 6.2: View Security Reports (Optional)
Reports are generated in `/tmp`:

```bash
ls -l /tmp/trivy-reports-*/
cat /tmp/trivy-reports-*/SUMMARY.txt
```

### Step 6.3: Fix Vulnerabilities (If critical)
If the report shows critical issues:

```bash
# Backend
cd /home/arif/DhakaCart-03-test/backend
npm audit fix

# Frontend  
cd ../frontend
npm audit fix

# Rebuild and push images
docker build -t arifhossaincse22/dhakacart-backend:latest ./backend
docker push arifhossaincse22/dhakacart-backend:latest
```

### Step 6.4: Verify Network Isolation

Test that network policies are working correctly:

**Frontend can reach Backend** (should work):
```bash
# On Master-1
kubectl exec -it -n dhakacart deployment/dhakacart-frontend -- curl -s http://dhakacart-backend-service:5000/health
```

**Expected**: `{"status":"ok"}` or similar success response

**Database CANNOT reach Internet** (should timeout):
```bash
kubectl exec -it -n dhakacart deployment/dhakacart-db -- curl -m 5 https://google.com
```

**Expected**: Timeout after ~5 seconds (this proves isolation is working)

### Step 6.5: Security Checklist

- [ ] **Network Policies Applied**: 3 policies active in dhakacart namespace
- [ ] **Container Scan Clean**: No CRITICAL vulnerabilities in images
- [ ] **Dependencies Audited**: npm audit shows 0 high/critical issues  
- [ ] **Network Isolation Verified**: Database cannot reach external internet
- [ ] **Secrets Management**: No hardcoded passwords in code

---

## Phase 7: Verification

### Checklist

- [ ] **Infrastructure**
  - [ ] Bastion accessible via SSH
  - [ ] All nodes showing in `kubectl get nodes`
  - [ ] ALB health checks passing

- [ ] **Application**
  - [ ] Frontend loads at ALB URL
  - [ ] Backend API responding
  - [ ] Database connected
  - [ ] Redis caching working

- [ ] **Monitoring**
  - [ ] Grafana accessible
  - [ ] Prometheus collecting metrics
  - [ ] Loki collecting logs
  - [ ] Dashboards showing data

### Phase 7.1: Performance Testing (Optional)
 
 Validate system performance under load:
 
 ```bash
 cd /home/arif/DhakaCart-03-test/testing/load-tests
 ./run-load-test.sh
 ```
 *   **Select**: Option 2 (Load Test) for standard validation.
 *   **Auto-detection**: The script automatically finds the ALB URL.
 
 ### Load Test Troubleshooting
 
 **1. High Error Rate (`http_req_failed`)**:
 - **Rate Limiting**: If backend logs show `ERR_ERL_UNEXPECTED_X_FORWARDED_FOR`, add `app.set('trust proxy', 1)` to `server.js`.
 - **Bad Request (400)**: Ensure K6 script sends valid `total_amount` and `price`.
 
 ### Verification Commands

```bash
# Check all pods across namespaces
kubectl get pods --all-namespaces

# Check services
kubectl get svc --all-namespaces

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn <FRONTEND_TG_ARN>

# Test frontend
curl -I http://<ALB_DNS>

# Test backend
curl http://<ALB_DNS>/api/health
```

---


---

## Phase 8: Exam Compliance (Enterprise Features)

> **✨ Automated:** This phase is now handled automatically by `deploy-4-hour-window.sh` (Step 8).
> Use the steps below **only** if you need to run them manually or for troubleshooting.

To meet the 10 Exam Constraints, these scripts must be run **on the Master Node**.

### Step 8.1: Connect to Master Node
```bash
# 1. SSH to Master-1 (via Bastion)
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@<BASTION_IP>
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@<MASTER1_IP>

# 2. Go to scripts directory
cd ~/scripts/enterprise-features
```

### Step 8.2: Run Enterprise Scripts

**A. Enable Automated Backups (Velero):**
```bash
./install-velero.sh
```

**B. Enable HTTPS (Cert-Manager):**
```bash
./install-cert-manager.sh
```

**C. Enable Vault Secrets:**
```bash
./install-vault.sh
```

---

## Troubleshooting

### Common Issues

#### 1. Terraform Apply Fails

**Error**: "Error creating EC2 instance"

**Solution**:
- Check AWS credentials
- Verify region availability
- Check service quotas

#### 2. Pods Not Starting

**Error**: "ImagePullBackOff" or "CrashLoopBackOff"

**Solution**:
```bash
# Check pod details
kubectl describe pod <POD_NAME> -n dhakacart

# Check logs
kubectl logs <POD_NAME> -n dhakacart
```

#### 3. ALB Health Checks Failing

**Error**: Targets showing "unhealthy"

**Solution**:
```bash
# Check NodePort services
kubectl get svc -n dhakacart

# Verify pods are running
kubectl get pods -n dhakacart

# Check security groups allow ALB → Workers traffic
```

#### 4. Grafana Not Accessible

**Error**: 404 or connection timeout

**Solution**:
```bash
# Run Grafana ALB setup
cd /home/arif/DhakaCart-03-test/scripts
./setup-grafana-alb.sh
```

#### 5. No Logs in Loki

**Error**: "No logs volume available"

**Solution**:
```bash
# Check Promtail
kubectl logs -n monitoring daemonset/promtail


# Restart Promtail
kubectl rollout restart daemonset/promtail -n monitoring
```

#### 6. Prometheus Targets Down
**Error**: Targets show 0/0 or Down in Grafana.
**Solution**:
```bash
# Check Node Exporter
kubectl get pods -n monitoring -l app=node-exporter

# Check Service Discovery
kubectl get endpoints -n monitoring
```
```

### Getting Help

📚 **Detailed Troubleshooting**: See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

📚 **Loki Issues**: See [docs/LOKI-TROUBLESHOOTING.md](docs/LOKI-TROUBLESHOOTING.md)

📚 **Quick Reference**: See [QUICK-REFERENCE.md](QUICK-REFERENCE.md)

---

## Important URLs and Credentials

### Application

- **Frontend**: http://\<ALB_DNS\>
- **Backend API**: http://\<ALB_DNS\>/api

### Monitoring

- **Grafana**: http://\<ALB_DNS\>/grafana/
  - Username: `admin`
  - Password: `dhakacart123`

### SSH Access

- **Bastion**: `ssh -i dhakacart-k8s-key.pem ubuntu@<BASTION_IP>`
- **Master-1**: From Bastion: `ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@<MASTER1_IP>`

---

## Next Steps After Deployment


1. **Configure DNS** (Optional):
   - Point your domain to ALB DNS
   - Update Grafana root URL

2. **Run Enterprise Scripts**:
   - As detailed in Phase 7.5, run the scripts in `scripts/enterprise-features/`.

3. **CI/CD Pipeline**:
   - Setup GitHub Actions
   - Automate deployments

---

## Phase 8: CI/CD & Maintenance

### Step 8.1: Setup GitHub Actions (Auto Deployment)

To enable automatic deployment when you push code:

1. **Fetch Kubeconfig**:
   ```bash
   ./scripts/fetch-kubeconfig.sh
   ```
2. **Add to GitHub**:
   - Copy the output.
   - Go to GitHub Repo Settings > Secrets > Actions.
   - Add new secret named `KUBECONFIG` with the copied content.

### Step 8.2: Manual Release (Optional)

If you prefer manual control or need an emergency fix, use the `Makefile`:

```bash
# Build, Push, and Deploy a new version
make release
```

To change the version, edit the `VERSION` variable in the `Makefile` first.

---

## Cleanup (Destroy Infrastructure)

⚠️ **Warning**: This will delete all resources!

```bash
cd /home/arif/DhakaCart-03-test/terraform/simple-k8s
terraform destroy
```

Type `yes` to confirm.

---

## Summary

You have successfully deployed:
- ✅ AWS infrastructure (VPC, EC2, ALB)
- ✅ Kubernetes cluster (2 masters, 3 workers)
- ✅ DhakaCart application (frontend, backend, database)
- ✅ Monitoring stack (Prometheus, Grafana, Loki)

**Total deployment time**: ~20-30 minutes

For questions or issues, refer to the troubleshooting documentation or check the logs.
