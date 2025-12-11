# 🚀 Full Stack Deployment Guide

This guide details the exact structure, files, and steps to follow for a flawless production deployment of the DhakaCart application.

---

## 📂 Key Files & Directories Structure

| Phase | Directory / File | Purpose |
|-------|------------------|---------|
| **1. Infra** | `terraform/aws-infra/` | Infrastructure Code (VPC, EC2, ALB) |
| **2. Auto** | `deploy-full-stack.sh` | **MASTER SCRIPT** - Runs *everything* (Infra+K8s+App+Seed) |
| **3. Config** | `scripts/load-env.sh` | Loads IPs from Terraform to scripts |
| **4. K8s** | `scripts/k8s-deployment/` | K8s manifest syncing & deploying |
| **5. Verify** | `scripts/monitoring/` | Check Grafana/Prometheus health |
| **6. Enterprise** | `scripts/enterprise-features/` | Enterprise features (Velero, Vault, Cert-Manager) |

---

## ✅ Phase 1: Pre-Deployment Check

Before running any script, ensure your environment is clean and ready.

1.  **Check AWS Credentials**:
    ```bash
    aws sts get-caller-identity
    ```
    *If this fails, run `aws configure`.*

2.  **Verify Project Root**:
    You must always start from the root:
    ```bash
    cd ~/DhakaCart-Final-Project
    ```

---

## 🚀 Phase 2: Automated Deployment (The "One-Click" Step)

We use a smart, resumable master script to handle 95% of the work.

### **Features:**
- **Checkpoint System**: Tracks progress in `.deploy_state`. If it fails, fix the issue and re-run; it resumes automatically.
- **Automated Seeding**: Automatically seeds the database with initial product data.
- **Idempotent**: Can be run multiple times without breaking things.

**Command:**
```bash
./deploy-full-stack.sh
```

**Options:**
- `force`: Restart from the beginning (Warning: Clears state).
  ```bash
  ./deploy-full-stack.sh --force
  ```

**What the script does (Steps 1-7):**
1.  **Infrastructure**: Terraforms VPC, Bastion, Masters, Workers.
2.  **Config**: Loads IPs dynamically.
3.  **Scripts**: Generates node config scripts.
4.  **Nodes**: Uploads scripts, updates hostnames across cluster.
5.  **Cluster**: Inits Master-1, Joins Master-2 & Workers.
6.  **App**: Deploys frontend, backend, DB, Redis, Monitoring.
    - **6.1 DB Seed**: Populates `products` table automatically.
7.  **ALB**: Registers workers with Target Groups for external access.

---

## 🔍 Phase 3: Verification (Critical Step)

Once the script finishes (~25 mins), perform these manual checks.

### 1. Check Access
Open the **Frontend URL** shown at the end of the script output.
*   **Success**: You see the DhakaCart Storefront with products loaded.

### 2. Check Monitoring
Open the **Grafana URL** (also shown in output).
- **User**: `admin`
- **Pass**: `dhakacart123`
- **Action**: Import Dashboard ID `1860` (Node Exporter Full) to see metrics.

---

## 🔒 Phase 3.5: Security & Testing (Manual Steps)

### 1. Apply Security Policies
```bash
cd scripts/security
./apply-security-hardening.sh
```

### 2. Run Load Test (Smoke Test)
```bash
cd ../../testing/load-tests
./run-load-test.sh
```
*   **Select Option 1** (Smoke Test).

### ⚠️ Load Test Issues?
- **Rate Limit Error**: Check if `trust proxy` is enabled in backend.
- **400 Bad Request**: Ensure K6 payload includes `total_amount`.

---

## 🏢 Phase 4: Enterprise Features

To meet enterprise compliance requirements, run these scripts after the main deployment.

### 1. Enable Automated Backups (Velero)
> **⚠️ Run on Master Node:**
> `ssh -i terraform/aws-infra/dhakacart-k8s-key.pem ubuntu@<MASTER_IP>`

```bash
cd scripts/enterprise-features
./install-velero.sh
```
*   **Result**: Velero installed, MinIO bucket configured.

### 2. Enable HTTPS (Cert-Manager)
```bash
./install-cert-manager.sh
```

### 3. Enable Vault Secrets
```bash
./install-vault.sh
```

---

## 🆘 Emergency Manual Fallbacks

If the automated script stops, check the error message.
- **Fix the specific error**.
- **Re-run `./deploy-full-stack.sh`** to resume.

| Error | Fix |
|-------|-----|
| **Terraform Lock** | `cd terraform/aws-infra && terraform force-unlock <ID>` |
| **SSH Permission** | `chmod 600 terraform/aws-infra/dhakacart-k8s-key.pem` |
| **DB Not Seeding** | Run `./scripts/database/seed-database.sh --automated` manually |
| **Grafana 404** | Run `scripts/monitoring/setup-grafana-alb.sh` |
| **Loki No Logs** | `kubectl rollout restart ds/promtail -n monitoring` |

---

## 🧹 Cleanup

**CRITICAL**: Destroy resources to avoid extra bills.

```bash
cd ~/DhakaCart-Final-Project/terraform/aws-infra
terraform destroy -auto-approve
```

---

**Last Updated**: 12 December 2025
**Guide Version**: 3.1 (Professional Standard)
