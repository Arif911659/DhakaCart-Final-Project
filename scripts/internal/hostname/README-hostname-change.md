# Hostname Change Automation Scripts

## Overview

এই directory তে দুইটি script আছে hostname change করার জন্য:

1. **`change-hostname.sh`** - Local hostname change (একটি machine এ সরাসরি run করার জন্য)
2. **`change-hostname-via-bastion.sh`** - Remote hostname change via Bastion (Kubernetes cluster এর সব node এ)

## Scripts

### 1. change-hostname.sh (Local)

একটি single machine এ hostname change করার জন্য।

**Usage:**
```bash
# Interactive mode
./change-hostname.sh

# Direct command
./change-hostname.sh Master-1

# Without confirmation (for automation)
./change-hostname.sh Worker-2 --no-confirm
```

**Available Hostnames:**
- Bastion
- Master-1, Master-2
- Worker-1, Worker-2, Worker-3

---

### 2. change-hostname-via-bastion.sh (Remote via Bastion)

Bastion থেকে সব Master এবং Worker nodes এ SSH করে hostname change করে।

**Prerequisites:**
- Terraform infrastructure deployed
- SSH key available at `terraform/simple-k8s/dhakacart-k8s-key.pem`
- `jq` installed: `sudo apt-get install jq`
- Bastion এ SSH key copied: `~/.ssh/dhakacart-k8s-key.pem`

**Usage:**

```bash
# Interactive mode (recommended)
./change-hostname-via-bastion.sh

# Change all nodes
./change-hostname-via-bastion.sh --all

# Change only Bastion
./change-hostname-via-bastion.sh --bastion

# Change all Masters
./change-hostname-via-bastion.sh --masters

# Change all Workers
./change-hostname-via-bastion.sh --workers

# Change specific node
./change-hostname-via-bastion.sh --node Master-1
./change-hostname-via-bastion.sh --node Worker-2

# Dry run (preview without making changes)
./change-hostname-via-bastion.sh --dry-run
./change-hostname-via-bastion.sh --all --dry-run
```

**How it works:**
1. Terraform output থেকে Bastion এবং node IPs collect করে
2. Bastion এ SSH করে
3. Bastion থেকে প্রতিটি Master/Worker node এ SSH করে
4. প্রতিটি node এ hostname change করে:
   - `hostnamectl set-hostname <name>`
   - `/etc/hosts` update করে
   - Backup নেয় পুরানো configuration এর

**Interactive Mode Example:**
```
Available nodes:
  0. All nodes
  1. Bastion
  2. Master-1 (10.0.1.10)
  3. Master-2 (10.0.1.11)
  4. Worker-1 (10.0.2.10)
  5. Worker-2 (10.0.2.11)
  6. Worker-3 (10.0.2.12)

Select node(s) to change hostname (0-6): 2
```

## Setup Instructions

### First Time Setup

1. **Install jq** (if not installed):
   ```bash
   sudo apt-get update
   sudo apt-get install jq -y
   ```

2. **Copy SSH key to Bastion** (if not already done):
   ```bash
   cd /home/arif/DhakaCart-03-test/terraform/simple-k8s
   scp -i dhakacart-k8s-key.pem dhakacart-k8s-key.pem ubuntu@<BASTION_IP>:~/.ssh/
   ```

3. **Set proper permissions on Bastion**:
   ```bash
   ssh -i dhakacart-k8s-key.pem ubuntu@<BASTION_IP>
   chmod 600 ~/.ssh/dhakacart-k8s-key.pem
   ```

### Running the Script

**Recommended workflow:**

1. **Test with dry-run first:**
   ```bash
   cd /home/arif/DhakaCart-03-test/scripts
   ./change-hostname-via-bastion.sh --dry-run
   ```

2. **Run in interactive mode:**
   ```bash
   ./change-hostname-via-bastion.sh
   ```

3. **Or change all at once:**
   ```bash
   ./change-hostname-via-bastion.sh --all
   ```

## Verification

After running the script, verify hostnames:

```bash
# SSH to Bastion
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@<BASTION_IP>

# From Bastion, check each node
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@<MASTER_IP> hostname
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@<WORKER_IP> hostname
```

## Troubleshooting

### Error: "jq command not found"
```bash
sudo apt-get install jq -y
```

### Error: "Could not retrieve Bastion IP"
```bash
cd /home/arif/DhakaCart-03-test/terraform/simple-k8s
terraform output bastion_public_ip
```

### Error: "Permission denied (publickey)"
- Ensure SSH key is copied to Bastion
- Check permissions: `chmod 600 ~/.ssh/dhakacart-k8s-key.pem`
- Verify key path in script matches actual location

### Hostname doesn't persist after reboot
- The script uses `hostnamectl` which should persist
- Check `/etc/hostname` and `/etc/hosts` files
- Verify cloud-init is not overwriting hostname

## Notes

- Script automatically creates backups of `/etc/hosts` before making changes
- Backup format: `/etc/hosts.backup.YYYYMMDD_HHMMSS`
- Hostname changes take effect immediately (no reboot required)
- Terminal prompt may not update until you reconnect
