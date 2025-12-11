#!/bin/bash
# Enterprise Feature: Velero Automated Backup (MinIO Backend)
# =========================================================
# 🇧🇩 এই স্ক্রিপ্ট Velero সেটআপ করবে আমাদের ক্লাস্টারের ব্যাকআপ নেয়ার জন্য।
# 🇺🇸 This script setups Velero to backup our cluster resources and volumes.
#
# 🇧🇩 কেন MinIO? AWS S3 তে পারমিশন সমস্যা এড়াতে আমরা ক্লাস্টারের ভেতরেই MinIO ব্যবহার করছি।
# 🇺🇸 Why MinIO? We use self-hosted MinIO to avoid AWS S3 permission issues.
#
# Architecture:
# [Velero] -> [AWS Plugin (S3 API)] -> [MinIO Service (Inside Cluster)]

set -e

# Configuration
CLUSTER_NAME="dhakacart-cluster"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MINIO_MANIFEST="$SCRIPT_DIR/minio-manifests.yaml"

echo -e "\033[0;34m🚀 Starting Velero Setup (with MinIO) for $CLUSTER_NAME...\033[0m"

# 1. Check Tools
# 🇧🇩 Velero CLI টুল না থাকলে ডাউনলোড করা হবে
# 🇺🇸 Check if Velero CLI is installed, download if missing
if ! command -v velero &> /dev/null; then
    echo "⬇️  Velero CLI not found. Downloading..."
    wget https://github.com/vmware-tanzu/velero/releases/download/v1.12.0/velero-v1.12.0-linux-amd64.tar.gz -q
    tar -zxvf velero-v1.12.0-linux-amd64.tar.gz > /dev/null
    sudo mv velero-v1.12.0-linux-amd64/velero /usr/local/bin/
    rm -rf velero-v1.12.0-linux-amd64*
    echo "✅ Velero CLI installed."
fi

# 2. Deploy MinIO Storage
# 🇧🇩 MinIO ডেপ্লয় করা হচ্ছে (যেখানে ব্যাকআপ ফাইল জমা থাকবে)
# 🇺🇸 Deploying MinIO (Where the backup files will be stored)
echo -e "\033[0;33m📦 Deploying MinIO Object Storage...\033[0m"
kubectl apply -f "$MINIO_MANIFEST"

echo "⏳ Waiting for MinIO to verify bucket creation (20s)..."
sleep 20
kubectl wait --for=condition=complete job/minio-setup -n velero --timeout=60s || echo "⚠️  MinIO setup job taking longer than expected..."

# 3. Create Credentials File (MinIO default)
# 🇧🇩 Velero কে MinIO এর পাসওয়ার্ড দেয়া (minioadmin/minioadmin)
# 🇺🇸 Provide MinIO credentials to Velero
cat > credentials-velero <<EOF
[default]
aws_access_key_id=minioadmin
aws_secret_access_key=minioadmin
EOF

# 4. Install Velero Server
# 🇧🇩 Velero সার্ভার ইন্সটল করা যা S3 API দিয়ে MinIO এর সাথে কথা বলবে
# 🇺🇸 Installing Velero server configured to talk to MinIO via S3 API
echo -e "\033[0;33m🛠️  Installing Velero Server...\033[0m"

# Uninstall previous if exists to avoid conflicts
velero uninstall --force --wait > /dev/null 2>&1 || true

velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.8.0 \
    --bucket dhakacart-backups \
    --secret-file ./credentials-velero \
    --use-node-agent \
    --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://minio.velero.svc:9000 \
    --wait

# 5. Cleanup
rm credentials-velero

echo -e "\033[0;32m🎉 Velero Setup Complete!\033[0m"
echo -e "\033[0;32m✅ Storage Provider: MinIO (Self-Hosted)\033[0m"
echo ""
echo "Test Backup:"
echo "  velero backup create test-backup --include-namespaces dhakacart"
echo ""
echo "Monitor:"
echo "  kubectl get pods -n velero"
echo "  MinIO Console: http://<NODE_IP>:31901 (User/Pass: minioadmin)"
