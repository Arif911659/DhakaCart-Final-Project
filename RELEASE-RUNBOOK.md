# Manual Release Guide

This guide explains how to manually build, push, and deploy new versions of the DhakaCart application using the `Makefile`.

## Prerequisites
- Docker installed and running
- Docker Hub login (`docker login`)
- `kubectl` configured (for deployment)

## Using the Makefile

The `Makefile` simplifies the process into single commands. Open a terminal in the project root.

### 0. Safety First (Recommended)
Before releasing a new version, ensure you have a recent backup:
```bash
# SSH to Master-1 and run:
velero backup create pre-release-backup --include-namespaces dhakacart
```

### 1. Build Images
Builds the Docker images locally with the version defined in the Makefile (currently `v1.0.4`).
```bash
make build
```

### 2. Push to Docker Hub
Pushes the built images to Docker Hub.
```bash
make push
```

### 3. Deploy to Kubernetes
Updates the running Kubernetes deployments to use the new version `v1.0.4`.
```bash
make deploy
```

### 4. Do it all (Release)
Runs build, push, and deploy in sequence.
```bash
make release
```

## How to Change the Version

To release a new version (e.g., `v1.0.5`):

1. **Edit the `Makefile`**:
   Change line 6:
   ```makefile
   VERSION := v1.0.5
   ```

2. **Run the release command**:
   ```bash
   make release
   ```

## Troubleshooting
- **Permission Denied**: Run with `sudo` if your user is not in the docker group: `sudo make build`.
- **Login Failed**: Run `docker login` and enter your credentials.
