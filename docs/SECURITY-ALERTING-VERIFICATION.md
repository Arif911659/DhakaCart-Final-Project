# Security & Alerting - Verification Guide

This guide contains all verification steps for the security and alerting features.

---

## 🔐 Security Verification

### 1. Verify Network Policies Applied

**SSH to Master-1 and run:**
```bash
kubectl get networkpolicies -n dhakacart
```

**Expected Output:**
```
NAME                        POD-SELECTOR              AGE
dhakacart-frontend-policy   app=dhakacart-frontend    5m
dhakacart-database-policy   app=dhakacart-db          5m
```
*(Note: Backend policy intentionally omitted for stability)*
```

### 2. Test Network Isolation

**Positive Test - Frontend can reach Backend:**
```bash
kubectl exec -it -n dhakacart deployment/dhakacart-frontend -- curl -s http://dhakacart-backend-service:5000/health
```
**Expected:** `{"status":"ok"}` or valid response

**Negative Test - Database CANNOT reach Internet:**
```bash
kubectl exec -it -n dhakacart deployment/dhakacart-db -- timeout 5 curl https://google.com
```
**Expected:** Command times out (this proves isolation works!)

### 3. Review Security Scan Results

**Check Trivy scan reports:**
```bash
cat /tmp/trivy-reports-*/SUMMARY.txt
```

**Expected:** Shows vulnerability counts for backend and frontend images.

**View detailed backend report:**
```bash
cat /tmp/trivy-reports-*/arifhossaincse22_dhakacart-backend_latest.txt | less
```

### 4. Check Dependency Audit

**Review npm audit results from the scan output.**

If vulnerabilities found, fix them:
```bash
# Backend
cd ~/DhakaCart-03-test/backend
npm audit fix

# Frontend  
cd ../frontend
npm audit fix
```

---

## 📊 Alerting Verification

### 1. Verify Alertmanager Pod Running

**SSH to Master-1:**
```bash
kubectl get pods -n monitoring | grep alertmanager
```

**Expected:**
```
alertmanager-xxxxx   1/1   Running   0   5m
```

### 2. Check Prometheus Targets

**Access in browser:**
```
http://<ALB_DNS>/prometheus/targets
```

**Expected:** Shows `alertmanager-service` with status **UP** (green)

### 3. View Alert Rules

**Access in browser:**
```
http://<ALB_DNS>/prometheus/alerts
```

**Expected:** All 7 alert rules listed:
- HighErrorRate
- HighLatency  
- PodDown
- HighMemoryUsage
- HighCPUUsage
- DatabaseConnectionFailed
- RedisConnectionFailed

All should be **Inactive** (green) if system is healthy.

### 4. Test Alert Triggering

**Trigger PodDown alert:**
```bash
# Scale backend to 0
kubectl scale deployment/dhakacart-backend --replicas=0 -n dhakacart

# Wait 2-3 minutes
sleep 180

# Check Prometheus alerts page
# Expected: PodDown alert should be FIRING (red)
```

**Resolve the alert:**
```bash
# Scale back to normal
kubectl scale deployment/dhakacart-backend --replicas=3 -n dhakacart

# Wait 2-3 minutes  
sleep 180

# Check Prometheus alerts page again
# Expected: PodDown alert should be Inactive (green)
```

### 5. Access Alertmanager UI

**Method 1: Direct NodePort access**
```
http://<WORKER_NODE_IP>:30093
```

**Method 2: Port forward (from Master-1)**
```bash
kubectl port-forward -n monitoring svc/alertmanager-service 9093:9093
# Then access: http://localhost:9093
```

---

## 🤖 CI/CD Security Scan Verification

### Trigger GitHub Actions Workflow

**Create a test branch and push:**
```bash
cd ~/DhakaCart-03-test

git checkout -b test/security-scan
echo "# Test security scan $(date)" >> README.md
git add README.md
git commit -m "test: trigger security scan workflow"
git push origin test/security-scan
```

### View Workflow Results

1. Go to: https://github.com/Arif911659/DhakaCart-03-test/actions
2. Click on latest **"Security Scan"** workflow
3. Wait ~3 minutes for completion
4. Check:
   - ✅ Workflow status (should be green if no CRITICAL vulns)
   - 📄 Artifacts: `trivy-scan-reports` 
   - 📊 Job summary showing vulnerability counts

### Download Scan Reports

1. Click on workflow run
2. Scroll to **Artifacts** section  
3. Download `trivy-scan-reports.zip`
4. Extract and review:
   - `backend-scan.txt` - Human-readable report
   - `backend-scan-results.json` - Machine-readable
   - `frontend-scan.txt`
   - `frontend-scan-results.json`

---

## 📈 Monitoring Dashboard Verification

### Import Additional Dashboards

**For alerting visualization, import:**

1. Go to Grafana: `http://<ALB_DNS>/grafana`
2. Login: `admin` / `dhakacart123`
3. **Dashboards** → **New** → **Import**
4. Enter ID: `11074` (Prometheus Alerts Dashboard)
5. Select **Prometheus** as datasource
6. **Import**

---

## 🧪 Complete Test Scenario

**Full end-to-end test:**

```bash
# 1. Verify all security features
./scripts/security/apply-security-hardening.sh

# 2. Deploy alerting
./scripts/monitoring/deploy-alerting-stack.sh

# 3. Trigger test alert
kubectl scale deployment/dhakacart-backend --replicas=0 -n dhakacart

# 4. Wait and check alerts
sleep 180
# View: http://<ALB_DNS>/prometheus/alerts

# 5. Resolve alert
kubectl scale deployment/dhakacart-backend --replicas=3 -n dhakacart

# 6. Verify resolution
sleep 180
# Check alerts page again - should be green
```

---

## 📝 Success Criteria Checklist

### Security
- [ ] 3 network policies applied
- [ ] Trivy scan completed with no CRITICAL vulnerabilities
- [ ] npm audit shows 0 high/critical issues
- [ ] Database cannot reach external internet (timeout test passes)
- [ ] Frontend can reach backend (health check passes)

### Alerting  
- [ ] Alertmanager pod running
- [ ] Prometheus shows 7 alert rules loaded
- [ ] Test alert (PodDown) fires correctly
- [ ] Test alert resolves when condition fixes
- [ ] Alertmanager UI accessible

### CI/CD
- [ ] GitHub Actions workflow exists
- [ ] Workflow triggers on push
- [ ] Scan artifacts uploaded
- [ ] Build fails on CRITICAL vulnerabilities

---

## 🔧 Troubleshooting

### Network Policy Blocks Everything

**Symptom:** Applications can't communicate

**Solution:**
```bash
# Delete all policies
kubectl delete networkpolicy --all -n dhakacart

# Reapply one by one
kubectl apply -f ~/k8s/security/network-policies/frontend-policy.yaml
# Test
kubectl apply -f ~/k8s/security/network-policies/backend-policy.yaml  
# Test
kubectl apply -f ~/k8s/security/network-policies/database-policy.yaml
```

### Alerts Not Showing

**Symptom:** No alerts in Prometheus

**Solution:**
```bash
# Check alert rules loaded
kubectl exec -n monitoring deployment/prometheus-deployment -- cat /etc/prometheus/alert-rules.yml

# Check Prometheus logs
kubectl logs -n monitoring deployment/prometheus-deployment --tail=50

# Restart Prometheus
kubectl rollout restart deployment/prometheus-deployment -n monitoring
```

### Alertmanager Not Reachable

**Symptom:** Prometheus can't connect to Alertmanager

**Solution:**
```bash
# Check Alertmanager pod
kubectl get pods -n monitoring | grep alertmanager

# Check service
kubectl get svc -n monitoring alertmanager-service

# Test connectivity from Prometheus
kubectl exec -n monitoring deployment/prometheus-deployment -- wget -qO- http://alertmanager-service.monitoring.svc.cluster.local:9093/-/healthy
```

---

## 📚 Reference Commands

```bash
# View all alerts
kubectl get prometheusrules -n monitoring

# Check Alertmanager config
kubectl get configmap alertmanager-config -n monitoring -o yaml

# View Prometheus config  
kubectl get configmap prometheus-server-conf -n monitoring -o yaml

# Restart monitoring stack
kubectl rollout restart deployment/prometheus-deployment -n monitoring
kubectl rollout restart deployment/alertmanager -n monitoring
kubectl rollout restart deployment/grafana -n monitoring
```

---

**Last Updated:** 07 December 2025  
**Tools:** Trivy, Prometheus, Alertmanager, GitHub Actions
