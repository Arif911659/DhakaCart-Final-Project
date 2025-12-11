# 🏗️ Project Structure & Architecture
> **DhakaCart E-Commerce Infrastructure**

This document provides a comprehensive overview of the file structure, describing the purpose of every major component.

## 📂 Directory Tree

```
DhakaCart-03-test/
├── 📂 .github/                         # CI/CD & GitHub Configuration
│   └── 📂 workflows/
│       ├── cd.yml                      # Continuous Deployment (Tunneling)
│       ├── ci.yml                      # Continuous Integration (Tests)
│       ├── docker-build.yml            # Docker Image Build
│       └── security-scan.yml           # Trivy Vulnerability Scanner
│
├── 📂 k8s/                             # Kubernetes Manifests (The "State")
│   ├── 📂 configmaps/                  # Configuration Injection
│   │   └── app-config.yaml             # Environment Variables (DB Host, API URL)
│   ├── 📂 deployments/                 # Application Workloads
│   │   ├── backend.yaml                # NodeJS Backend
│   │   ├── frontend.yaml               # React Frontend
│   │   ├── postgres.yaml               # Database
│   │   └── redis.yaml                  # Caching
│   ├── 📂 enterprise-features/         # [Phase 2] Enterprise Capabilities
│   │   ├── 📂 cert-manager/            # HTTPS/SSL
│   │   ├── 📂 vault/                   # Secrets Management
│   │   └── 📂 velero/                  # Backup Schedules
│   ├── 📂 ingress/                     # Traffic Routing
│   │   └── ingress.yaml                # ALB Ingress Rules
│   ├── 📂 monitoring/                  # Observability Stack
│   │   ├── 📂 alertmanager/            # Alert Routing
│   │   ├── 📂 grafana/                 # Dashboards
│   │   ├── 📂 loki/                    # Log Aggregation
│   │   ├── 📂 prometheus/              # Metrics Collection
│   │   ├── 📂 promtail/                # Log Shipping Agent
│   │   ├── 📂 node-exporter/           # Node Metrics
│   │   └── namespace.yaml              # Monitoring Namespace
│   ├── 📂 network-policies/            # Zero-Trust Security
│   │   ├── backend-policy.yaml
│   │   ├── db-policy.yaml
│   │   └── frontend-policy.yaml
│   ├── 📂 secrets/                     # Sensitive Data (Git-Encrypted/Base64)
│   │   └── db-secrets.yaml
│   ├── 📂 services/                    # Internal Networking
│   │   ├── backend-service.yaml
│   │   ├── db-service.yaml
│   │   ├── frontend-service.yaml
│   │   └── redis-service.yaml
│   ├── deploy-prod.sh                  # 🚀 Operations: Apply all manifests
│   └── hpa.yaml                        # Horizontal Pod Autoscaling
│
├── 📂 scripts/                         # Automation & Operations (The "Logic")
│   ├── 📂 database/                    # DB Maintenance
│   │   ├── diagnose-db-products-issue.sh
│   │   └── seed-database.sh
│   ├── 📂 enterprise-features/         # [Phase 2] Installers
│   │   ├── install-cert-manager.sh
│   │   ├── install-vault.sh
│   │   ├── install-velero.sh
│   │   └── minio-manifests.yaml        # S3-compatible backend for Velero
│   ├── 📂 internal/                    # Internal Helpers
│   │   └── 📂 hostname/                # Node Naming
│   ├── 📂 k8s-deployment/              # Deployment Helpers
│   │   ├── copy-k8s-to-master1.sh
│   │   ├── sync-k8s-to-master1.sh
│   │   └── update-and-deploy.sh
│   ├── 📂 monitoring/                  # Monitoring Helpers
│   │   ├── check-prometheus-metrics.sh
│   │   ├── deploy-alerting-stack.sh
│   │   ├── fix-grafana-config.sh
│   │   └── setup-grafana-alb.sh
│   ├── 📂 nodes-config/                # Cluster Bootstrapping
│   │   ├── extract-terraform-outputs.sh
│   │   ├── generate-scripts.sh         # Generates Kubeadm commands
│   │   └── upload-to-bastion.sh
│   ├── 📂 security/                    # Security Automation
│   │   └── apply-security-hardening.sh
│   ├── deploy-4-hour-window.sh         # 🚀 MASTER SCRIPT: 0 to Production
│   ├── .deploy_state                   # 🔄 State tracking for Resume Capability
│   ├── fetch-kubeconfig.sh             # CI/CD Helper
│   └── load-infrastructure-config.sh   # State Loader
│
├── 📂 terraform/                       # Infrastructure as Code (AWS)
│   └── 📂 simple-k8s/
│       ├── main.tf                     # Core Infrastructure
│       ├── outputs.tf                  # IP/DNS Exports
│       ├── variables.tf                # Region/Instance Config
│       └── register-workers-to-alb.sh  # ALB Target Registration
│
├── 📂 testing/                         # QA & Verification
│   └── 📂 load-tests/
│       ├── k6-script.js                # Load Test Scenario
│       └── run-load-test.sh            # Load Test Runner
│
├── 📂 backend/                         # Application Source (Node.js)
├── 📂 frontend/                        # Application Source (React)
│
├── 📄 4-HOUR-DEPLOYMENT.md             # ⏱️ Quick Deployment Runbook
├── 📄 DEPLOYMENT-GUIDE.md              # 📚 Full Detailed Guide

├── 📄 PHASE-2-TECH-SPEC.md             # � Enterprise Features Guide
├── 📄 PROJECT-STRUCTURE.md             # 🗺️ This File
├── 📄 QUICK-REFERENCE.md               # ⚡ Cheat Sheet
└── 📄 README.md                        # 🏠 Project Homepage
```

## 🧩 Component Descriptions

### 1. Automation Core (`scripts/`)
*   **`deploy-4-hour-window.sh`**: The orchestrator. It calls Terraform, configures nodes, deploys K8s, and **auto-seeds** the DB. Features **Smart Resume** to recover from interruptions.
*   **`enterprise-features/`**: Scripts to install Phase 2 tools (Backup, Security) *after* the main deployment.
*   **`nodes-config/`**: Handles the complex logic of `kubeadm init` and `kubeadm join` ensuring nodes connect correctly.

### 2. Infrastructure (`terraform/`)
*   **`simple-k8s/`**: A simplified, flat Terraform structure designed for speed and reliability in the exam.
*   **Static IPs**: Hardcoded in `main.tf` to ensure predictable internal networking (a key "Lean" feature).

### 3. Orchestration (`k8s/`)
*   **`deploy-prod.sh`**: Located inside `k8s/`, this script applies the YAML files in the correct order (ConfigMaps -> Secrets -> Services -> Deployments).
*   **`monitoring/`**: A complete observability stack (Prometheus, Grafana, Loki) defined as code.

### 4. CI/CD (`.github/`)
*   **`cd.yml`**: Defines the production pipeline. It builds Docker images and uses an SSH Tunnel to deploy to the private K8s cluster via the Bastion host.
