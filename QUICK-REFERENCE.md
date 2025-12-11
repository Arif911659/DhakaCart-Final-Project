# DhakaCart Quick Reference

One-page cheat sheet for common operations and commands.

## 🚀 Quick Start (After Terraform Apply)

```bash
cd /home/arif/DhakaCart-03-test/scripts
./post-terraform-setup.sh
```

---

## 📋 Common Commands

### Infrastructure

```bash
# Get Bastion IP
cd terraform/simple-k8s
terraform output bastion_public_ip

# Get ALB DNS
terraform output load_balancer_dns

# SSH to Bastion
ssh -i dhakacart-k8s-key.pem ubuntu@<BASTION_IP>

# SSH to Master-1 (from Bastion)
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@<MASTER1_IP>
```

### Kubernetes

```bash
# Get all nodes
kubectl get nodes

# Get all pods
kubectl get pods --all-namespaces

# Get application pods
kubectl get pods -n dhakacart

# Get monitoring pods
kubectl get pods -n monitoring

# Check pod logs
kubectl logs <POD_NAME> -n dhakacart

# Restart deployment
kubectl rollout restart deployment/<DEPLOYMENT_NAME> -n dhakacart
```

### Application

```bash
# Seed database
cd scripts
./seed-database.sh

# Update application
cd scripts/k8s-deployment
./update-and-deploy.sh

# Check database
./diagnose-db-products-issue.sh
```

### Monitoring

```bash
# Setup Grafana ALB
cd scripts/monitoring
./setup-grafana-alb.sh

# Deploy alerting
./deploy-alerting-stack.sh

# Check Prometheus
./check-prometheus-metrics.sh

# Fix Grafana
./fix-grafana-config.sh

# Restart Promtail (if logs not showing)
kubectl rollout restart daemonset/promtail -n monitoring
```

### Security

```bash
# Apply security hardening
cd scripts/security
./apply-security-hardening.sh

# Run vulnerability scan
cd ../../security/scanning
./trivy-scan.sh

# Check network policies
# Check network policies
kubectl get networkpolicies -n dhakacart

### Testing

```bash
# Run Load Test (Auto-detects ALB)
cd testing/load-tests
./run-load-test.sh
```

### ⚠️ Load Test Troubleshooting
| Error | Cause | Fix |
|-------|-------|-----|
| `http_req_failed` > 0% | Rate Limit or Bad Request | Check Backend logs |
| `ERR_ERL_UNEXPECTED` | Missing `trust proxy` | Add `app.set('trust proxy', 1)` in server.js |
| `400 Bad Request` | Invalid Order Payload | Update K6 script to include `total_amount` |

```

### Manual Release (Makefile)

```bash
# Build, Push, and Deploy
make release

# Just Build
make build

# Just Push
make push

# Just Deploy
make deploy
```

### Ansible Automation

```bash
# Check connection to all servers
cd ansible && ansible all -m ping

# Check disk space on all nodes
ansible all -m command -a "df -h"
```


### CI/CD Setup

```bash
# Fetch Kubeconfig for GitHub Secrets
./scripts/fetch-kubeconfig.sh
```

### Phase 8 (Exam Compliance Features)
**⚠️ Run on Master-1 via SSH:**

```bash
# SSH to Master-1 from Bastion
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@<BASTION_IP>
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@<MASTER1_IP>

# Go to scripts
cd scripts/enterprise-features
```

```bash
# 1. Backups (Velero + MinIO)
./scripts/enterprise-features/install-velero.sh

#### 🛠️ Velero Commands (Run on Master-1)
```bash
# 1. Manual Backup
velero backup create manual-backup-01 --include-namespaces dhakacart

# 2. Automated Daily Backup (Cron)
velero schedule create daily-backup --schedule="0 0 * * *" --include-namespaces dhakacart

# 3. Check Backups
velero backup get

# 4. Check Schedules
velero schedule get

# 5. Restore from Backup
velero restore create --from-backup manual-backup-01
```

# 2. HTTPS (Cert-Manager)
./scripts/enterprise-features/install-cert-manager.sh

# 3. Secrets (Vault)
./scripts/enterprise-features/install-vault.sh
```

---

## 🔗 Important URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| **Frontend** | http://\<ALB_DNS\> | - |
| **Backend API** | http://\<ALB_DNS\>/api | - |
| **Grafana** | http://\<ALB_DNS\>/grafana/ | admin / dhakacart123 |

---

## 📁 Script Organization

```
scripts/
├── load-infrastructure-config.sh    # Load IPs from Terraform
├── post-terraform-setup.sh          # Post-terraform automation
├── fetch-kubeconfig.sh              # Fetch Kubeconfig for CI/CD
│
├── security/                        # Security hardening
│   └── apply-security-hardening.sh  # Network policies + scans
│
├── monitoring/                      # Monitoring & Alerting
│   ├── deploy-alerting-stack.sh     # Deploy Prometheus alerts
│   ├── setup-grafana-alb.sh         # Setup Grafana ALB
│   ├── check-prometheus-metrics.sh  # Check Prometheus
│   └── fix-grafana-config.sh        # Fix Grafana
│
├── k8s-deployment/                  # Kubernetes deployment
│   ├── update-and-deploy.sh         # Deploy/update application
│   ├── copy-k8s-to-master1.sh       # Copy manifests
│   └── sync-k8s-to-master1.sh       # Sync manifests
│
├── database/                        # Database scripts
│   ├── seed-database.sh             # Seed database
│   └── diagnose-db-issues.sh        # Diagnose DB issues
│
├── internal/hostname/           # Hostname management
│   ├── change-hostname.sh           # Local hostname change
│   └── change-hostname-via-bastion.sh  # Remote via Bastion
│
├── enterprise-features/         # [Phase 2]
│   ├── install-velero.sh
│   ├── install-cert-manager.sh
│   └── install-vault.sh
```

---

## 🔧 Troubleshooting Quick Fixes

### Pods Not Starting

```bash
kubectl describe pod <POD_NAME> -n dhakacart
kubectl logs <POD_NAME> -n dhakacart
```

### ALB Health Checks Failing

```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn <TG_ARN>

# Re-register workers
cd terraform/simple-k8s
./register-workers-to-alb.sh
```

### Grafana Not Accessible

```bash
cd scripts
./setup-grafana-alb.sh
```

### No Logs in Loki

```bash
# Check Promtail
kubectl logs -n monitoring daemonset/promtail

# Restart Promtail
kubectl rollout restart daemonset/promtail -n monitoring

# Check positions file
kubectl exec -n monitoring daemonset/promtail -- cat /run/promtail/positions.yaml
```

### Database Connection Issues

```bash
# Check database pod
kubectl get pods -n dhakacart | grep db

# Check database logs
kubectl logs -n dhakacart <DB_POD_NAME>

# Restart database
kubectl rollout restart deployment/dhakacart-db -n dhakacart
```

---

## 📊 Verification Checklist

### After Terraform Apply

- [ ] Bastion accessible: `ssh -i dhakacart-k8s-key.pem ubuntu@<BASTION_IP>`
- [ ] SSH key copied to Bastion
- [ ] All nodes in `kubectl get nodes`

### After Application Deployment

- [ ] All pods running: `kubectl get pods -n dhakacart`
- [ ] Frontend accessible: `curl -I http://<ALB_DNS>`
- [ ] Backend API responding: `curl http://<ALB_DNS>/api/health`

### After Monitoring Setup

- [ ] Grafana accessible: http://\<ALB_DNS\>/grafana/
- [ ] Prometheus showing metrics
- [ ] Loki showing logs: `{job="kubernetes-pods"}`

---

## 🆘 Emergency Commands

### Restart Everything

```bash
# Restart all application pods
kubectl rollout restart deployment -n dhakacart

# Restart monitoring stack
kubectl rollout restart deployment -n monitoring
kubectl rollout restart daemonset -n monitoring
```

### Check Cluster Health

```bash
# Node status
kubectl get nodes

# Component status
kubectl get componentstatuses

# All pods status
kubectl get pods --all-namespaces | grep -v Running
```

### Destroy and Rebuild

```bash
# Destroy infrastructure
cd terraform/simple-k8s
terraform destroy

# Rebuild
terraform apply
cd ../../scripts
./post-terraform-setup.sh
```

---

## 📚 Documentation Links

- **Full Deployment Guide**: [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)
- **Troubleshooting**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Loki Troubleshooting**: [docs/LOKI-TROUBLESHOOTING.md](docs/LOKI-TROUBLESHOOTING.md)
- **Hostname Change**: [scripts/README-hostname-change.md](scripts/README-hostname-change.md)

---

## 💡 Pro Tips

1. **Always source config before running scripts**:
   ```bash
   source scripts/load-infrastructure-config.sh
   ```

2. **Use dry-run for testing**:
   ```bash
   ./change-hostname-via-bastion.sh --dry-run
   ```

3. **Check logs first when debugging**:
   ```bash
   kubectl logs <POD_NAME> -n <NAMESPACE> --tail=50
   ```

4. **Keep backups of working configurations**:
   ```bash
   kubectl get all -n dhakacart -o yaml > backup.yaml
   ```

5. **Monitor resource usage**:
   ```bash
   kubectl top nodes
   kubectl top pods -n dhakacart
   ```

---

## 🔑 Key Files

| File | Purpose |
|------|---------|
| `terraform/simple-k8s/dhakacart-k8s-key.pem` | SSH private key |
| `terraform/simple-k8s/terraform.tfstate` | Terraform state |
| `scripts/load-infrastructure-config.sh` | Config loader |
| `k8s/` | Kubernetes manifests |

---

**Last Updated**: 2025-12-07  
**Version**: 1.0
