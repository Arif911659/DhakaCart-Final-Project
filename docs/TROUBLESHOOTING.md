# DhakaCart Troubleshooting Guide

Comprehensive troubleshooting guide for common issues and their solutions.

## Table of Contents

- [Terraform Issues](#terraform-issues)
- [Kubernetes Cluster Issues](#kubernetes-cluster-issues)
- [Application Deployment Issues](#application-deployment-issues)
- [Monitoring Stack Issues](#monitoring-stack-issues)
- [Network and ALB Issues](#network-and-alb-issues)
- [Database Issues](#database-issues)
- [General Debugging](#general-debugging)

---

## Terraform Issues

### Issue: Terraform Apply Fails

**Symptoms**:
```
Error: Error creating EC2 Instance
Error: timeout while waiting for state to become 'running'
```

**Causes**:
- AWS credentials not configured
- Insufficient permissions
- Service quotas exceeded
- Region unavailable

**Solutions**:

1. **Check AWS credentials**:
   ```bash
   aws sts get-caller-identity
   ```

2. **Verify permissions**:
   - Ensure IAM user/role has EC2, VPC, ELB permissions

3. **Check service quotas**:
   ```bash
   aws service-quotas list-service-quotas \
     --service-code ec2 \
     --query 'Quotas[?QuotaName==`Running On-Demand Standard instances`]'
   ```

4. **Try different region**:
   - Edit `terraform/simple-k8s/variables.tf`
   - Change `aws_region` default value

### Issue: Terraform State Lock

**Symptoms**:
```
Error: Error acquiring the state lock
```

**Solution**:
```bash
# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

---

## Kubernetes Cluster Issues

### Issue: Nodes Not Ready

**Symptoms**:
```bash
kubectl get nodes
# NAME       STATUS     ROLES    AGE
# Master-1   NotReady   master   5m
```

**Diagnosis**:
```bash
# Check node details
kubectl describe node Master-1

# Check kubelet logs
ssh to node
sudo journalctl -u kubelet -f
```

**Common Causes & Solutions**:

1. **CNI not installed**:
   ```bash
   kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
   ```

2. **Kubelet not running**:
   ```bash
   sudo systemctl start kubelet
   sudo systemctl enable kubelet
   ```

3. **Certificate issues**:
   ```bash
   # Regenerate certificates
   sudo kubeadm reset
   sudo kubeadm init --config=/path/to/kubeadm-config.yaml
   ```

### Issue: Pods Stuck in Pending

**Symptoms**:
```bash
kubectl get pods -n dhakacart
# NAME                    READY   STATUS    RESTARTS   AGE
# dhakacart-backend-xxx   0/1     Pending   0          5m
```

**Diagnosis**:
```bash
kubectl describe pod <POD_NAME> -n dhakacart
```

**Common Causes**:

1. **Insufficient resources**:
   - Check node resources: `kubectl top nodes`
   - Reduce resource requests in deployment

2. **Node selector mismatch**:
   - Remove node selectors or add labels to nodes

3. **PVC not bound**:
   - Check PVCs: `kubectl get pvc -n dhakacart`

---

## Application Deployment Issues

### Issue: ImagePullBackOff

**Symptoms**:
```bash
kubectl get pods -n dhakacart
# NAME                    READY   STATUS             RESTARTS   AGE
# dhakacart-backend-xxx   0/1     ImagePullBackOff   0          2m
```

**Diagnosis**:
```bash
kubectl describe pod <POD_NAME> -n dhakacart
# Look for: Failed to pull image
```

**Solutions**:

1. **Check image name**:
   - Verify image exists in registry
   - Check for typos in deployment YAML

2. **Registry authentication**:
   ```bash
   # Create docker registry secret
   kubectl create secret docker-registry regcred \
     --docker-server=<registry> \
     --docker-username=<username> \
     --docker-password=<password> \
     -n dhakacart
   ```

3. **Use local images** (for testing):
   - Set `imagePullPolicy: Never`
   - Build images on all nodes

### Issue: CrashLoopBackOff

**Symptoms**:
```bash
kubectl get pods -n dhakacart
# NAME                    READY   STATUS              RESTARTS   AGE
# dhakacart-backend-xxx   0/1     CrashLoopBackOff    5          5m
```

**Diagnosis**:
```bash
# Check logs
kubectl logs <POD_NAME> -n dhakacart

# Check previous container logs
kubectl logs <POD_NAME> -n dhakacart --previous
```

**Common Causes**:

1. **Application error**:
   - Fix application code
   - Check environment variables

2. **Missing dependencies**:
   - Ensure database/redis are running
   - Check service names and ports

3. **Health check failing**:
   - Adjust liveness/readiness probes
   - Increase `initialDelaySeconds`

---

## Monitoring Stack Issues

### Issue: Grafana Not Accessible

**Symptoms**:
- 404 error at http://\<ALB_DNS\>/grafana/
- Connection timeout

**Diagnosis**:
```bash
# Check Grafana pod
kubectl get pods -n monitoring | grep grafana

# Check Grafana service
kubectl get svc -n monitoring grafana-service
```

**Solutions**:

1. **Setup Grafana ALB routing**:
   ```bash
   cd /home/arif/DhakaCart-03-test/scripts
   ./setup-grafana-alb.sh
   ```

2. **Check Grafana logs**:
   ```bash
   kubectl logs -n monitoring deployment/grafana
   ```

3. **Restart Grafana**:
   ```bash
   kubectl rollout restart deployment/grafana -n monitoring
   ```

### Issue: No Logs in Loki

**Symptoms**:
- "No logs volume available" in Grafana
- Empty query results

**Diagnosis**:
```bash
# Check Promtail pods
kubectl get pods -n monitoring | grep promtail

# Check Promtail logs
kubectl logs -n monitoring daemonset/promtail

# Check positions file
kubectl exec -n monitoring daemonset/promtail -- \
  cat /run/promtail/positions.yaml
```

**Solutions**:

1. **Restart Promtail**:
   ```bash
   kubectl rollout restart daemonset/promtail -n monitoring
   ```

2. **Check Promtail configuration**:
   ```bash
   kubectl get configmap -n monitoring promtail-config -o yaml
   ```

3. **Verify log files exist**:
   ```bash
   kubectl exec -n monitoring daemonset/promtail -- \
     ls -la /var/log/pods/ | head -20
   ```

**See**: [LOKI-TROUBLESHOOTING.md](LOKI-TROUBLESHOOTING.md) for detailed Loki troubleshooting

### Issue: Prometheus Not Scraping

**Symptoms**:
- Targets showing as "down" in Prometheus
- No metrics in Grafana

**Diagnosis**:
```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-service 9090:9090

# Check targets at: http://localhost:9090/targets
```

**Solutions**:

1. **Check service discovery**:
   ```bash
   kubectl get servicemonitors -n monitoring
   ```

2. **Verify network policies**:
   ```bash
   kubectl get networkpolicies -n monitoring
   ```

3. **Restart Prometheus**:
   ```bash
   kubectl rollout restart deployment/prometheus-deployment -n monitoring
   ```

---

## Network and ALB Issues

### Issue: ALB Health Checks Failing

**Symptoms**:
```bash
aws elbv2 describe-target-health --target-group-arn <TG_ARN>
# State: unhealthy
# Reason: Target.FailedHealthChecks
```

**Diagnosis**:
```bash
# Check NodePort services
kubectl get svc -n dhakacart

# Check if pods are running
kubectl get pods -n dhakacart

# Test from worker node
curl http://localhost:30080
```

**Solutions**:

1. **Re-register workers**:
   ```bash
   cd /home/arif/DhakaCart-03-test/terraform/simple-k8s
   ./register-workers-to-alb.sh
   ```

2. **Check security groups**:
   - ALB security group allows inbound 80/443
   - Worker security group allows inbound from ALB

3. **Verify health check path**:
   - Frontend: `/`
   - Backend: `/api/health`

### Issue: Cannot Access Application

**Symptoms**:
- Timeout when accessing http://\<ALB_DNS\>
- Connection refused

**Diagnosis**:
```bash
# Check ALB status
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?DNSName=='<ALB_DNS>'].State"

# Check listener rules
aws elbv2 describe-rules --listener-arn <LISTENER_ARN>

# Test from Bastion
curl -I http://<ALB_DNS>
```

**Solutions**:

1. **Check target groups**:
   ```bash
   aws elbv2 describe-target-groups \
     --query "TargetGroups[?contains(TargetGroupName, 'dhakacart')]"
   ```

2. **Verify DNS propagation**:
   ```bash
   nslookup <ALB_DNS>
   ```

3. **Check security groups**:
   - Ensure your IP is allowed in ALB security group

---

## Database Issues

### Issue: Database Connection Failed

**Symptoms**:
- Backend logs show: "Error: connect ECONNREFUSED"
- Application cannot connect to database

**Diagnosis**:
```bash
# Check database pod
kubectl get pods -n dhakacart | grep db

# Check database logs
kubectl logs -n dhakacart <DB_POD_NAME>

# Check database service
kubectl get svc -n dhakacart dhakacart-db-service
```

**Solutions**:

1. **Verify service name**:
   - Backend should use: `dhakacart-db-service`
   - Port: `5432`

2. **Check environment variables**:
   ```bash
   kubectl describe deployment dhakacart-backend -n dhakacart
   # Look for DB_HOST, DB_PORT, DB_NAME
   ```

3. **Test connection from backend pod**:
   ```bash
   kubectl exec -it <BACKEND_POD> -n dhakacart -- \
     nc -zv dhakacart-db-service 5432
   ```

### Issue: Database Not Seeded

**Symptoms**:
- No products showing in frontend
- Empty database

**Solution**:
```bash
cd /home/arif/DhakaCart-03-test/scripts
./seed-database.sh
```

---

## General Debugging

### Useful Commands

```bash
# Get all resources in namespace
kubectl get all -n dhakacart

# Describe resource
kubectl describe <RESOURCE_TYPE> <RESOURCE_NAME> -n <NAMESPACE>

# Get logs
kubectl logs <POD_NAME> -n <NAMESPACE> --tail=100

# Follow logs
kubectl logs -f <POD_NAME> -n <NAMESPACE>

# Execute command in pod
kubectl exec -it <POD_NAME> -n <NAMESPACE> -- /bin/bash

# Port forward
kubectl port-forward <POD_NAME> <LOCAL_PORT>:<POD_PORT> -n <NAMESPACE>

# Get events
kubectl get events -n <NAMESPACE> --sort-by='.lastTimestamp'
```

### Log Locations

**On Nodes**:
- Kubelet logs: `/var/log/kubelet.log` or `journalctl -u kubelet`
- Container logs: `/var/log/containers/`
- Pod logs: `/var/log/pods/`

**In Kubernetes**:
- Pod logs: `kubectl logs <POD_NAME> -n <NAMESPACE>`
- Previous container: `kubectl logs <POD_NAME> -n <NAMESPACE> --previous`

### Resource Monitoring

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -n dhakacart

# Describe node
kubectl describe node <NODE_NAME>
```

---

## Recovery Procedures

### Complete Cluster Reset

```bash
# On each node
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo rm -rf $HOME/.kube/config

# Re-initialize cluster
# Follow deployment guide from Phase 3
```

### Application Rollback

```bash
# View deployment history
kubectl rollout history deployment/<DEPLOYMENT_NAME> -n dhakacart

# Rollback to previous version
kubectl rollout undo deployment/<DEPLOYMENT_NAME> -n dhakacart

# Rollback to specific revision
kubectl rollout undo deployment/<DEPLOYMENT_NAME> \
  --to-revision=<REVISION> -n dhakacart
```

### Infrastructure Rebuild

```bash
# Destroy infrastructure
cd /home/arif/DhakaCart-03-test/terraform/simple-k8s
terraform destroy

# Rebuild
terraform apply

# Run post-terraform setup
cd ../../scripts
./post-terraform-setup.sh
```

---

## Getting Help

If issues persist:

1. **Check logs** - Always start with logs
2. **Search documentation** - Check all .md files
3. **Verify configuration** - Compare with working examples
4. **Test components individually** - Isolate the problem
5. **Check AWS console** - Verify resources exist

**Documentation**:
- [DEPLOYMENT-GUIDE.md](../DEPLOYMENT-GUIDE.md)
- [QUICK-REFERENCE.md](../QUICK-REFERENCE.md)
- [LOKI-TROUBLESHOOTING.md](LOKI-TROUBLESHOOTING.md)

---

**Last Updated**: 2025-12-07  
**Version**: 1.0
