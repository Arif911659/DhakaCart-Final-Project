# Changelog

All notable changes to the DhakaCart project will be documented in this file.

## [Suggested Renames for Professionalism]

To make the project structure look more enterprise-grade and less "Exam/Lab" like, here are the suggested renames:

### 📂 Directories
| Current Path | Suggested Path | Impact (Files to Change) |
|--------------|----------------|--------------------------|
| `terraform/simple-k8s/` | `terraform/aws-infra/` | `deploy-4-hour-window.sh`, `scripts/nodes-config/extract-terraform-outputs.sh`, `scripts/k8s-deployment/update-and-deploy.sh`, `scripts/internal/hostname/*`, `scripts/monitoring/*`, `scripts/post-terraform-setup.sh`, `scripts/fetch-kubeconfig.sh`, `README.md`, `PROJECT-STRUCTURE.md` |
| `scripts/nodes-config/` | `scripts/provisioning/` | `deploy-4-hour-window.sh`, `scripts/nodes-config/automate-node-config.sh`, `extract-terraform-outputs.sh`, `README.md` |
| `scripts/internal/` | `scripts/utils/` | `deploy-4-hour-window.sh`, `scripts/internal/hostname/*`, `README.md`, `PROJECT-STRUCTURE.md`, `scripts/SCRIPTS-GUIDE.md` |

### 📄 Files
| Current Name | Suggested Name | Impact (Files to Change) |
|--------------|----------------|--------------------------|
| `deploy-4-hour-window.sh` | `deploy-full-stack.sh` | `README.md`, `PROJECT-STRUCTURE.md`, `DEPLOYMENT-GUIDE.md`, `QUICK-REFERENCE.md`, `PLAN.txt` |
| `4-HOUR-DEPLOYMENT.md` | `FULL-DEPLOYMENT-GUIDE.md` | `README.md`, `PROJECT-STRUCTURE.md`, `DEPLOYMENT-GUIDE.md`, `docs/SECURITY-AND-TESTING-GUIDE.md`, `QUICK-REFERENCE.md` |
| `MANUAL_RELEASE_GUIDE.md` | `RELEASE-RUNBOOK.md` | `README.md`, `PROJECT-STRUCTURE.md` |
| `load-infrastructure-config.sh` | `load-env.sh` | **Many Scripts**: `deploy-4-hour-window.sh`, `monitoring/*`, `testing/load-tests/run-load-test.sh`, `security/apply-security-hardening.sh`, `scripts/k8s-deployment/sync-k8s-to-master1.sh`, `scripts/monitoring/deploy-alerting-stack.sh`, `README.md`, `PROJECT-STRUCTURE.md` |
| `generate-scripts.sh` | `generate-node-scripts.sh` | `scripts/nodes-config/automate-node-config.sh`, `scripts/nodes-config/generate-scripts.sh` (self) |

### ☸️ Kubernetes
| Current Name | Suggested Name | Impact (Files to Change) |
|--------------|----------------|--------------------------|
| `k8s/deploy-prod.sh` | `k8s/apply-manifests.sh` | `deploy-4-hour-window.sh`, `scripts/SCRIPTS-GUIDE.md`, `k8s/README_*.md`, `README.md`, `PROJECT-STRUCTURE.md` |
| `deploy-prod.sh` (inside k8s) | `main-deployment.sh` | `deploy-4-hour-window.sh` |

---
