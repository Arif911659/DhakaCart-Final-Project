# 🚀 DhakaCart Application Deployment Guide - সহজ ভাষায়

**তারিখ:** 30 নভেম্বর, 2025 
**লক্ষ্য:** Kubernetes Cluster এ DhakaCart Application Deploy করা  
**লক্ষ্য দর্শক:** Non-Coder Person (আপনি!)

---

## 📋 Table of Contents

1. [আপনি কোথায় আছেন?](#আপনি-কোথায়-আছেন)
2. [কি কি করতে হবে?](#কি-কি-করে-হবে)
3. [ধাপ ১: আপনার Computer থেকে Master-1 এ Files কপি করা](#ধাপ-১-আপনার-computer-থেকে-master-1-এ-files-কপি-করা)
4. [ধাপ ২: Master-1 এ SSH করা](#ধাপ-২-master-1-এ-ssh-করা)
5. [ধাপ ৩: Application Deploy করা](#ধাপ-৩-application-deploy-করা)
6. [ধাপ ৪: সব কিছু Verify করা](#ধাপ-৪-সব-কিছু-verify-করা)
7. [ধাপ ৫: Public Access Configure করা](#ধাপ-৫-public-access-configure-করা)
8. [ধাপ ৬: Website Test করা](#ধাপ-৬-website-test-করা)
9. [সমস্যা হলে কি করবেন?](#সমস্যা-হলে-কি-করবেন)
10. [Quick Reference Commands](#quick-reference-commands)

---

## আপনি কোথায় আছেন?

### ✅ যা সম্পন্ন হয়েছে:

1. **Infrastructure Deployed** ✅
   - Bastion Host: `13.229.110.212`
   - Master-1: `10.0.10.253`
   - Master-2: `10.0.10.105`
   - Worker-1: `10.0.10.170`
   - Worker-2: `10.0.10.12`
   - Worker-3: `10.0.10.84`
   - Load Balancer: `dhakacart-k8s-alb-1098869932.ap-southeast-1.elb.amazonaws.com`

2. **Kubernetes Cluster Ready** ✅
   - সব nodes Ready status এ আছে
   - `kubectl` command কাজ করছে

### ⏳ এখন যা করতে হবে:

1. **Application Files Master-1 এ কপি করা**
2. **Application Deploy করা**
3. **Public Access Configure করা**
4. **Website Test করা**

---

## কি কি করতে হবে?

### সহজ ভাষায়:

1. **আপনার Computer** → `k8s/` folder → **Master-1** এ কপি করুন
2. **Master-1** এ SSH করুন
3. **kubectl apply** commands run করুন (application deploy হবে)
4. **AWS Console** এ Load Balancer configure করুন
5. **Browser** এ website test করুন

**মোট সময়:** ২০-৩০ মিনিট

---

## ধাপ ১: আপনার Computer থেকে Master-1 এ Files কপি করা

### Option A: Automation Script ব্যবহার করুন (সবচেয়ে সহজ) ⭐

**আপনার Computer এ Terminal/Command Prompt open করুন:**

```bash
# 1. Project folder এ যান
cd /home/arif/DhakaCart-03

# 2. Script executable করুন
chmod +x copy-k8s-to-master1.sh

# 3. Script run করুন
./copy-k8s-to-master1.sh
```

**এই script কি করবে:**
- ✅ আপনার `k8s/` folder Master-1 এ কপি করবে
- ✅ SSH key path check করবে
- ✅ Bastion এর মাধ্যমে Master-1 এ files transfer করবে

**যদি Error হয়:**
- Script আপনাকে error message দেখাবে
- Error message অনুযায়ী fix করুন

---

### Option B: Manual কপি (যদি Script কাজ না করে)

**আপনার Computer এ Terminal open করুন:**

```bash
# 1. Project folder এ যান
cd /home/arif/DhakaCart-03

# 2. SSH key path check করুন
ls -lh terraform/simple-k8s/dhakacart-k8s-key.pem

# 3. Bastion এ SSH key কপি করুন (যদি আগে না করে থাকেন)
scp -i terraform/simple-k8s/dhakacart-k8s-key.pem \
    terraform/simple-k8s/dhakacart-k8s-key.pem \
    ubuntu@13.229.110.212:~/.ssh/

# 4. Bastion এ SSH করুন
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@13.229.110.212

# 5. Bastion এ থেকে Master-1 এ k8s folder কপি করুন
# (Bastion এর ভিতরে এই command run করুন)
scp -r -i ~/.ssh/dhakacart-k8s-key.pem \
    ubuntu@10.0.10.253:/home/ubuntu/k8s \
    /tmp/k8s 2>/dev/null || echo "Copying from local..."

# যদি উপরের command কাজ না করে, তাহলে:
# আপনার Computer থেকে (Bastion এ SSH করার আগে):
scp -r -i terraform/simple-k8s/dhakacart-k8s-key.pem \
    k8s/ \
    ubuntu@13.229.110.212:/tmp/k8s

# তারপর Bastion এ SSH করে:
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@13.229.110.212

# Bastion এর ভিতরে:
scp -r -i ~/.ssh/dhakacart-k8s-key.pem \
    /tmp/k8s \
    ubuntu@10.0.10.253:/home/ubuntu/
```

**💡 সহজ উপায়:** Option A (Script) ব্যবহার করুন!

---

## ধাপ ২: Master-1 এ SSH করা

**আপনার Computer এ Terminal open করুন:**

```bash
# 1. Bastion এ SSH করুন
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@13.229.110.212

# 2. Bastion এর ভিতরে, Master-1 এ SSH করুন
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@10.0.10.253
```

**✅ Success হলে:**
- Terminal prompt দেখাবে: `ubuntu@master-1:~$`
- এর মানে আপনি Master-1 এ আছেন!

**Verify করুন:**
```bash
# Master-1 এ থেকে
pwd
# Output: /home/ubuntu

ls -la k8s/
# Output: namespace.yaml, deployments/, services/, etc. (files দেখাবে)
```

---

## ধাপ ৩: Application Deploy করা

**আপনি এখন Master-1 এ আছেন।** এই commands গুলো **একটি একটি করে** run করুন:

### Step 3.1: Namespace Create করুন

**কেন:** Namespace = Separate area, DhakaCart আলাদা জায়গায় থাকবে

**Command:**
```bash
kubectl apply -f k8s/namespace.yaml
```

**Verify:**
```bash
kubectl get namespace dhakacart
```

**✅ Expected Output:**
```
NAME        STATUS   AGE
dhakacart   Active   5s
```

**যদি Error হয়:**
- Error message দেখুন
- সাধারণত file path ভুল হলে error হয়
- `ls k8s/namespace.yaml` দিয়ে file আছে কিনা check করুন

---

### Step 3.2: Secrets Create করুন

**কেন:** Database password এবং sensitive data store করতে হবে

**Command:**
```bash
kubectl apply -f k8s/secrets/db-secrets.yaml
```

**Verify:**
```bash
kubectl get secrets -n dhakacart
```

**✅ Expected Output:**
```
NAME                  TYPE     DATA   AGE
dhakacart-secrets     Opaque   2      10s
```

---

### Step 3.3: ConfigMaps Create করুন

**কেন:** Application configuration store করতে হবে

**Command:**
```bash
kubectl apply -f k8s/configmaps/
```

**Verify:**
```bash
kubectl get configmaps -n dhakacart
```

**✅ Expected Output:**
```
NAME                  DATA   AGE
dhakacart-config      5      15s
postgres-init         1      15s
```

---

### Step 3.4: Volumes Create করুন

**কেন:** Database data permanently store করার জন্য

**Command:**
```bash
kubectl apply -f k8s/volumes/pvc.yaml
```

**⏱️ Wait:** ৩০-৬০ সেকেন্ড (volumes create হতে সময় লাগে)

**Verify:**
```bash
kubectl get pvc -n dhakacart
```

**✅ Expected Output:**
```
NAME           STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
postgres-pvc   Bound    pvc-xxx  10Gi       RWO            gp3            30s
redis-pvc      Bound    pvc-xxx  5Gi        RWO            gp3            30s
```

**যদি STATUS "Pending" দেখায়:**
- ⏱️ কিছুক্ষণ অপেক্ষা করুন (১-২ মিনিট)
- `kubectl get pvc -n dhakacart -w` দিয়ে watch করুন

---

### Step 3.5: Database Deploy করুন

**কেন:** Database সব data store করবে, এটা প্রথমে deploy করতে হবে

**Command:**
```bash
kubectl apply -f k8s/deployments/postgres-deployment.yaml
```

**⏱️ Wait:** ১-২ মিনিট

**Check Status:**
```bash
kubectl get pods -n dhakacart -l app=dhakacart-db
```

**✅ Expected Output:**
```
NAME                           READY   STATUS    RESTARTS   AGE
dhakacart-db-xxxxxxxxxx-xxxxx  1/1     Running   0          1m
```

**💡 ব্যাখ্যা:**
- `1/1 Ready` = Pod running এবং ready
- `Running` = Database successfully started

**যদি STATUS "Pending" বা "ContainerCreating" দেখায়:**
- ⏱️ কিছুক্ষণ অপেক্ষা করুন (২-৩ মিনিট)
- Check করুন: `kubectl describe pod <pod-name> -n dhakacart`

**যদি STATUS "Error" বা "CrashLoopBackOff" দেখায়:**
- Logs check করুন: `kubectl logs -n dhakacart -l app=dhakacart-db --tail=50`
- Common issue: Image pull error বা configuration error

---

### Step 3.6: Redis Deploy করুন

**কেন:** Redis = Cache/performance boost

**Command:**
```bash
kubectl apply -f k8s/deployments/redis-deployment.yaml
```

**⏱️ Wait:** ১ মিনিট

**Verify:**
```bash
kubectl get pods -n dhakacart -l app=dhakacart-redis
```

**✅ Expected Output:**
```
NAME                              READY   STATUS    RESTARTS   AGE
dhakacart-redis-xxxxxxxxxx-xxxxx  1/1     Running   0          1m
```

---

### Step 3.7: Services Create করুন

**কেন:** Services = Pods এর সাথে connect করার network endpoint

**Command:**
```bash
kubectl apply -f k8s/services/services.yaml
```

**Verify:**
```bash
kubectl get svc -n dhakacart
```

**✅ Expected Output:**
```
NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
dhakacart-db-service        ClusterIP   10.96.x.x       <none>        5432/TCP
dhakacart-redis-service     ClusterIP   10.96.x.x       <none>        6379/TCP
dhakacart-backend-service   ClusterIP   10.96.x.x       <none>        5000/TCP
dhakacart-frontend-service  ClusterIP   10.96.x.x       <none>        80/TCP
```

**💡 ব্যাখ্যা:**
- `ClusterIP` = Internal access (pods একে অপরের সাথে communicate করবে)
- এখন external IP নেই (পরের ধাপে করব)

---

### Step 3.8: Backend Deploy করুন

**কেন:** Backend = API server, Database ready হওয়ার পর deploy করতে হবে

**Command:**
```bash
kubectl apply -f k8s/deployments/backend-deployment.yaml
```

**⏱️ Wait:** ২-৩ মিনিট (images download হতে সময় লাগে)

**Check Status:**
```bash
kubectl get pods -n dhakacart -l app=dhakacart-backend
```

**✅ Expected Output:**
```
NAME                                 READY   STATUS    RESTARTS   AGE
dhakacart-backend-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
dhakacart-backend-xxxxxxxxxx-yyyyy   1/1     Running   0          2m
dhakacart-backend-xxxxxxxxxx-zzzzz   1/1     Running   0          2m
```

**💡 ব্যাখ্যা:**
- ৩টি Backend pods running (High Availability)
- সব pods `1/1 Ready` এবং `Running` status এ থাকতে হবে

**Real-time Watch (Optional):**
```bash
# Real-time status দেখার জন্য (Ctrl+C দিয়ে stop করুন)
kubectl get pods -n dhakacart -l app=dhakacart-backend -w
```

**যদি Problem হয়:**
```bash
# Logs check
kubectl logs -n dhakacart -l app=dhakacart-backend --tail=100

# Pod describe
kubectl describe pod <pod-name> -n dhakacart
```

---

### Step 3.9: Frontend Deploy করুন

**কেন:** Frontend = Website/User interface

**Command:**
```bash
kubectl apply -f k8s/deployments/frontend-deployment.yaml
```

**⏱️ Wait:** ২-৩ মিনিট

**Verify:**
```bash
kubectl get pods -n dhakacart -l app=dhakacart-frontend
```

**✅ Expected Output:**
```
NAME                                  READY   STATUS    RESTARTS   AGE
dhakacart-frontend-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
dhakacart-frontend-xxxxxxxxxx-yyyyy   1/1     Running   0          2m
```

**💡 ব্যাখ্যা:**
- ২টি Frontend pods running
- সব pods `1/1 Ready` এবং `Running` status এ থাকতে হবে

---

## ধাপ ৪: সব কিছু Verify করা

### Step 4.1: সব Pods Check করুন

**Command:**
```bash
kubectl get pods -n dhakacart
```

**✅ Expected Output (সব Running):**
```
NAME                                  READY   STATUS    RESTARTS   AGE
dhakacart-db-xxxxxxxxxx-xxxxx         1/1     Running   0          5m
dhakacart-redis-xxxxxxxxxx-xxxxx       1/1     Running   0          4m
dhakacart-backend-xxxxxxxxxx-xxxxx    1/1     Running   0          3m
dhakacart-backend-xxxxxxxxxx-yyyyy     1/1     Running   0          3m
dhakacart-backend-xxxxxxxxxx-zzzzz     1/1     Running   0          3m
dhakacart-frontend-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
dhakacart-frontend-xxxxxxxxxx-yyyyy   1/1     Running   0          2m
```

**✅ Success Criteria:**
- সব pods "Running" status
- সব pods "1/1 Ready"
- কোনো "Error" বা "CrashLoopBackOff" নেই

**যদি সব "Running" এবং "1/1 Ready" দেখায়, তাহলে Application deployed! ✅**

---

### Step 4.2: Services Check করুন

**Command:**
```bash
kubectl get svc -n dhakacart
```

**✅ Expected Output:**
```
NAME                        TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
dhakacart-db-service        ClusterIP   10.96.x.x       <none>        5432/TCP
dhakacart-redis-service     ClusterIP   10.96.x.x       <none>        6379/TCP
dhakacart-backend-service   ClusterIP   10.96.x.x       <none>        5000/TCP
dhakacart-frontend-service  ClusterIP   10.96.x.x       <none>        80/TCP
```

**✅ Success Criteria:**
- ৪টি services আছে
- সব services "ClusterIP" type

---

### Step 4.3: Application Internal Test করুন (Optional)

**Command:**
```bash
# Backend health check (port-forward)
kubectl port-forward -n dhakacart svc/dhakacart-backend-service 5000:5000
```

**Another terminal এ (Master-1 এ থেকে):**
```bash
# Test API
curl http://localhost:5000/health

# Get products
curl http://localhost:5000/api/products
```

**✅ Success হলে:** JSON response দেখাবে

**Port-forward stop করতে:** `Ctrl + C`

---

## ধাপ ৫: Public Access Configure করা

এখন সব pods running আছে, কিন্তু Internet থেকে access করা যাচ্ছে না। Load Balancer configure করতে হবে।

### Step 5.1: Frontend Service NodePort এ Change করুন

**কেন:** Load Balancer NodePort use করে, তাই Frontend service NodePort type করতে হবে

**Command (Master-1 এ থেকে):**
```bash
# Frontend service NodePort type করুন
kubectl patch svc dhakacart-frontend-service -n dhakacart -p '{"spec":{"type":"NodePort"}}'
```

**Verify:**
```bash
kubectl get svc -n dhakacart dhakacart-frontend-service
```

**✅ Expected Output:**
```
NAME                        TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)
dhakacart-frontend-service  NodePort   10.96.x.x       <none>        80:30080/TCP
```

**💡 ব্যাখ্যা:**
- `NodePort` = External access enable
- `30080` = NodePort number (Load Balancer এই port use করবে)

**যদি NodePort না হয়:**
```bash
# Manual edit
kubectl edit svc dhakacart-frontend-service -n dhakacart
# Change: type: ClusterIP → type: NodePort
# Save: ESC, :wq (vi editor)
```

---

### Step 5.2: Load Balancer Target Group Update করুন (AWS Console)

**Current Status:** 
- Load Balancer আছে: `dhakacart-k8s-alb-1098869932.ap-southeast-1.elb.amazonaws.com`
- কিন্তু target group workers এর সাথে connect নেই

**AWS Console এ যান:**

1. **AWS Console → EC2 → Target Groups**
   - URL: https://console.aws.amazon.com/ec2/v2/home?region=ap-southeast-1#TargetGroups:

2. **Target group খুঁজুন**
   - dhakacart-k8s-alb এর সাথে associated target group
   - Name দেখতে পাবেন: `dhakacart-k8s-alb-tg` বা similar

3. **"Targets" tab → "Register targets" click করুন**

4. **Worker nodes select করুন:**
   - ✅ worker-1: `10.0.10.170` Port: `30080`
   - ✅ worker-2: `10.0.10.12` Port: `30080`
   - ✅ worker-3: `10.0.10.84` Port: `30080`

5. **"Register targets" button click করুন**

6. **Health check wait করুন**
   - ১-২ মিনিট অপেক্ষা করুন
   - Status "healthy" হতে হবে

**💡 Screenshot Guide:**
```
AWS Console → EC2 → Target Groups
├── Select target group (dhakacart-k8s-alb-tg)
├── Click "Targets" tab
├── Click "Register targets"
├── Select instances:
│   ├── worker-1 (10.0.10.170) Port: 30080
│   ├── worker-2 (10.0.10.12) Port: 30080
│   └── worker-3 (10.0.10.84) Port: 30080
└── Click "Register targets"
```

---

### Step 5.3: Load Balancer Listener Configure করুন (AWS Console)

**AWS Console এ:**

1. **EC2 → Load Balancers → `dhakacart-k8s-alb-...` select করুন**

2. **"Listeners" tab**

3. **Listener আছে কিনা check করুন (Port 80)**
   - যদি আছে → OK
   - যদি না থাকে → "Add listener" click করুন

4. **Listener Configuration:**
   - Protocol: HTTP
   - Port: 80
   - Default action: Forward to target group
   - Target group: dhakacart-k8s-alb-tg (select করুন)

5. **Save করুন**

---

### Step 5.4: Security Group Update করুন (যদি প্রয়োজন)

**AWS Console এ:**

1. **EC2 → Security Groups**

2. **Worker nodes এর security group খুঁজুন**
   - Name: `dhakacart-k8s-worker-sg` বা similar

3. **Inbound Rules → Edit**

4. **Add rule:**
   - Type: Custom TCP
   - Port: 30080
   - Source: Load Balancer security group (বা 0.0.0.0/0 for testing)
   - Description: "Allow NodePort 30080 from Load Balancer"

5. **Save rules**

---

## ধাপ ৬: Website Test করা

### Step 6.1: Load Balancer DNS Get করুন

**Load Balancer DNS:**
```
http://dhakacart-k8s-alb-1098869932.ap-southeast-1.elb.amazonaws.com
```

**Or AWS Console এ:**
- EC2 → Load Balancers → dhakacart-k8s-alb → DNS name copy করুন

---

### Step 6.2: Browser এ Test করুন

1. **Browser open করুন** (Chrome, Firefox, etc.)

2. **Address bar এ paste করুন:**
   ```
   http://dhakacart-k8s-alb-1098869932.ap-southeast-1.elb.amazonaws.com
   ```

3. **Enter press করুন**

**✅ Success হলে:**
- DhakaCart website দেখাবে! 🎉
- Homepage load হবে
- Products দেখাবে

**যদি কাজ না করে:**
- ⏱️ Wait করুন ২-৩ মিনিট (Load Balancer propagate হতে সময় লাগে)
- Health check verify করুন (AWS Console → Target Groups → Health checks)
- Port-forward test করুন (local এ কাজ করছে কিনা)

---

## সমস্যা হলে কি করবেন?

### Issue 1: Pods "Pending" Status

**Cause:** Resources not available বা volume issue

**Solution:**
```bash
# Check pod details
kubectl describe pod <pod-name> -n dhakacart

# Common fixes:
# - Wait for volumes (PVC)
# - Check node resources
# - Check image pull
```

---

### Issue 2: Pods "CrashLoopBackOff"

**Cause:** Application error বা configuration issue

**Solution:**
```bash
# Check logs
kubectl logs -n dhakacart <pod-name> --tail=100

# Common fixes:
# - Database connection issue → Check DB pod
# - Configuration error → Check ConfigMaps
# - Image pull error → Check image name
```

---

### Issue 3: Services Not Accessible

**Cause:** Service type বা selector issue

**Solution:**
```bash
# Check service
kubectl describe svc <service-name> -n dhakacart

# Check endpoints
kubectl get endpoints -n dhakacart
```

---

### Issue 4: Load Balancer Not Working

**Cause:** Target group unhealthy বা port mismatch

**Solution:**
1. Target group health checks verify করুন
2. Port 30080 verify করুন
3. Security group rules check করুন
4. Wait করুন (propagation time)

---

### Issue 5: Files Copy Failed

**Cause:** SSH key path ভুল বা network issue

**Solution:**
```bash
# Check SSH key exists
ls -lh terraform/simple-k8s/dhakacart-k8s-key.pem

# Check key permissions
chmod 400 terraform/simple-k8s/dhakacart-k8s-key.pem

# Test SSH connection
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@13.229.110.212
```

---

## Quick Reference Commands

### Master-1 এ SSH করা:

```bash
# Your Computer → Bastion
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@13.229.110.212

# Bastion → Master-1
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@10.0.10.253
```

---

### Application Deploy (Master-1 এ থেকে):

```bash
# All at once
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/
kubectl apply -f k8s/volumes/
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/

# Verify
kubectl get pods -n dhakacart
kubectl get svc -n dhakacart
```

---

### Frontend Service NodePort:

```bash
kubectl patch svc dhakacart-frontend-service -n dhakacart -p '{"spec":{"type":"NodePort"}}'
kubectl get svc -n dhakacart dhakacart-frontend-service
```

---

### Useful kubectl Commands:

```bash
# All resources
kubectl get all -n dhakacart

# Pod logs
kubectl logs -n dhakacart <pod-name> -f

# Pod describe
kubectl describe pod <pod-name> -n dhakacart

# Service endpoints
kubectl get endpoints -n dhakacart

# Delete and redeploy (যদি problem হয়)
kubectl delete -f k8s/deployments/backend-deployment.yaml
kubectl apply -f k8s/deployments/backend-deployment.yaml
```

---

## ✅ Complete Checklist

### Before Starting:

- [ ] Kubernetes cluster ready (all nodes Ready)
- [ ] `kubectl` command works on Master-1
- [ ] SSH access to Bastion and Master-1
- [ ] `k8s/` folder exists in your computer

### Step 1: Files Copy:

- [ ] Run `copy-k8s-to-master1.sh` script
- [ ] OR manually copy `k8s/` folder to Master-1
- [ ] Verify files in Master-1: `ls -la k8s/`

### Step 2: SSH to Master-1:

- [ ] SSH to Bastion
- [ ] SSH to Master-1 from Bastion
- [ ] Verify: `pwd` shows `/home/ubuntu`

### Step 3: Application Deploy:

- [ ] Namespace created
- [ ] Secrets created
- [ ] ConfigMaps created
- [ ] Volumes created (PVCs Bound)
- [ ] Database deployed (Running)
- [ ] Redis deployed (Running)
- [ ] Services created (4 services)
- [ ] Backend deployed (3 pods Running)
- [ ] Frontend deployed (2 pods Running)

### Step 4: Verify:

- [ ] All pods Running (`kubectl get pods -n dhakacart`)
- [ ] All services created (`kubectl get svc -n dhakacart`)
- [ ] No errors in pods

### Step 5: Public Access:

- [ ] Frontend service NodePort type
- [ ] Load Balancer target group configured
- [ ] Workers registered in target group (Port 30080)
- [ ] Target group health checks healthy
- [ ] Listener configured (Port 80)
- [ ] Security group allows port 30080

### Step 6: Website Test:

- [ ] Load Balancer DNS accessible
- [ ] Website loads in browser
- [ ] Homepage shows correctly

---

## 🎯 Simple Summary

### এখন যা করতে হবে:

**1. আপনার Computer এ:**
```bash
cd /home/arif/DhakaCart-03
chmod +x copy-k8s-to-master1.sh
./copy-k8s-to-master1.sh
```

**2. Master-1 এ SSH:**
```bash
ssh -i terraform/simple-k8s/dhakacart-k8s-key.pem ubuntu@13.229.110.212
ssh -i ~/.ssh/dhakacart-k8s-key.pem ubuntu@10.0.10.253
```

**3. Master-1 এ Deploy:**
```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets/
kubectl apply -f k8s/configmaps/
kubectl apply -f k8s/volumes/
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/
kubectl get pods -n dhakacart
```

**4. Frontend Service NodePort:**
```bash
kubectl patch svc dhakacart-frontend-service -n dhakacart -p '{"spec":{"type":"NodePort"}}'
```

**5. AWS Console:**
- Load Balancer → Target Groups → Register Workers (Port 30080)

**6. Browser:**
- Open: `http://dhakacart-k8s-alb-1098869932.ap-southeast-1.elb.amazonaws.com`

---

## 🎉 Success!

যদি সব steps follow করে website browser এ দেখতে পান, তাহলে **Deployment Successful!** 🎉

**Congratulations!** আপনি আপনার DhakaCart application successfully deploy করেছেন!

---

**Created:** ২৪ নভেম্বর, ২০২৪  
**Last Updated:** ২৪ নভেম্বর, ২০২৪  
**Status:** Ready to Use ✅

**Good Luck! আপনি পারবেন! 🚀**

