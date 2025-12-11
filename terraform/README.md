# 🏗️ Infrastructure as Code (Terraform)

**এটি কি? (What is this?)**
এটি AWS ক্লাউডে আমাদের ইনফ্রাস্ট্রাকচার (Server, Network, Storage) অটোমেটিক তৈরি করার কোড।

**কেন এটি দরকার? (Why do we need this?)**
- ম্যানুয়ালি সার্ভার সেটআপ করার ঝামেলা নেই।
- **এক কমান্ডে** VPC, Subnet, Security Group, EC2 এবং Load Balancer তৈরি হয়ে যায়।
- ভুল হওয়ার সম্ভাবনা নেই (Zero Human Error)।

---

## ⚙️ কি কি তৈরি হয়? (Resources Created)

| Resource | Details | Purpose | Cost Est. (Approx) |
|----------|---------|---------|--------------------|
| **VPC** | 10.0.0.0/16 | Isolated Network | Free |
| **Bastion** | t3.small (10.0.1.10) | Secure Entry Point | ~$0.0208/hr |
| **Master Nodes** | 2x t3.medium | Kubernetes Control Plane | ~$0.0832/hr |
| **Worker Nodes** | 3x t3.medium | Application Workload | ~$0.1248/hr |
| **ALB** | Application Load Balancer | Traffic Distribution | ~$0.0225/hr |

**Total Estimated Cost:** ~$7.20/day (approx $0.30/hour)

---

## 📂 ফাইল স্ট্রাকচার (Folder Structure)

```
terraform/simple-k8s/
├── main.tf             # মেইন ইনফ্রাস্ট্রাকচার কোড
├── variables.tf        # কনফিগারেশন ভেরিয়েবল (Region, AMI)
├── outputs.tf          # IP এবং DNS আউটপুট
└── alb-backend-config.tf # লোড ব্যালেন্সার কনফিগারেশন
```

---

## 🚀 কিভাবে রান করবেন? (How to Run)

```bash
cd terraform/simple-k8s
terraform init
terraform apply --auto-approve
```

---

## 🌟 Advanced Options

### HA Cluster (High Availability)
For requirements with 3 masters and multi-AZ support, see `k8s-ha-cluster/README.md`.
- 3 Master Nodes (Etcd HA)
- Internal Load Balancer for API Server
- Multi-AZ deployment
