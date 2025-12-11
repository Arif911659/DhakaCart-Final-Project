output "bastion_public_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh -i ${var.cluster_name}-key.pem ubuntu@${aws_instance.bastion.public_ip}"
}

output "master_private_ips" {
  description = "Private IPs of master nodes"
  value       = aws_instance.masters[*].private_ip
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = aws_instance.workers[*].private_ip
}

output "ssh_to_masters" {
  description = "Commands to SSH to masters from bastion"
  value = [
    for i, master in aws_instance.masters : 
    "ssh -i ~/.ssh/${var.cluster_name}-key.pem ubuntu@${master.private_ip}"
  ]
}

output "ssh_to_workers" {
  description = "Commands to SSH to workers from bastion"
  value = [
    for i, worker in aws_instance.workers : 
    "ssh -i ~/.ssh/${var.cluster_name}-key.pem ubuntu@${worker.private_ip}"
  ]
}

output "load_balancer_url" {
  description = "Public URL for DhakaCart application"
  value       = "http://${aws_lb.app.dns_name}"
}

output "load_balancer_dns" {
  description = "Load Balancer DNS name"
  value       = aws_lb.app.dns_name
}

output "frontend_target_group_arn" {
  description = "Frontend Target Group ARN"
  value       = aws_lb_target_group.app.arn
}

output "backend_target_group_arn" {
  description = "Backend Target Group ARN"
  value       = aws_lb_target_group.backend.arn
}

output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT
    =============================================
    Kubernetes Infrastructure Deployed!
    =============================================
    
    📌 PUBLIC ACCESS URL (After K8s setup):
    http://${aws_lb.app.dns_name}
    
    🔑 SSH to Bastion:
    ssh -i ${var.cluster_name}-key.pem ubuntu@${aws_instance.bastion.public_ip}
    
    📋 Copy SSH key to bastion:
    scp -i ${var.cluster_name}-key.pem ${var.cluster_name}-key.pem ubuntu@${aws_instance.bastion.public_ip}:~/.ssh/
    
    🖥️  From bastion, SSH to nodes:
    Master-1: ssh -i ~/.ssh/${var.cluster_name}-key.pem ubuntu@${aws_instance.masters[0].private_ip}
    Worker-1: ssh -i ~/.ssh/${var.cluster_name}-key.pem ubuntu@${aws_instance.workers[0].private_ip}
    
    📊 Cluster Info:
    Masters: ${join(", ", aws_instance.masters[*].private_ip)}
    Workers: ${join(", ", aws_instance.workers[*].private_ip)}
    
    🚀 Next Steps:
    1. Install Kubernetes on all nodes
    2. Deploy DhakaCart application
    3. Access via: http://${aws_lb.app.dns_name}
    
    =============================================
  EOT
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_key_path" {
  description = "Path to private SSH key"
  value       = "./${var.cluster_name}-key.pem"
}

# ============================================
# Output File for AWS Instances
# ============================================

resource "local_file" "aws_instances_output" {
  filename = "${path.module}/aws_instances_output.txt"
  content = <<-EOT
=============================================
AWS Instances Output Information
Generated: ${timestamp()}
=============================================

BASTION HOST
=============================================
Public IP: ${aws_instance.bastion.public_ip}
SSH Command: ssh -i ${var.cluster_name}-key.pem ubuntu@${aws_instance.bastion.public_ip}
Instance ID: ${aws_instance.bastion.id}
Instance Type: ${aws_instance.bastion.instance_type}

MASTER NODES
=============================================
${join("\n", [
  for i, master in aws_instance.masters : 
  "Master-${i + 1}:\n  Private IP: ${master.private_ip}\n  Instance ID: ${master.id}\n  Instance Type: ${master.instance_type}\n  SSH Command: ssh -i ~/.ssh/${var.cluster_name}-key.pem ubuntu@${master.private_ip}"
])}

Master Private IPs: ${join(", ", aws_instance.masters[*].private_ip)}

WORKER NODES
=============================================
${join("\n", [
  for i, worker in aws_instance.workers : 
  "Worker-${i + 1}:\n  Private IP: ${worker.private_ip}\n  Instance ID: ${worker.id}\n  Instance Type: ${worker.instance_type}\n  SSH Command: ssh -i ~/.ssh/${var.cluster_name}-key.pem ubuntu@${worker.private_ip}"
])}

Worker Private IPs: ${join(", ", aws_instance.workers[*].private_ip)}

LOAD BALANCER
=============================================
DNS Name: ${aws_lb.app.dns_name}
Public URL: http://${aws_lb.app.dns_name}
Load Balancer ARN: ${aws_lb.app.arn}

NETWORKING
=============================================
VPC ID: ${aws_vpc.main.id}
VPC CIDR: ${aws_vpc.main.cidr_block}

SSH KEY
=============================================
Private Key Path: ./${var.cluster_name}-key.pem
Key Name: ${aws_key_pair.k8s_key.key_name}

CLUSTER INFORMATION
=============================================
Cluster Name: ${var.cluster_name}
AWS Region: ${var.aws_region}
Master Count: ${var.master_count}
Worker Count: ${var.worker_count}

NEXT STEPS
=============================================
1. SSH to Bastion:
   ssh -i ${var.cluster_name}-key.pem ubuntu@${aws_instance.bastion.public_ip}

2. Copy SSH key to bastion:
   scp -i ${var.cluster_name}-key.pem ${var.cluster_name}-key.pem ubuntu@${aws_instance.bastion.public_ip}:~/.ssh/

3. From bastion, SSH to nodes:
${join("\n", [
  for i, master in aws_instance.masters : 
  "   Master-${i + 1}: ssh -i ~/.ssh/${var.cluster_name}-key.pem ubuntu@${master.private_ip}"
])}
${join("\n", [
  for i, worker in aws_instance.workers : 
  "   Worker-${i + 1}: ssh -i ~/.ssh/${var.cluster_name}-key.pem ubuntu@${worker.private_ip}"
])}

4. Access Application (after K8s setup):
   http://${aws_lb.app.dns_name}

=============================================
EOT

  depends_on = [
    aws_instance.bastion,
    aws_instance.masters,
    aws_instance.workers,
    aws_lb.app
  ]
}

