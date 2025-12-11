# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-12-12

### Added
- **Enterprise Features**: Standardized scripts for backups (Velero), secrets (Vault), and HTTPS (Cert-Manager).
- **Deployment Guide**: Comprehensive `FULL-DEPLOYMENT-GUIDE.md` replacing the ad-hoc 4-hour window guide.
- **Runbook**: Added `RELEASE-RUNBOOK.md` for manual release procedures.

### Refactoring Map (Old Name ➔ New Name)
> **Note**: All internal references to these paths have been updated to ensure the system is 100% error-free.

| Type | Old Name | New Name |
|------|----------|----------|
| **Directory** | `terraform/simple-k8s/` | `terraform/aws-infra/` |
| **Directory** | `scripts/nodes-config/` | `scripts/provisioning/` |
| **Directory** | `scripts/internal/` | `scripts/utils/` |
| **File** | `scripts/deploy-4-hour-window.sh` | `./deploy-full-stack.sh` (Moved to Root) |
| **File** | `k8s/deploy-prod.sh` | `k8s/apply-manifests.sh` |
| **File** | `4-HOUR-DEPLOYMENT.md` | `FULL-DEPLOYMENT-GUIDE.md` |
| **File** | `MANUAL_RELEASE_GUIDE.md` | `RELEASE-RUNBOOK.md` |
| **File** | `scripts/load-infrastructure-config.sh` | `scripts/load-env.sh` |

### Changed
- **Project Structure**: Refactored directory layout for better maintainability (Enterprise Standard).
- **Scripts**: Updated all logic to use the new `aws-infra` and `provisioning` paths.
- **Documentation**: Updated `README.md` and `PROJECT-STRUCTURE.md` to reflect the professionalized architecture.

### Removed
- Removed legacy "Exam/Lab" references from documentation to reflect Production readiness.

## [1.0.3] - 2025-12-10

### Added
- Smart Resume capability in deployment scripts.
- Automated Database Seeding.

### Fixed
- Fixed module connection issues in Terraform.
- Resolved 404 errors during frontend routing.
