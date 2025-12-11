# 📜 DhakaCart Scripts Guide

This directory contains all the automation scripts for deploying, managing, and securing the DhakaCart application.

## 📂 Directory Structure

```
scripts/
├── deploy-4-hour-window.sh        # 🚀 MASTER SCRIPT: Deploys everything (Resume + Seed)
├── post-terraform-setup.sh        # 🛠️ SETUP: Interactive config after Terraform
├── fetch-kubeconfig.sh            # 🔑 ACCESS: Get Kubeconfig for local access
├── load-infrastructure-config.sh  # ⚙️ CONFIG: Helper to load Terraform outputs
│
├── enterprise-features/           # 🏢 EXAM SOLUTION (Phase 2)
│   ├── install-velero.sh          # Backups (MinIO Integrated)
│   ├── install-cert-manager.sh    # HTTPS
│   ├── install-vault.sh           # Secrets
│   └── minio-manifests.yaml       # MinIO Deployment
│
├── k8s-deployment/                # ☸️ KUBERNETES
│   ├── sync-k8s-to-master1.sh     # Syncs files to Master Node
│   └── update-and-deploy.sh       # Deploys App Manifests
│
├── database/                      # 💾 DATABASE
│   ├── seed-database.sh           # Seeds sample data (Supports --automated)
│   └── init.sql                   # SQL seed file

---

## 🚦 Application Workflow: Which Script? When?

### 1. **I want to deploy everything from scratch** (Start Here)
*   **Script**: `./deploy-4-hour-window.sh`
*   **What it does (Enhanced)**:
    1.  Provisions AWS Infra (Terrform).
    2.  Configures K8s Cluster (Kubeadm).
    3.  Deploys Backend, Frontend, DB, Redis.
    4.  **Auto-Seeds Database**.
    5.  **Smart Resume**: Skips completed steps if re-run.
*   **Use Case**: Fresh 4-hour deployment window.

### 2. **I just updated the code and want to re-deploy**
*   **Option A (Automated)**:
    1.  `./scripts/k8s-deployment/sync-k8s-to-master1.sh` (Syncs files).
    2.  SSH to Master-1: `ssh ubuntu@<MASTER_IP>`.
    3.  Run: `./k8s/deploy-prod.sh`.

### 3. **I want to fix/reset the Database**
*   **Script**: `./scripts/database/seed-database.sh`
*   **Options**:
    *   Interactive: Run without flags.
    *   Automated: Run with `--automated` to skip prompts.
*   **Use Case**: Products not showing on Frontend.

### 4. **I want to meet Exam Requirements (Enterprise Layers)** (Mandatory)
These scripts must be run on the **Master Node** via SSH.

*   **Backups (Velero + MinIO)**: `./scripts/enterprise-features/install-velero.sh`
    *   *Note: Uses MinIO (Self-hosted) to solve AWS S3 permission issues.*
*   **HTTPS (Cert-Manager)**: `./scripts/enterprise-features/install-cert-manager.sh`
*   **Secrets (Vault)**: `./scripts/enterprise-features/install-vault.sh`

### 5. **I want to secure the cluster**
*   **Script**: `./scripts/security/apply-security-hardening.sh`
*   **What it does**:
    1.  Runs Trivy vulnerability scans.
    2.  Applies Network Policies (Frontend/DB isolation).

### 6. **I want to access the cluster from my laptop**
*   **Script**: `./scripts/fetch-kubeconfig.sh`
*   **What it does**: Downloads `admin.conf` from Master-1 to your `~/.kube/config`.

---

## 🛠 Helper Scripts (Internal Use)

*   `load-infrastructure-config.sh`: Used by other scripts to find IP addresses.
*   `internal/generate-ansible-inventory.sh`: Creates Ansible hosts file.
*   `internal/update-alb-dns-dynamic.sh`: Updates source code with new Load Balancer URL.
*   `internal/hostname/change-hostname-via-bastion.sh`: Automates hostname updates.

---

## ⚠️ Important Notes

*   **Always run from project root**: `cd ~/DhakaCart-03-test` before running `./scripts/...`.
*   **Execution Permission**: If permission denied, run `chmod +x scripts/**/*.sh`.

---

## 🔧 Troubleshooting Common Script Issues

| Issue | Solution |
|-------|----------|
| `Permission denied` | Run `chmod +x <script_name>` |
| `terraform/terraform.tfstate not found` | Run `terraform apply` first to generate state file |
| `SSH connection failed` | Check `dhakacart-k8s-key.pem` permissions (must be 400/600) |
| **Script hangs/fails** | Fix issue and re-run `./deploy-4-hour-window.sh` (It will resume) |

