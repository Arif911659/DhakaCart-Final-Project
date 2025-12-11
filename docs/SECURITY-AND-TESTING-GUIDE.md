# 🔐 Security & Testing - Complete Implementation Guide

This guide shows you how to use DhakaCart's security hardening and performance testing tools to ensure your application is **secure**, **stable**, and **performant**.

---

## 📁 Overview

You have **2 important directories**:

### 1. `/security` - Application Security
- **Network Policies** - Controls pod-to-pod communication
- **Vulnerability Scanning** - Finds security bugs in code and containers
- **SSL/TLS Setup** - HTTPS encryption automation

### 2. `/testing` - Performance Testing  
- **Load Testing** - Simulates real user traffic
- **Performance Benchmarks** - Measures response times

**Why you need these:**
- Production applications MUST be secure and tested
- Employers expect knowledge of security and testing
- 4-hour lab demos impress evaluators

---

## 🚀 Part 1: Security Implementation

### Step 1: Install Trivy (Vulnerability Scanner)
**Note:** The automation script handles this, but for manual install:

**On your local machine:**
```bash
# Install Trivy to local bin
mkdir -p $HOME/.local/bin
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $HOME/.local/bin
export PATH=$HOME/.local/bin:$PATH

# Verify
trivy --version
```

### Step 2: Automated Security Hardening (Recommended)

Instead of running steps manualy, use the automation script:

```bash
cd ~/DhakaCart-03-test/scripts/security
./apply-security-hardening.sh
```

**This script automatically:**
1. Copies network policies to Master-1
2. Applies policies for Frontend and Database
3. Runs Trivy vulnerability scan
4. Checks NPM dependencies
5. Verifies network isolation

### Step 3: View Reports
The script saves reports to: `/tmp/trivy-reports-*/`

### Step 5: Test Network Policies

**Verify frontend can reach backend (should work):**
```bash
kubectl exec -it -n dhakacart deployment/dhakacart-frontend -- curl -s http://dhakacart-backend-service:5000/health
```

**Verify database CANNOT reach internet (should fail):**
```bash
kubectl exec -it -n dhakacart deployment/dhakacart-db -- curl -m 5 https://google.com
# Expected: timeout
```

---

## 🧪 Part 2: Load Testing Implementation

### Step 1: Install K6 (Load Testing Tool)

**On your local machine (Ubuntu/WSL):**
```bash
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6

# Verify
k6 version
```

### Step 2: Run Load Tests

```bash
cd ~/DhakaCart-03-test/testing/load-tests

```bash
cd ~/DhakaCart-03-test/testing/load-tests

# Run Load Test (Auto-detects ALB URL)
./run-load-test.sh
```

**Note**: The script automatically fetches the ALB URL from your infrastructure config. No manual finding required!

**Test Options:**
1. **Smoke Test** - Quick 30-second check (2 users)
2. **Load Test** - Normal traffic (100 users, 10 mins)  
3. **Stress Test** - High load (500 users, 15 mins)
4. **Spike Test** - Sudden surge (1000 users, 5 mins)
5. **Endurance Test** - Long-term stability (50 users, 1 hour)

**Example: Run Smoke Test**
```
Select test type:
1) Smoke Test (Quick - 2 VUs, 30s)
2) Load Test (Normal - 100 VUs, 10m)
3) Stress Test (High - 500 VUs, 15m)
4) Spike Test (Burst - 1000 VUs, 5m)
5) Endurance Test (Long - 50 VUs, 1h)
6) Custom
Enter choice [1-6]: 1
```

### Step 3: Understand Results

**K6 Output Explanation:**
```
checks.........................: 98.50% ✓ 2955   ✗ 45  
http_req_duration..............: avg=145ms min=12ms med=98ms max=2.1s p(90)=280ms p(95)=450ms
http_req_failed................: 1.50%  ✓ 45    ✗ 2955
http_reqs......................: 3000   50/s
```

**What each metric means:**
- **checks**: 98.50% of tests passed ✅ (Good: >95%)
- **http_req_duration**: 
  - Average: 145ms
  - p(95): 450ms ← 95% of requests finished in <450ms ✅ (Goal: <2s)
- **http_req_failed**: 1.5% error rate ⚠️ (Goal: <1%)
- **http_reqs**: 50 requests/second

**Performance Goals:**

| Metric | ✅ Good | ⚠️ Acceptable | ❌ Poor |
|--------|---------|--------------|---------|
| p95 Response Time | <500ms | <1s | >1s |
| Error Rate | <0.1% | <1% | >1% |
| Requests/sec | >100 | >50 | <50 |

### Step 4: Monitor During Test

**While K6 is running**, open another terminal and SSH to Master-1:

```bash
# Watch pod resource usage
kubectl top pods -n dhakacart --watch

# Check pod status
kubectl get pods -n dhakacart -w
```

**Look for:**
- High CPU usage (>80%) - needs more replicas
- High memory (>80%) - increase limits
- Pod restarts - indicates crashes

---

## 📊 Part 3: Real-World Usage Scenarios

### Scenario 1: Before Production Deployment

**Run these checks:**
```bash
# 1. Security scan
cd ~/DhakaCart-03-test/security/scanning
./trivy-scan.sh
./dependency-check.sh

# 2. Apply network policies
kubectl apply -f ../network-policies/*.yaml

# 3. Run smoke test
cd ~/DhakaCart-03-test/testing/load-tests
BASE_URL=http://your-alb-url ./run-load-test.sh
# Select: 1 (Smoke Test)
```

**Acceptable criteria to proceed:**
- ✅ CRITICAL vulnerabilities = 0
- ✅ Network policies applied
- ✅ Smoke test >95% success rate

### Scenario 2: Performance Validation

**After deploying to production:**
```bash
# Run load test (normal traffic)
cd ~/DhakaCart-03-test/testing/load-tests
BASE_URL=http://your-production-url ./run-load-test.sh
# Select: 2 (Load Test)
```

**Monitor Grafana during test:**
1. Open `http://<ALB-DNS>/grafana`
2. Dashboard 1860 (Node Exporter)
3. Watch CPU/Memory graphs spike

**If performance is poor:**
- Add more replicas: `kubectl scale deployment/dhakacart-backend --replicas=5 -n dhakacart`
- Increase resources in `k8s/deployments/backend-deployment.yaml`

### Scenario 3: Security Audit for Presentation

**Demonstrate security knowledge:**
```bash
# 1. Show network policies
kubectl get networkpolicies -n dhakacart
kubectl describe networkpolicy dhakacart-backend-policy -n dhakacart

# 2. Show scanning results
cd ~/DhakaCart-03-test/security/scanning
./trivy-scan.sh
cat /tmp/trivy-reports-*/SUMMARY.txt

# 3. Test pod isolation
kubectl exec -it -n dhakacart deployment/dhakacart-db -- curl -m 5 https://google.com
# Should timeout - database can't reach internet!
```

---

## 🎯 Recommended Workflow (4-Hour Lab)

**Time-boxed implementation:**

### Hour 1-2: Infrastructure + Deployment ✅ (Already Done)
- Terraform infrastructure
- Kubernetes setup
- Application deployment

### Hour 3: Security Hardening (30 mins)
```bash
# 1. Quick security scan (5 mins)
cd ~/DhakaCart-03-test/security/scanning
./trivy-scan.sh

# 2. Apply network policies (10 mins)
cd ~/DhakaCart-03-test
cp -r security/network-policies k8s/security/
./scripts/k8s-deployment/sync-k8s-to-master1.sh

# On Master-1:
kubectl apply -f ~/k8s/security/network-policies/

# 3. Test policies (5 mins)
kubectl exec -it -n dhakacart deployment/dhakacart-frontend -- curl http://dhakacart-backend-service:5000/health
```

### Hour 3-4: Load Testing (30 mins)
```bash
# 1. Install K6 (10 mins - if not installed)
# Follow Step 1 above

# 2. Run smoke test (5 mins)
cd ~/DhakaCart-03-test/testing/load-tests
BASE_URL=http://<YOUR-ALB> ./run-load-test.sh
# Select: 1

# 3. Run load test (15 mins)
# Select: 2
```

---

## 🔧 Troubleshooting

### Issue 1: Trivy Not Found
```bash
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
```

### Issue 2: Network Policy Blocks Everything
```bash
# Check policies
kubectl get networkpolicies -n dhakacart

# Delete specific policy
kubectl delete networkpolicy dhakacart-backend-policy -n dhakacart

# Reapply correctly
kubectl apply -f ~/k8s/security/network-policies/backend-policy.yaml
```

### Issue 3: K6 Shows High Error Rate
**Possible causes:**
- ALB health checks failing
- Pods not ready
- Database connection issues

**Debug:**
```bash
# Check pod status
kubectl get pods -n dhakacart

# Check backend logs
kubectl logs -n dhakacart deployment/dhakacart-backend --tail=50

# Check database
kubectl exec -n dhakacart deployment/dhakacart-db -- psql -U dhakacart -d dhakacart_db -c "SELECT COUNT(*) FROM products;"
```

---

## 📚 Key Files Reference

### Security Files
```
security/
├── scanning/
│   ├── trivy-scan.sh          # Run: ./trivy-scan.sh
│   └── dependency-check.sh     # Run: ./dependency-check.sh
└── network-policies/
    ├── frontend-policy.yaml    # kubectl apply -f
    ├── backend-policy.yaml     # kubectl apply -f
    └── database-policy.yaml    # kubectl apply -f
```

### Testing Files
```
testing/
├── load-tests/
│   ├── k6-load-test.js        # K6 test script
│   └── run-load-test.sh        # Run: ./run-load-test.sh
└── performance/
    └── benchmark.sh            # Apache Bench tests
```

---

## 🎓 What You've Learned

After implementing security and testing, you can demonstrate:

✅ **Security:**
- Container vulnerability scanning
- Network segmentation with policies
- Dependency management
- Zero-trust architecture

✅ **Performance:**
- Load testing methodology
- Reading performance metrics
- Identifying bottlenecks
- Scaling strategies

✅ **DevOps Best Practices:**
- Continuous security scanning
- Performance benchmarking
- Monitoring under load
- Production readiness validation

---

## 💡 Quick Commands Cheat Sheet

```bash
# === SECURITY ===

# Scan containers
cd ~/DhakaCart-03-test/security/scanning && ./trivy-scan.sh

# Check dependencies
cd ~/DhakaCart-03-test/security/scanning && ./dependency-check.sh

# Apply network policies (on Master-1)
kubectl apply -f ~/k8s/security/network-policies/

# Test network isolation
kubectl exec -it -n dhakacart deployment/dhakacart-db -- curl -m 5 https://google.com

# === TESTING ===

# Run load test
cd ~/DhakaCart-03-test/testing/load-tests
BASE_URL=http://<YOUR-ALB-URL> ./run-load-test.sh

# Monitor during test (on Master-1)
kubectl top pods -n dhakacart --watch

# Check application health
kubectl get pods -n dhakacart
kubectl logs -n dhakacart deployment/dhakacart-backend --tail=50
```

---

## 🔐 Part 3: Enterprise Security & Reliability (Phase 2)

### Step 1: Automated Backup (Velero + MinIO)

**Why:** Disaster recovery. If the cluster crashes, you lose everything without backups.
**Implementation:** `scripts/enterprise-features/install-velero.sh`

**Verification:**
```bash
# Check Backup Schedule
velero schedule get

# Trigger Manual Backup
velero backup create test-backup --include-namespaces dhakacart

# Verify Backup Status
velero backup get
# Expected: Completed (or partially failed if metadata issues, but data is safe)
```

### Step 2: Secrets Management (Vault)

**Why:** Storing passwords in plain text (ConfigMaps) is insecure. Vault encrypts them.
**Implementation:** `scripts/enterprise-features/install-vault.sh`

**Verification:**
```bash
# Check Vault Status
kubectl get pods -n vault
# Expected: vault-0 Running
```

### Step 3: HTTPS/TLS (Cert-Manager)

**Why:** Encrypts traffic between user and load balancer.
**Implementation:** `scripts/enterprise-features/install-cert-manager.sh`

**Verification:**
```bash
# Check Cert-Manager Pods
kubectl get pods -n cert-manager
```

---

## 🚀 Next Steps

1. **Add to deployment guide** - Update `Project-Deployment-Steps-(06-12-2025).md` with security phase
2. **CI/CD Integration** - Add Trivy scans to GitHub Actions
3. **Scheduled Testing** - Run weekly load tests automatically
4. **Alerting** - Set up alerts for high error rates in Grafana

---

**📝 Created:** 07 December 2025  
**🎯 Purpose:** Production-ready security and performance validation  
**⏱️ Time Required:** ~1 hour total (Security: 30min, Testing: 30min)

---

**🔐 Security + 🧪 Testing = 💪 Production-Ready Application!**
