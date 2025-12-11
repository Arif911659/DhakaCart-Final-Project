# 🔄 Dynamic Load Balancer URL Setup - LAB Practice Guide

**Problem**: Load Balancer URL changes every time in LAB practice  
**Solution**: Dynamic update scripts and best practices  
**Date**: 2024-11-30

---

## 📋 Table of Contents

1. [Problem Statement](#problem-statement)
2. [Solution Overview](#solution-overview)
3. [Method 1: Quick Sync & Update](#method-1-quick-sync--update)
4. [Method 2: Automated Script](#method-2-automated-script)
5. [Method 3: Manual Update](#method-3-manual-update)
6. [Best Practices](#best-practices)

---

## Problem Statement

In LAB practice:
- ✅ Load Balancer URL changes every time: `dhakacart-k8s-alb-XXXXX.ap-southeast-1.elb.amazonaws.com`
- ❌ ConfigMap has hardcoded URL: `REACT_APP_API_URL: "http://dhakacart-k8s-alb-1098869932.../api"`
- ❌ Every deployment requires manual URL update
- ❌ Files need to be copied to Master-1 every time

---

## Solution Overview

### Created Scripts:

1. **`sync-k8s-to-master1.sh`** - Copy k8s files to Master-1
2. **`update-configmap-with-lb.sh`** - Update ConfigMap with current Load Balancer URL
3. **`update-and-deploy.sh`** - Complete automation (copy + update + deploy)

---

## Method 1: Quick Sync & Update (Recommended for LAB)

### Step 1: Copy Files to Master-1

**Your Computer এ:**

```bash
cd /home/arif/DhakaCart-03
./sync-k8s-to-master1.sh
```

**What it does:**
- Copies `k8s/` folder to Master-1
- Files are available at: `~/k8s/` on Master-1

---

### Step 2: Get Current Load Balancer URL

**AWS Console এ:**
1. EC2 → Load Balancers
2. Find `dhakacart-k8s-alb-XXXXX`
3. Copy DNS name

**Or Master-1 এ:**

```bash
# SSH to Master-1
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@13.229.110.212
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@10.0.10.253

# Get Load Balancer URL (if ingress exists)
kubectl get ingress -A -o jsonpath="{range .items[*]}{.status.loadBalancer.ingress[0].hostname}{'\n'}{end}"
```

---

### Step 3: Update ConfigMap with Load Balancer URL

**Your Computer এ:**

```bash
# Method A: Auto-detect (tries to get from Master-1)
./update-configmap-with-lb.sh

# Method B: Manual (you provide URL)
./update-configmap-with-lb.sh dhakacart-k8s-alb-123456789.ap-southeast-1.elb.amazonaws.com
```

**What it does:**
- Updates ConfigMap with new Load Balancer URL
- Restarts frontend pods to pick up new config

---

### Step 4: Apply Changes on Master-1

**Master-1 এ SSH করুন:**

```bash
# Apply all changes
kubectl apply -f ~/k8s/namespace.yaml
kubectl apply -f ~/k8s/secrets/
kubectl apply -f ~/k8s/configmaps/
kubectl apply -f ~/k8s/volumes/
kubectl apply -f ~/k8s/services/
kubectl apply -f ~/k8s/deployments/

# Verify
kubectl get pods -n dhakacart
kubectl get svc -n dhakacart
```

---

## Method 2: Automated Script (All-in-One)

**Your Computer এ:**

```bash
cd /home/arif/DhakaCart-03
./update-and-deploy.sh
```

**What it does:**
1. ✅ Copies k8s files to Master-1
2. ✅ Tries to auto-detect Load Balancer URL
3. ✅ Updates ConfigMap with Load Balancer URL
4. ✅ Applies all changes
5. ✅ Restarts frontend pods

**If auto-detection fails:**
- Script will ask you to enter Load Balancer URL manually

---

## Method 3: Manual Update (Step-by-Step)

### Step 1: Copy Files

```bash
# Your Computer
cd /home/arif/DhakaCart-03
./sync-k8s-to-master1.sh
```

---

### Step 2: SSH to Master-1

```bash
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@13.229.110.212
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@10.0.10.253
```

---

### Step 3: Get Load Balancer URL

**AWS Console এ Load Balancer DNS name note করুন:**
- Example: `dhakacart-k8s-alb-123456789.ap-southeast-1.elb.amazonaws.com`

---

### Step 4: Update ConfigMap on Master-1

**Master-1 এ:**

```bash
# Get current ConfigMap
kubectl get configmap dhakacart-config -n dhakacart -o yaml > /tmp/dhakacart-config.yaml

# Edit ConfigMap (replace YOUR_LB_URL with actual URL)
sed -i 's|REACT_APP_API_URL:.*|REACT_APP_API_URL: "http://YOUR_LB_URL/api"|' /tmp/dhakacart-config.yaml

# Replace YOUR_LB_URL with actual URL
nano /tmp/dhakacart-config.yaml
# Find: YOUR_LB_URL
# Replace with: dhakacart-k8s-alb-123456789.ap-southeast-1.elb.amazonaws.com
# Save: Ctrl+X, Y, Enter

# Apply updated ConfigMap
kubectl apply -f /tmp/dhakacart-config.yaml

# Restart frontend
kubectl rollout restart deployment dhakacart-frontend -n dhakacart
```

---

### Step 5: Apply Changes

```bash
# Apply all k8s files
kubectl apply -f ~/k8s/namespace.yaml
kubectl apply -f ~/k8s/secrets/
kubectl apply -f ~/k8s/configmaps/
kubectl apply -f ~/k8s/volumes/
kubectl apply -f ~/k8s/services/
kubectl apply -f ~/k8s/deployments/

# Verify
kubectl get pods -n dhakacart
```

---

## Best Practices

### 1. Always Use Scripts

**Before Deployment:**
```bash
# Copy files
./sync-k8s-to-master1.sh

# Update Load Balancer URL
./update-configmap-with-lb.sh YOUR_LB_URL
```

---

### 2. Store Load Balancer URL

**Create a file to store current URL:**

```bash
# Create .lb-url file
echo "dhakacart-k8s-alb-123456789.ap-southeast-1.elb.amazonaws.com" > .lb-url

# Use it in script
LB_URL=$(cat .lb-url)
./update-configmap-with-lb.sh "$LB_URL"
```

---

### 3. Quick Reference Commands

**Your Computer:**
```bash
# 1. Sync files
./sync-k8s-to-master1.sh

# 2. Update ConfigMap (with URL)
./update-configmap-with-lb.sh dhakacart-k8s-alb-XXXXX.ap-southeast-1.elb.amazonaws.com

# 3. Or use auto-detect
./update-configmap-with-lb.sh
```

**Master-1:**
```bash
# Apply changes
kubectl apply -f ~/k8s/...

# Check status
kubectl get pods -n dhakacart
kubectl get svc -n dhakacart

# Check ConfigMap
kubectl get configmap dhakacart-config -n dhakacart -o yaml | grep REACT_APP_API_URL
```

---

## Scripts Summary

| Script | Purpose | Usage |
|--------|---------|-------|
| `sync-k8s-to-master1.sh` | Copy k8s files to Master-1 | `./sync-k8s-to-master1.sh` |
| `update-configmap-with-lb.sh` | Update ConfigMap with LB URL | `./update-configmap-with-lb.sh [URL]` |
| `update-and-deploy.sh` | All-in-one automation | `./update-and-deploy.sh` |

---

## Troubleshooting

### Issue: Script Fails to Auto-Detect LB URL

**Solution:**
```bash
# Get URL manually from AWS Console or Master-1
# Then run:
./update-configmap-with-lb.sh YOUR_LB_URL
```

---

### Issue: ConfigMap Not Updating

**Solution:**
```bash
# Master-1 এ manually check:
kubectl get configmap dhakacart-config -n dhakacart -o yaml

# If wrong, update manually:
kubectl edit configmap dhakacart-config -n dhakacart
```

---

### Issue: Frontend Still Using Old URL

**Solution:**
```bash
# Restart frontend pods
kubectl rollout restart deployment dhakacart-frontend -n dhakacart

# Wait 1-2 minutes
kubectl get pods -n dhakacart -l app=dhakacart-frontend
```

---

## Workflow for LAB Practice

### Every Time You Deploy:

```bash
# 1. Update files locally (if needed)

# 2. Sync to Master-1
./sync-k8s-to-master1.sh

# 3. Get Load Balancer URL (from AWS Console or previous deployment)

# 4. Update ConfigMap
./update-configmap-with-lb.sh YOUR_NEW_LB_URL

# 5. SSH to Master-1 and apply
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@13.229.110.212
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@10.0.10.253
kubectl apply -f ~/k8s/...
```

---

## Alternative: Use Template File

For more advanced users, you can use the template file:

```bash
# Use template
cp k8s/configmaps/app-config.yaml.template k8s/configmaps/app-config.yaml

# Replace placeholder
sed -i "s|LOAD_BALANCER_URL|$LB_URL|g" k8s/configmaps/app-config.yaml

# Sync and deploy
./sync-k8s-to-master1.sh
```

---

**Last Updated**: 2024-11-30  
**Status**: Ready to Use ✅

