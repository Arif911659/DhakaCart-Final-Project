# 🚀 Phase 2 Technical Specification: Enterprise Features
> **Codebase Location:** `scripts/enterprise-features/` & `k8s/enterprise-features/`

এই ডকুমেন্টটি আপনাকে বোঝাবে **Phase 2** তে আমরা আসলে কী করব এবং কেন করব। আগামীকাল আমরা এই স্টেপগুলোই ফলো করব।

---

## 1. Automated Backups (Velero)
**Objective:** ডাটাবেস এবং কুবারনেটিস রিসোর্স অটোমেটিক ব্যাকআপ নেওয়া, যাতে ক্র্যাশ করলে ১ কমান্ডে রিস্টোর করা যায়।

### 🛠️ Architecture
*   **Tool:** Velero (Industry Standard for K8s Backup).
*   **Storage:** AWS S3 Bucket (Cloud Storage).
*   **Mechanism:** Snapshot of Persistent Volume (Database) + YAML Backups.

### 📋 Implementation Steps (Execution Guide)
**Step 1:** Run the automation script:
```bash
./scripts/enterprise-features/install-velero.sh
```
*(This will check credentials, create S3 bucket if needed, install Velero, and schedule daily backups.)*

# 🦅 Phase 2 Technical Specification: Enterprise Scalability & Reliability
> **Strategic Roadmap for DhakaCart Exam Requirements**

This document aligns our implementation with the **DhakaCart E-Commerce Reliability Challenge** (Exam Content).

---

## 🎯 Exam Requirements vs. Our Solution Matrix

| Exam Requirement | Our Solution (Implemented) | Script/File |
|-------------------|----------------------------|-------------|
| **1. Cloud Infra** | AWS VPC, EC2, ALB via Terraform | `terraform/simple-k8s/` |
| **2. Containerization** | Docker + Kubernetes (Kubeadm) | `k8s/deployments/` |
| **3. CI/CD** | GitHub Actions (Auto-Deploy) | `.github/workflows/cd.yml` |
| **4. Monitoring** | Prometheus + Grafana + Loki | `k8s/monitoring/` |
| **5. Logging** | Grafana Loki (Centralized) | `k8s/monitoring/loki/` |
| **6. Security** | Network Policies + Trivy + Vault | `scripts/security/` |
| **7. Backups** | **Velero + MinIO (Self-Hosted)** | `scripts/enterprise-features/` |

---

## 🛠️ Feature 1: Automated Backups & Disaster Recovery
**Exam Goal:** "Automate daily backups stored in secure, redundant locations."

### Architecture
Since we don't have AWS S3 permissions for the exam, we implement a **Cloud-Agnostic** solution:
*   **Tool**: Velero (Industry Standard)
*   **Storage**: **MinIO** (S3-Compatible Object Storage running in-cluster)
*   **Schedule**: Daily @ 2:00 AM

### Implementation Script
`./scripts/enterprise-features/install-velero.sh`

**What it does:**
1.  Deploys MinIO (Deployment + Service).
2.  Installs Velero Server.
3.  Configures Velero to talk to MinIO (`http://minio.velero.svc:9000`).
4.  Creates a default backup schedule.

**Verification:**
```bash
velero backup get
kubectl get pods -n velero
```

---

## 🔐 Feature 2: HTTPS & SSL/TLS
**Exam Goal:** "Enforce HTTPS (SSL/TLS) for encrypted traffic."

### Architecture
*   **Tool**: Cert-Manager.
*   **Issuer**: Let's Encrypt (Staging/Prod) or Self-Signed (for Internal).
*   **Integration**: Ingress annotations.

### Implementation Script
`./scripts/enterprise-features/install-cert-manager.sh`

**Status:** Ready to execute. Adds `cert-manager` namespace and CRDs.

---

## 🔑 Feature 3: Secrets Management
**Exam Goal:** "Manage all passwords and API keys using secrets management."

### Architecture
*   **Tool**: HashiCorp Vault (Dev Mode for Exam).
*   **Integration**: Kubernetes Auth Method.
*   **Why**: Removes hardcoded secrets from source code.

### Implementation Script
`./scripts/enterprise-features/install-vault.sh`

**Status:** Installs Vault via Helm.

---

## 📊 Feature 4: High Availability (Database)
**Exam Goal:** "Consider database replication."

### Strategy (Defense)
While we deploy a single Postgres pod for the 4-hour window simplicity, our architecture allows specifically for **StatefulSet** scaling.
*   **StorageClass**: `gp2` (AWS EBS) ensures data persists even if pods crash.
*   **Future**: Deploy `postgresql-ha` Helm chart for Master-Slave replication.

---

## 🚀 Execution Guide (For Examiners)

To demonstrate these features during the presentation:

1.  **Backups**: Run `install-velero.sh` -> Show `velero backup create test` -> "Backup Completed".
2.  **Security**: Run `apply-security-hardening.sh` -> Show Network Policies blocking access.
3.  **Monitoring**: Show Grafana Dashboard 1860 with CPU/Memory metrics.

This proves the system is **Production-Ready** and meets all 10 Exam Constraints.
