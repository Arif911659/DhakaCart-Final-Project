# 🔐 DhakaCart Security Guide

This directory contains the security configuration, policies, and scanning tools for the DhakaCart application.

## � Directory Structure

```
security/
├── network-policies/          # 🛡️ ZERO-TRUST RULES
│   ├── frontend-policy.yaml   # Limits frontend to only talk to backend
│   ├── backend-policy.yaml    # Limits backend to only talk to DB/Redis
│   └── database-policy.yaml   # Locks DB to only accept internal traffic
│
├── scanning/                  # � VULNERABILITY SCANNERS
│   ├── trivy-scan.sh          # Scans Docker images for CVEs
│   └── dependency-check.sh    # Audits NPM dependencies
│
└── ssl/                       # 🔒 ENCRYPTION
    └── certbot-setup.sh       # Let's Encrypt automation
```

---

## � Security Workflow: How to Apply & Verify

### 1. **Apply Full Security Hardening (Recommended)**
Instead of running these files manually, use the master script that automates everything (Sync -> Apply -> Scan).

*   **Command**:
    ```bash
    ../scripts/security/apply-security-hardening.sh
    ```
*   **What it does**:
    1.  Syncs latest policies from `security/network-policies/` to Master Node.
    2.  Applies Network Policies to the `dhakacart` namespace.
    3.  Runs `trivy-scan.sh` to check for container vulnerabilities.
    4.  Verifies network isolation (tests if DB can reach Google - it should fail).

### 2. **Edit/Update Network Policies**
If you need to open a new port or change access rules:

1.  Edit the files in `security/network-policies/`.
2.  Commit your changes.
3.  Re-run `apply-security-hardening.sh` to deploy the changes.

> **Note**: Do not edit files directly on the Master Node; they will be overwritten by the sync script.

### 3. **Run Manual Vulnerability Scans**
If you only want to check the code/images without deploying:

```bash
cd security/scanning
./trivy-scan.sh
```

---

## 🛡️ Network Policy Architecture

We use a **Zero-Trust** model. By default, pods cannot talk to each other unless explicitly allowed.

| Policy | Ingress (Incoming) | Egress (Outgoing) |
|--------|-------------------|-------------------|
| **Frontend** | Public Internet (via LB) | Backend API (Port 5000) |
| **Backend** | Frontend Pods | DB (5432), Redis (6379) |
| **Database** | Backend Pods | **Blocked** (No Internet) |

---

## � Troubleshooting Security Issues

### Issue: "Connection Refused" between Pods
*   **Cause**: Network Policy might be too strict.
*   **Fix**: Check `backend-policy.yaml`. Ensure the `matchLabels` correctly match the pods.
    ```bash
    kubectl get networkpolicies -n dhakacart
    kubectl describe networkpolicy backend-policy -n dhakacart
    ```

### Issue: "Trivy command not found"
*   **Cause**: Trivy is not installed on your machine.
*   **Fix**: The main script attempts to install it, or install manually:
    ```bash
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b ~/.local/bin
    ```

### Issue: "Database won't allow external connection"
*   **Cause**: This is **INTENTIONAL**. The Database Policy blocks external access.
*   **Workaround**: Use `kubectl port-forward` to connect locally.
    ```bash
    kubectl port-forward svc/dhakacart-db-service 5432:5432 -n dhakacart
    ```

---

## ⚠️ Important Notes
*   **Production Readiness**: Always run the hardening script before verifying a deployment for production.
*   **Monitoring**: Check alerting stack in `scripts/monitoring/` if you suspect security rules are blocking metrics scraping.
