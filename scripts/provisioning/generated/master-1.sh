#!/bin/bash
# Master-1 (Control Plane) Full Configuration Guide
# Auto-generated from template - DO NOT EDIT MANUALLY
# IPs and values will be replaced automatically

# set -e # Disabled to allow resuming/retrying without full exit on minor errors

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
curl -fSL https://download.docker.com/linux/ubuntu/gpg -o /tmp/docker.gpg
sudo gpg --dearmor --yes -o /usr/share/keyrings/docker-archive-keyring.gpg /tmp/docker.gpg
rm /tmp/docker.gpg
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
sudo mkdir -p /etc/apt/keyrings
curl -fSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key -o /tmp/k8s.key
sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg /tmp/k8s.key
rm /tmp/k8s.key
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Initialize Master-1
MASTER_1_IP="10.0.10.10"
echo "Initializing Kubernetes cluster on Master-1 (IP: $MASTER_1_IP)..."

if [ -f /etc/kubernetes/admin.conf ]; then
    echo "✅ Cluster already initialized. Skipping init..."
else
    sudo kubeadm init \
      --pod-network-cidr=10.244.0.0/16 \
      --control-plane-endpoint "${MASTER_1_IP}:6443" \
      --upload-certs \
      --ignore-preflight-errors=NumCPU
fi

# Configure kubectl for the user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install Flannel CNI
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo ""
echo "✅ Master-1 configuration complete!"
echo ""
echo "📋 Next steps:"
echo "1. Save the kubeadm join command shown above"
echo "2. Use it to join Master-2 and Worker nodes"
echo "3. Check cluster status: kubectl get nodes"
echo ""

