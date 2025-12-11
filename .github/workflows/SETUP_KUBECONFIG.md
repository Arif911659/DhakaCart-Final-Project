# 🔑 KUBECONFIG Setup Guide

This guide explains how to get your Kubernetes Cluster configuration and add it to GitHub Secrets so that the CD pipeline can deploy your application.

## Step 1: Get the Kubeconfig

Since you are using a custom Terraform setup, your Kubeconfig file is located inside your **Master Node**. We have created a helper script to get it for you easily.

1. Open your terminal in the project root.
2. Run the fetch script:
   ```bash
   ./scripts/fetch-kubeconfig.sh
   ```

3. The script will:
   - Connect to your Bastion host.
   - Jump to Master-1.
   - Read the configuration file (`admin.conf`).
   - Show the content on your screen AND save it to a file named `kubeconfig_fetched`.

## Step 2: Add Secrets to GitHub

The script will output 4 values. You need to add them to your GitHub Repository settings.

Go to **Settings** > **Secrets and variables** > **Actions**.

### 1. Add Secrets (Under 'Secrets' tab)
- **Name:** `KUBECONFIG`
  - **Value:** (Copy from script output)
- **Name:** `SSH_PRIVATE_KEY`
  - **Value:** (Copy from script output)

### 2. Add Variables (Under 'Variables' tab)
- **Name:** `BASTION_IP`
  - **Value:** (Copy from script output)
- **Name:** `MASTER_PRIVATE_IP`
  - **Value:** (Copy from script output)

## Step 3: Trigger Deployment
Once added, push your code or re-run the failed job. The workflow will now use the Bastion host to tunnel into your private cluster.

> **Note:** This `KUBECONFIG` gives full admin access to your cluster. Keep it safe and never share it publicly.
