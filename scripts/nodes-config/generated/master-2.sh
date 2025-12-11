#!/bin/bash
# Master-2 (HA Control Plane) Configuration Guide
# Auto-generated from template - DO NOT EDIT MANUALLY
# IPs and values will be replaced automatically
# NOTE: You need to get the join command from Master-1 after it initializes

set -e

# System update
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Swap disable
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Kernel modules load
sudo modprobe overlay
sudo modprobe br_netfilter

# Kernel parameters & apply
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system

# Containerd install & Cgroup fix
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
# Cgroup fix
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Kubernetes tools install (v1.29)
sudo rm /etc/apt/sources.list.d/kubernetes.list 2>/dev/null
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Join Master-2 to existing Control Plane
# IMPORTANT: Replace the token and certificate-key with values from Master-1
# Get these values by running on Master-1:
#   kubeadm token create --print-join-command
#   kubeadm init phase upload-certs --upload-certs

MASTER_1_IP="10.0.10.10"
echo "Joining Master-2 to cluster at $MASTER_1_IP:6443..."

echo ""
echo "⚠️  IMPORTANT: You need to get the join command from Master-1!"
echo "   On Master-1, run: kubeadm token create --print-join-command"
echo ""
echo "   Then run the command shown here with --control-plane and --certificate-key flags"
echo ""
read -p "Press Enter after you have the join command, or Ctrl+C to cancel..."

# Example join command (replace with actual values from Master-1):
# sudo kubeadm join ${MASTER_1_IP}:6443 \
#   --token <TOKEN> \
#   --discovery-token-ca-cert-hash sha256:<HASH> \
#   --control-plane \
#   --certificate-key <CERT_KEY>

echo ""
echo "After joining, configure kubectl:"
echo "  mkdir -p \$HOME/.kube"
echo "  sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo "  sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo ""

