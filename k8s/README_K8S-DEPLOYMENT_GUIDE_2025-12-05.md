# Kubernetes Deployment Guide for DhakaCart

**Complete deployment commands for DhakaCart E-Commerce Platform on Kubernetes**
![alt text](image.png)


---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Complete Deployment Commands](#complete-deployment-commands)
3. [Quick One-Line Deployment](#quick-one-line-deployment)
4. [Step-by-Step Deployment](#step-by-step-deployment)
5. [Verification Commands](#verification-commands)
6. [Port-Forwarding for Testing](#port-forwarding-for-testing)
7. [Detailed Setup](#detailed-setup)
8. [Monitoring & Management](#monitoring--management)
9. [Troubleshooting](#troubleshooting)
10. [Cleanup](#cleanup)

---

## Prerequisites

### 1. **Kubernetes Cluster** (Choose one):

```bash
# AWS EKS
eksctl create cluster --name dhakacart --region us-east-1 --nodes 3 --node-type t3.medium

# GCP GKE
gcloud container clusters create dhakacart --num-nodes=3 --machine-type=n1-standard-2 --region=us-central1

# Azure AKS
az aks create --resource-group dhakacart-rg --name dhakacart --node-count 3 --node-vm-size Standard_B2s

# DigitalOcean
doctl kubernetes cluster create dhakacart --count 3 --size s-2vcpu-4gb

# Minikube (local testing)
minikube start --cpus=4 --memory=8192 --driver=docker
```

### 2. **Install Required Tools**

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify kubectl
kubectl version --client

# Helm (for cert-manager)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm
helm version
```

### 3. **Configure kubectl Context**

```bash
# Check current context
kubectl config current-context

# List all contexts
kubectl config get-contexts

# Switch context (if needed)
kubectl config use-context <your-cluster-context>

# Test connection
kubectl cluster-info
kubectl get nodes
```

---

## 🚀 Complete Deployment Commands

### **OPTION 1: Automated Production Deployment** (Recommended)

This script handles everything: namespaces, secrets, configmaps, deployments, services, ingress, and ALB configuration.

```bash
# 1. Make the script executable
chmod +x k8s/deploy-prod.sh

# 2. Run the deployment script (Run this from Master Node Project Root)
# This includes App, DB, Monitoring, and Security Policies!
./k8s/deploy-prod.sh

# 3. (Optional) Database Seeding
# The script usually handles this, but if you need to run it manually:
kubectl exec -i -n dhakacart deployment/dhakacart-db -- psql -U dhakacart -d dhakacart < database/init.sql
```


---

### **OPTION 2: Step-by-Step Deployment** (Recommended for Production)

#### **Step 1: Create Namespace**

```bash
kubectl apply -f k8s/namespace.yaml

# Verify namespace created
kubectl get namespace dhakacart
```

#### **Step 2: Apply Secrets**

```bash
kubectl apply -f k8s/secrets/db-secrets.yaml

# Verify secrets (don't decode in production!)
kubectl get secrets -n dhakacart
kubectl describe secret dhakacart-secrets -n dhakacart
```

#### **Step 3: Apply ConfigMaps**

```bash
kubectl apply -f k8s/configmaps/app-config.yaml
kubectl apply -f k8s/configmaps/postgres-init.yaml

# Verify ConfigMaps
kubectl get configmaps -n dhakacart
kubectl describe configmap dhakacart-config -n dhakacart
``` 

#### **Step 3.5: Apply Security Policies** (Recommended)
```bash
if [ -d "k8s/security/network-policies" ]; then
    kubectl apply -f k8s/security/network-policies/
    echo "Security policies applied."
fi
# Verify
kubectl get networkpolicies -n dhakacart
```

#### **Step 4: Create Persistent Volume Claims**

```bash
kubectl apply -f k8s/volumes/pvc.yaml

# Verify PVCs
kubectl get pvc -n dhakacart
kubectl describe pvc postgres-pvc -n dhakacart
kubectl describe pvc redis-pvc -n dhakacart
```

#### **Step 5: Deploy Database (PostgreSQL)**

```bash
kubectl apply -f k8s/deployments/postgres-deployment.yaml

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l app=dhakacart-db -n dhakacart --timeout=120s

# Check database pod
kubectl get pods -n dhakacart -l app=dhakacart-db
```

#### **Step 6: Deploy Cache (Redis)**

```bash
kubectl apply -f k8s/deployments/redis-deployment.yaml

# Wait for Redis to be ready
kubectl wait --for=condition=ready pod -l app=dhakacart-redis -n dhakacart --timeout=120s

# Check Redis pod
kubectl get pods -n dhakacart -l app=dhakacart-redis
```

#### **Step 7: Create Services**

```bash
kubectl apply -f k8s/services/services.yaml

# Verify all services
kubectl get svc -n dhakacart

# Check service details
kubectl describe svc dhakacart-db-service -n dhakacart
kubectl describe svc dhakacart-redis-service -n dhakacart
kubectl describe svc dhakacart-backend-service -n dhakacart
kubectl describe svc dhakacart-frontend-service -n dhakacart
```

#### **Step 8: Deploy Backend Application**

```bash
kubectl apply -f k8s/deployments/backend-deployment.yaml

# Wait for backend pods to be ready
kubectl wait --for=condition=ready pod -l app=dhakacart-backend -n dhakacart --timeout=180s

# Check backend pods (should see 3 replicas)
kubectl get pods -n dhakacart -l app=dhakacart-backend
```

#### **Step 9: Deploy Frontend Application**

```bash
kubectl apply -f k8s/deployments/frontend-deployment.yaml

# Wait for frontend pods to be ready
kubectl wait --for=condition=ready pod -l app=dhakacart-frontend -n dhakacart --timeout=180s

# Check frontend pods (should see 2 replicas)
kubectl get pods -n dhakacart -l app=dhakacart-frontend
```

#### **Step 10: Apply Horizontal Pod Autoscaler (HPA)**

```bash
kubectl apply -f k8s/hpa.yaml

# Verify HPA
kubectl get hpa -n dhakacart
kubectl describe hpa dhakacart-backend-hpa -n dhakacart
kubectl describe hpa dhakacart-frontend-hpa -n dhakacart
```

#### **Step 11: Apply Ingress (Optional - requires Ingress Controller)**

```bash
# First install NGINX Ingress Controller (see Detailed Setup section)
# Then apply ingress rules
kubectl apply -f k8s/ingress/ingress.yaml

# Verify ingress
kubectl get ingress -n dhakacart
kubectl describe ingress dhakacart-ingress -n dhakacart
```

---

## ✅ Verification Commands

### **Check All Resources**

```bash
# Get all resources in dhakacart namespace
kubectl get all -n dhakacart

# Watch all pods
kubectl get pods -n dhakacart -w
```

**Expected Output:**
```
NAME                                      READY   STATUS    RESTARTS   AGE
pod/dhakacart-backend-xxx                 1/1     Running   0          5m
pod/dhakacart-backend-xxx                 1/1     Running   0          5m
pod/dhakacart-backend-xxx                 1/1     Running   0          5m
pod/dhakacart-db-xxx                      1/1     Running   0          7m
pod/dhakacart-frontend-xxx                1/1     Running   0          4m
pod/dhakacart-frontend-xxx                1/1     Running   0          4m
pod/dhakacart-redis-xxx                   1/1     Running   0          6m

NAME                                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
service/dhakacart-backend-service        ClusterIP   10.100.200.50    <none>        5000/TCP   6m
service/dhakacart-db-service             ClusterIP   10.100.200.51    <none>        5432/TCP   7m
service/dhakacart-frontend-service       ClusterIP   10.100.200.52    <none>        80/TCP     5m
service/dhakacart-redis-service          ClusterIP   10.100.200.53    <none>        6379/TCP   6m

NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/dhakacart-backend    3/3     3            3           5m
deployment.apps/dhakacart-db         1/1     1            1           7m
deployment.apps/dhakacart-frontend   2/2     2            2           4m
deployment.apps/dhakacart-redis      1/1     1            1           6m

NAME                                            DESIRED   CURRENT   READY   AGE
replicaset.apps/dhakacart-backend-xxx           3         3         3       5m
replicaset.apps/dhakacart-db-xxx                1         1         1       7m
replicaset.apps/dhakacart-frontend-xxx          2         2         2       4m
replicaset.apps/dhakacart-redis-xxx             1         1         1       6m

NAME                                                REFERENCE                      TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/dhakacart-backend-hpa    Deployment/dhakacart-backend   50%/70%, 60%/80%   3         10        3          3m
horizontalpodautoscaler.autoscaling/dhakacart-frontend-hpa   Deployment/dhakacart-frontend  45%/70%, 55%/80%   2         8         2          3m
```

### **Verify Each Component**

```bash
# 1. Check Namespace
kubectl get namespace dhakacart

# 2. Check Secrets
kubectl get secrets -n dhakacart

# 3. Check ConfigMaps
kubectl get configmaps -n dhakacart

# 4. Check PersistentVolumeClaims
kubectl get pvc -n dhakacart

# 5. Check Deployments
kubectl get deployments -n dhakacart

# 6. Check Pods
kubectl get pods -n dhakacart -o wide

# 7. Check Services
kubectl get svc -n dhakacart

# 8. Check HPA
kubectl get hpa -n dhakacart

# 9. Check Ingress (if applied)
kubectl get ingress -n dhakacart

# 10. Check Events
kubectl get events -n dhakacart --sort-by='.lastTimestamp' | tail -20
```

---

## 🔍 Port-Forwarding for Testing

### **Access Frontend**

```bash
# Forward frontend service (runs in foreground)
kubectl port-forward -n dhakacart svc/dhakacart-frontend-service 3000:80

# Or run in background
kubectl port-forward -n dhakacart svc/dhakacart-frontend-service 3000:80 &

# Access in browser
# http://localhost:3000
```

### **Access Backend API**

```bash
# Forward backend service
kubectl port-forward -n dhakacart svc/dhakacart-backend-service 5000:5000

# Test backend health endpoint
curl http://localhost:5000/health
curl http://localhost:5000/api/products

# Or use httpie
http http://localhost:5000/health
```

### **Access Database (PostgreSQL)**

```bash
# Forward database service
kubectl port-forward -n dhakacart svc/dhakacart-db-service 5432:5432

# Connect with psql
psql -h localhost -p 5432 -U dhakacart -d dhakacart
# Password: dhakacart123
```

### **Access Redis**

```bash
# Forward Redis service
kubectl port-forward -n dhakacart svc/dhakacart-redis-service 6379:6379

# Connect with redis-cli
redis-cli -h localhost -p 6379
```

### **Stop Port-Forwarding**

```bash
# Find and kill port-forward processes
ps aux | grep port-forward
kill <PID>

# Or kill all port-forwards
pkill -f "port-forward"
```

---

## 📦 Detailed Setup

### **1. Install NGINX Ingress Controller**

```bash
# For cloud providers (AWS, GCP, Azure, DigitalOcean)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

# For Minikube
minikube addons enable ingress

# For bare-metal
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/baremetal/deploy.yaml

# Wait for ingress controller to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Verify ingress controller
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### **2. Get LoadBalancer IP/External IP**

```bash
# Get the external IP of ingress controller
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Wait for external IP to be assigned
kubectl get svc -n ingress-nginx ingress-nginx-controller --watch

# Save the external IP
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "External IP: $EXTERNAL_IP"
```

### **3. Install Cert-Manager (for SSL/TLS)**

```bash
# Install cert-manager using kubectl
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=120s

# Verify cert-manager installation
kubectl get pods -n cert-manager

# Create Let's Encrypt ClusterIssuer for production
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@dhakacart.com  # Change this!
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Create Let's Encrypt ClusterIssuer for staging (testing)
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: your-email@dhakacart.com  # Change this!
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Verify ClusterIssuers
kubectl get clusterissuer
```

### **4. Configure DNS Records**

Point your domain to the LoadBalancer IP:

```bash
# Get the LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Add these DNS A records in your domain registrar:
# Record Type: A
# Name: @              → Value: <LoadBalancer-IP>  (dhakacart.com)
# Name: www            → Value: <LoadBalancer-IP>  (www.dhakacart.com)
# Name: api            → Value: <LoadBalancer-IP>  (api.dhakacart.com)

# Verify DNS propagation (wait 5-10 minutes after adding records)
nslookup dhakacart.com
nslookup www.dhakacart.com
nslookup api.dhakacart.com

# Or use dig
dig dhakacart.com
dig www.dhakacart.com
dig api.dhakacart.com
```

### **5. Apply Ingress Rules**

```bash
# Apply ingress configuration
kubectl apply -f k8s/ingress/ingress.yaml

# Verify ingress
kubectl get ingress -n dhakacart
kubectl describe ingress dhakacart-ingress -n dhakacart

# Check certificate status (if using cert-manager)
kubectl get certificate -n dhakacart
kubectl describe certificate dhakacart-tls -n dhakacart

# Check certificate request
kubectl get certificaterequest -n dhakacart
```

### **6. Test Access**

```bash
# Test frontend (after DNS is configured)
curl -I https://dhakacart.com
curl -I https://www.dhakacart.com

# Test backend API
curl https://api.dhakacart.com/health
curl https://api.dhakacart.com/api/products

# Open in browser
xdg-open https://dhakacart.com  # Linux
open https://dhakacart.com      # macOS
```

---

## 🔍 Complete Verification Checklist

### Database

```bash
# Check if database is running
kubectl get pods -n dhakacart -l app=dhakacart-db

# Check logs
kubectl logs -n dhakacart -l app=dhakacart-db

# Connect to database
kubectl exec -it -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-db -o jsonpath='{.items[0].metadata.name}') -- psql -U dhakacart -d dhakacart

# Run query
\dt
SELECT COUNT(*) FROM products;
\q
```

### Redis

```bash
# Check if Redis is running
kubectl get pods -n dhakacart -l app=dhakacart-redis

# Test Redis
kubectl exec -it -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-redis -o jsonpath='{.items[0].metadata.name}') -- redis-cli ping
```

### Backend

```bash
# Check backend pods
kubectl get pods -n dhakacart -l app=dhakacart-backend

# Check logs
kubectl logs -n dhakacart -l app=dhakacart-backend --tail=50

# Test health endpoint
kubectl exec -it -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-backend -o jsonpath='{.items[0].metadata.name}') -- curl localhost:5000/health
```

### Frontend

```bash
# Check frontend pods
kubectl get pods -n dhakacart -l app=dhakacart-frontend

# Check logs
kubectl logs -n dhakacart -l app=dhakacart-frontend --tail=50
```

---

## 📊 Monitoring & Management

### **Check Logs**

```bash
# View logs for all backend pods
kubectl logs -n dhakacart -l app=dhakacart-backend

# Follow logs in real-time
kubectl logs -n dhakacart -l app=dhakacart-backend -f

# Get logs from specific pod
kubectl logs -n dhakacart <pod-name>

# Get logs from previous crashed container
kubectl logs -n dhakacart <pod-name> --previous

# Tail last 50 lines
kubectl logs -n dhakacart <pod-name> --tail=50

# View logs with timestamps
kubectl logs -n dhakacart <pod-name> --timestamps

# Logs from all containers in a pod
kubectl logs -n dhakacart <pod-name> --all-containers

# Database logs
kubectl logs -n dhakacart -l app=dhakacart-db --tail=100

# Redis logs
kubectl logs -n dhakacart -l app=dhakacart-redis --tail=100

# Frontend logs
kubectl logs -n dhakacart -l app=dhakacart-frontend --tail=100
```

### **Execute Commands in Pods**

```bash
# Get shell access to backend pod
kubectl exec -it -n dhakacart <backend-pod-name> -- sh

# Execute single command
kubectl exec -n dhakacart <pod-name> -- ls -la

# Connect to PostgreSQL database
kubectl exec -it -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-db -o jsonpath='{.items[0].metadata.name}') -- psql -U dhakacart -d dhakacart

# Inside PostgreSQL
\dt                              # List tables
\d products                      # Describe products table
SELECT COUNT(*) FROM products;   # Count products
SELECT * FROM products LIMIT 5;  # Get 5 products
\q                               # Exit

# Connect to Redis
kubectl exec -it -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-redis -o jsonpath='{.items[0].metadata.name}') -- redis-cli

# Inside Redis
PING                # Test connection
KEYS *              # List all keys
GET <key>           # Get value
INFO                # Redis info
EXIT                # Exit
```

### **Resource Usage & Monitoring**

```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods -n dhakacart

# Sort by CPU
kubectl top pods -n dhakacart --sort-by=cpu

# Sort by memory
kubectl top pods -n dhakacart --sort-by=memory

# Get detailed resource information
kubectl describe nodes

# Check resource limits and requests
kubectl get pods -n dhakacart -o=custom-columns=NAME:.metadata.name,CPU_REQUEST:.spec.containers[*].resources.requests.cpu,CPU_LIMIT:.spec.containers[*].resources.limits.cpu,MEMORY_REQUEST:.spec.containers[*].resources.requests.memory,MEMORY_LIMIT:.spec.containers[*].resources.limits.memory
```

### **Manual Scaling**

```bash
# Scale backend deployment
kubectl scale deployment dhakacart-backend -n dhakacart --replicas=5

# Scale frontend deployment
kubectl scale deployment dhakacart-frontend -n dhakacart --replicas=4

# Scale down
kubectl scale deployment dhakacart-backend -n dhakacart --replicas=2

# Check scaling status
kubectl get deployments -n dhakacart
kubectl get pods -n dhakacart
```

### **Auto-Scaling (HPA)**

```bash
# Check HPA status
kubectl get hpa -n dhakacart

# Detailed HPA information
kubectl describe hpa dhakacart-backend-hpa -n dhakacart
kubectl describe hpa dhakacart-frontend-hpa -n dhakacart

# Watch HPA in real-time
kubectl get hpa -n dhakacart -w

# Edit HPA (change min/max replicas, CPU threshold)
kubectl edit hpa dhakacart-backend-hpa -n dhakacart

# HPA configurations:
# Backend: min=3, max=10, CPU=70%, Memory=80%
# Frontend: min=2, max=8, CPU=70%, Memory=80%
```

### **Updates & Rolling Updates**

```bash
# Update backend to new version
kubectl set image deployment/dhakacart-backend -n dhakacart backend=arifhossaincse22/dhakacart-backend:v1.0.2

# Update frontend to new version
kubectl set image deployment/dhakacart-frontend -n dhakacart frontend=arifhossaincse22/dhakacart-frontend:v1.0.2

# Watch rollout progress
kubectl rollout status deployment/dhakacart-backend -n dhakacart
kubectl rollout status deployment/dhakacart-frontend -n dhakacart

# Pause rollout
kubectl rollout pause deployment/dhakacart-backend -n dhakacart

# Resume rollout
kubectl rollout resume deployment/dhakacart-backend -n dhakacart

# Check rollout history
kubectl rollout history deployment/dhakacart-backend -n dhakacart
kubectl rollout history deployment/dhakacart-frontend -n dhakacart

# View specific revision
kubectl rollout history deployment/dhakacart-backend -n dhakacart --revision=2
```

### **Rollback Deployments**

```bash
# Rollback backend to previous version
kubectl rollout undo deployment/dhakacart-backend -n dhakacart

# Rollback frontend to previous version
kubectl rollout undo deployment/dhakacart-frontend -n dhakacart

# Rollback to specific revision
kubectl rollout undo deployment/dhakacart-backend -n dhakacart --to-revision=2

# Check rollback status
kubectl rollout status deployment/dhakacart-backend -n dhakacart
```

### **Restart Deployments**

```bash
# Restart backend deployment (zero-downtime)
kubectl rollout restart deployment/dhakacart-backend -n dhakacart

# Restart frontend deployment
kubectl rollout restart deployment/dhakacart-frontend -n dhakacart

# Restart all deployments
kubectl rollout restart deployment -n dhakacart

# Delete and recreate pod (not recommended for production)
kubectl delete pod <pod-name> -n dhakacart
```

### **Watch Events**

```bash
# Watch all events in dhakacart namespace
kubectl get events -n dhakacart --watch

# Get recent events sorted by time
kubectl get events -n dhakacart --sort-by='.lastTimestamp' | tail -20

# Filter warning events only
kubectl get events -n dhakacart --field-selector type=Warning

# Filter normal events
kubectl get events -n dhakacart --field-selector type=Normal

# Events for specific pod
kubectl get events -n dhakacart --field-selector involvedObject.name=<pod-name>
```

### **Describe Resources**

```bash
# Describe namespace
kubectl describe namespace dhakacart

# Describe deployments
kubectl describe deployment dhakacart-backend -n dhakacart
kubectl describe deployment dhakacart-frontend -n dhakacart
kubectl describe deployment dhakacart-db -n dhakacart
kubectl describe deployment dhakacart-redis -n dhakacart

# Describe services
kubectl describe svc dhakacart-backend-service -n dhakacart
kubectl describe svc dhakacart-frontend-service -n dhakacart

# Describe pods
kubectl describe pod <pod-name> -n dhakacart

# Describe HPA
kubectl describe hpa -n dhakacart

# Describe ingress
kubectl describe ingress dhakacart-ingress -n dhakacart
```

---

## 🔧 Troubleshooting

### **Common Issues & Solutions**

#### **1. Pods Not Starting / CrashLoopBackOff**

```bash
# Check pod status
kubectl get pods -n dhakacart
kubectl describe pod <pod-name> -n dhakacart

# Check logs
kubectl logs <pod-name> -n dhakacart
kubectl logs <pod-name> -n dhakacart --previous  # Previous crashed container

# Common causes:
# - Image pull errors: Check image name and registry access
# - Resource limits: Check if pod is being OOMKilled
# - Configuration errors: Check environment variables and secrets
# - Health check failures: Verify liveness/readiness probes

# Check events
kubectl get events -n dhakacart --field-selector involvedObject.name=<pod-name>

# Debug with a temporary pod
kubectl run debug-pod -n dhakacart --image=busybox --rm -it -- sh
```

#### **2. Image Pull Errors (ImagePullBackOff, ErrImagePull)**

```bash
# Check image details in pod
kubectl describe pod <pod-name> -n dhakacart | grep -A 5 "Events:"

# Verify image exists
docker pull arifhossaincse22/dhakacart-backend:v1.0.0
docker pull arifhossaincse22/dhakacart-frontend:v1.0.1

# Check image pull policy
kubectl get deployment dhakacart-backend -n dhakacart -o yaml | grep imagePullPolicy

# If using private registry, create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=<your-registry-server> \
  --docker-username=<your-username> \
  --docker-password=<your-password> \
  --docker-email=<your-email> \
  -n dhakacart

# Add secret to deployment
kubectl patch serviceaccount default -n dhakacart -p '{"imagePullSecrets": [{"name": "regcred"}]}'
```

#### **3. Database Connection Issues**

```bash
# Check if database pod is running
kubectl get pods -n dhakacart -l app=dhakacart-db

# Check database logs
kubectl logs -n dhakacart -l app=dhakacart-db --tail=50

# Test database connectivity from backend pod
kubectl exec -it -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-backend -o jsonpath='{.items[0].metadata.name}') -- sh

# Inside backend container
nc -zv dhakacart-db-service 5432
ping dhakacart-db-service
nslookup dhakacart-db-service
env | grep DB_  # Check environment variables
exit

# Check database service and endpoints
kubectl get svc dhakacart-db-service -n dhakacart
kubectl get endpoints dhakacart-db-service -n dhakacart
kubectl describe svc dhakacart-db-service -n dhakacart

# Verify database credentials
kubectl get secret dhakacart-secrets -n dhakacart -o yaml
kubectl get secret dhakacart-secrets -n dhakacart -o jsonpath='{.data.DB_USER}' | base64 -d
kubectl get secret dhakacart-secrets -n dhakacart -o jsonpath='{.data.DB_PASSWORD}' | base64 -d

# Connect directly to database
kubectl exec -it -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-db -o jsonpath='{.items[0].metadata.name}') -- psql -U dhakacart -d dhakacart -c "SELECT version();"
```

#### **4. Redis Connection Issues**

```bash
# Check if Redis pod is running
kubectl get pods -n dhakacart -l app=dhakacart-redis

# Check Redis logs
kubectl logs -n dhakacart -l app=dhakacart-redis --tail=50

# Test Redis connectivity
kubectl exec -it -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-redis -o jsonpath='{.items[0].metadata.name}') -- redis-cli ping

# Test from backend pod
kubectl exec -it -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-backend -o jsonpath='{.items[0].metadata.name}') -- sh
nc -zv dhakacart-redis-service 6379
exit

# Check Redis service
kubectl get svc dhakacart-redis-service -n dhakacart
kubectl get endpoints dhakacart-redis-service -n dhakacart
```

#### **5. Service Not Accessible**

```bash
# Check all services
kubectl get svc -n dhakacart

# Check service endpoints (should have IPs listed)
kubectl get endpoints -n dhakacart

# Describe service
kubectl describe svc dhakacart-backend-service -n dhakacart

# Verify service selector matches pod labels
kubectl get svc dhakacart-backend-service -n dhakacart -o yaml | grep selector -A 5
kubectl get pods -n dhakacart -l app=dhakacart-backend --show-labels

# Test service from inside cluster
kubectl run test-pod -n dhakacart --image=curlimages/curl --rm -it -- sh
curl http://dhakacart-backend-service:5000/health
curl http://dhakacart-frontend-service:80
exit
```

#### **6. Ingress Not Working**

```bash
# Check ingress status
kubectl get ingress -n dhakacart
kubectl describe ingress dhakacart-ingress -n dhakacart

# Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Get ingress controller service
kubectl get svc -n ingress-nginx

# Verify DNS resolution
nslookup dhakacart.com
dig dhakacart.com

# Test with curl (bypassing DNS)
curl -H "Host: dhakacart.com" http://<EXTERNAL-IP>

# Check TLS certificate
kubectl get certificate -n dhakacart
kubectl describe certificate dhakacart-tls -n dhakacart

# Check cert-manager logs
kubectl logs -n cert-manager -l app=cert-manager
```

#### **7. High Resource Usage / OOMKilled**

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n dhakacart --sort-by=memory
kubectl top pods -n dhakacart --sort-by=cpu

# Check for OOMKilled pods
kubectl get pods -n dhakacart | grep OOMKilled

# Describe pod to see resource limits
kubectl describe pod <pod-name> -n dhakacart | grep -A 10 "Limits:"

# Increase resource limits (edit deployment)
kubectl edit deployment dhakacart-backend -n dhakacart

# Or patch deployment
kubectl patch deployment dhakacart-backend -n dhakacart -p '{"spec":{"template":{"spec":{"containers":[{"name":"backend","resources":{"limits":{"memory":"1Gi","cpu":"1000m"}}}]}}}}'
```

#### **8. PersistentVolumeClaim (PVC) Issues**

```bash
# Check PVC status
kubectl get pvc -n dhakacart

# Describe PVC
kubectl describe pvc postgres-pvc -n dhakacart
kubectl describe pvc redis-pvc -n dhakacart

# Check PV (Persistent Volume)
kubectl get pv

# Check storage class
kubectl get storageclass

# If PVC is pending, check events
kubectl get events -n dhakacart --field-selector involvedObject.kind=PersistentVolumeClaim
```

#### **9. ConfigMap / Secret Issues**

```bash
# Check if ConfigMaps exist
kubectl get configmap -n dhakacart

# View ConfigMap contents
kubectl get configmap dhakacart-config -n dhakacart -o yaml

# Check if Secrets exist
kubectl get secrets -n dhakacart

# Verify secret is mounted in pod
kubectl describe pod <pod-name> -n dhakacart | grep -A 10 "Mounts:"

# Check environment variables in running pod
kubectl exec -n dhakacart <pod-name> -- env | sort
```

#### **10. HPA Not Scaling**

```bash
# Check HPA status
kubectl get hpa -n dhakacart
kubectl describe hpa dhakacart-backend-hpa -n dhakacart

# Check if metrics-server is running
kubectl get deployment metrics-server -n kube-system

# Install metrics-server if missing
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Generate load to test autoscaling
kubectl run load-generator -n dhakacart --image=busybox --rm -it -- /bin/sh -c "while true; do wget -q -O- http://dhakacart-backend-service:5000/health; done"

# Watch HPA scale up
kubectl get hpa -n dhakacart -w
```

### **General Debugging Commands**

```bash
# Get all resources in namespace
kubectl get all -n dhakacart

# Get all events (sorted by time)
kubectl get events -n dhakacart --sort-by='.lastTimestamp'

# Get warning events
kubectl get events -n dhakacart --field-selector type=Warning

# Export all configurations
kubectl get all -n dhakacart -o yaml > dhakacart-backup.yaml

# Check cluster info
kubectl cluster-info
kubectl cluster-info dump

# Check node status
kubectl get nodes -o wide
kubectl describe node <node-name>

# Check API resources
kubectl api-resources

# Validate YAML files before applying
kubectl apply -f k8s/deployments/backend-deployment.yaml --dry-run=client
kubectl apply -f k8s/deployments/backend-deployment.yaml --dry-run=server
```

---

## 🗑️ Cleanup & Removal

### **Remove Entire Application**

```bash
# Delete entire namespace (removes all resources inside)
kubectl delete namespace dhakacart

# This deletes:
# - All deployments
# - All pods
# - All services
# - All ConfigMaps
# - All secrets
# - All PVCs (and associated PVs)
# - All ingress rules
# - All HPAs
```

### **Remove Individual Components**

```bash
# Delete deployments
kubectl delete -f k8s/deployments/backend-deployment.yaml
kubectl delete -f k8s/deployments/frontend-deployment.yaml
kubectl delete -f k8s/deployments/postgres-deployment.yaml
kubectl delete -f k8s/deployments/redis-deployment.yaml

# Delete services
kubectl delete -f k8s/services/services.yaml

# Delete HPA
kubectl delete -f k8s/hpa.yaml

# Delete ingress
kubectl delete -f k8s/ingress/ingress.yaml

# Delete PVCs (WARNING: This deletes data!)
kubectl delete -f k8s/volumes/pvc.yaml

# Delete ConfigMaps
kubectl delete -f k8s/configmaps/app-config.yaml
kubectl delete -f k8s/configmaps/postgres-init.yaml

# Delete secrets
kubectl delete -f k8s/secrets/db-secrets.yaml

# Delete namespace
kubectl delete -f k8s/namespace.yaml
```

### **Delete by Label**

```bash
# Delete all backend resources
kubectl delete all -n dhakacart -l app=dhakacart-backend

# Delete all frontend resources
kubectl delete all -n dhakacart -l app=dhakacart-frontend

# Delete all database resources
kubectl delete all -n dhakacart -l app=dhakacart-db

# Delete all redis resources
kubectl delete all -n dhakacart -l app=dhakacart-redis
```

### **Force Delete Stuck Resources**

```bash
# Force delete pod
kubectl delete pod <pod-name> -n dhakacart --grace-period=0 --force

# Force delete namespace (if stuck in terminating state)
kubectl get namespace dhakacart -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/dhakacart/finalize" -f -

# Delete PVC with finalizers
kubectl patch pvc postgres-pvc -n dhakacart -p '{"metadata":{"finalizers":null}}'
```

### **Clean Up External Resources**

```bash
# Remove ingress controller (if installed)
kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

# Remove cert-manager (if installed)
kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# Delete ClusterIssuers
kubectl delete clusterissuer letsencrypt-prod
kubectl delete clusterissuer letsencrypt-staging
```

---

## 📦 Backup & Restore

### **Backup Database**

```bash
# Backup PostgreSQL database
kubectl exec -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-db -o jsonpath='{.items[0].metadata.name}') -- pg_dump -U dhakacart dhakacart > dhakacart_backup_$(date +%Y%m%d).sql

# Backup with custom format (compressed)
kubectl exec -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-db -o jsonpath='{.items[0].metadata.name}') -- pg_dump -U dhakacart -Fc dhakacart > dhakacart_backup_$(date +%Y%m%d).dump

# Copy backup from pod to local
kubectl cp dhakacart/<db-pod-name>:/backup/dhakacart.sql ./dhakacart_backup.sql
```

### **Restore Database**

```bash
# Restore from SQL file
cat dhakacart_backup.sql | kubectl exec -i -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-db -o jsonpath='{.items[0].metadata.name}') -- psql -U dhakacart dhakacart

# Restore from dump file
kubectl exec -i -n dhakacart $(kubectl get pod -n dhakacart -l app=dhakacart-db -o jsonpath='{.items[0].metadata.name}') -- pg_restore -U dhakacart -d dhakacart < dhakacart_backup.dump
```

### **Export All Kubernetes Configurations**

```bash
# Export all resources
kubectl get all -n dhakacart -o yaml > dhakacart-all-resources.yaml

# Export specific resources
kubectl get deployment -n dhakacart -o yaml > deployments-backup.yaml
kubectl get svc -n dhakacart -o yaml > services-backup.yaml
kubectl get configmap -n dhakacart -o yaml > configmaps-backup.yaml
kubectl get secret -n dhakacart -o yaml > secrets-backup.yaml
kubectl get pvc -n dhakacart -o yaml > pvc-backup.yaml
```

---

## 📋 Production Checklist

### **Before Deploying to Production:**

- [ ] **Security**
  - [ ] Change default database password in secrets
  - [ ] Use Sealed Secrets or External Secrets Operator
  - [ ] Enable RBAC and create service accounts
  - [ ] Configure Network Policies
  - [ ] Scan images for vulnerabilities (Trivy, Snyk)
  - [ ] Enable Pod Security Standards
  - [ ] Use private container registry

- [ ] **SSL/TLS & Domain**
  - [ ] Configure proper domain names
  - [ ] Set up SSL/TLS certificates (Let's Encrypt)
  - [ ] Force HTTPS redirect
  - [ ] Configure CORS properly

- [ ] **High Availability**
  - [ ] Run multiple replicas of stateless services
  - [ ] Configure Pod Disruption Budgets
  - [ ] Set up database replication (if needed)
  - [ ] Configure Redis in cluster mode (if needed)
  - [ ] Use multiple availability zones

- [ ] **Monitoring & Logging**
  - [ ] Set up Prometheus + Grafana
  - [ ] Configure centralized logging (ELK, Loki)
  - [ ] Set up alerting (AlertManager, PagerDuty)
  - [ ] Monitor resource usage
  - [ ] Set up uptime monitoring

- [ ] **Backup & Recovery**
  - [ ] Configure automated database backups
  - [ ] Set up Velero for cluster backups
  - [ ] Test restore procedures
  - [ ] Document disaster recovery plan
  - [ ] Store backups in different region

- [ ] **Resource Management**
  - [ ] Configure appropriate resource requests/limits
  - [ ] Set up Horizontal Pod Autoscaler (HPA)
  - [ ] Configure Vertical Pod Autoscaler (if needed)
  - [ ] Set up Cluster Autoscaler

- [ ] **CI/CD**
  - [ ] Set up automated deployment pipeline
  - [ ] Implement automated testing
  - [ ] Configure rolling updates
  - [ ] Set up canary deployments (optional)
  - [ ] Implement blue-green deployments (optional)

- [ ] **Performance**
  - [ ] Load test the application
  - [ ] Configure CDN for static assets
  - [ ] Optimize database queries
  - [ ] Configure Redis caching
  - [ ] Enable HTTP/2

- [ ] **Compliance & Documentation**
  - [ ] Document deployment procedures
  - [ ] Create runbooks for common issues
  - [ ] Set up change management process
  - [ ] Ensure compliance requirements are met
  - [ ] Document architecture diagrams

---

## 🚀 Advanced Configuration

### **Install Metrics Server**

```bash
# Install metrics-server (required for HPA and kubectl top)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For minikube
minikube addons enable metrics-server

# Verify
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
```

### **Install Prometheus & Grafana (Monitoring)**

```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus + Grafana
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Default credentials: admin / prom-operator
# Visit: http://localhost:3000
```

### **Configure Pod Disruption Budget**

```bash
# Create PDB for backend
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: dhakacart-backend-pdb
  namespace: dhakacart
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: dhakacart-backend
EOF

# Create PDB for frontend
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: dhakacart-frontend-pdb
  namespace: dhakacart
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: dhakacart-frontend
EOF

# Check PDBs
kubectl get pdb -n dhakacart
```

---

## 📚 Useful Commands Reference

```bash
# Quick status check
kubectl get all -n dhakacart
kubectl get pods -n dhakacart -o wide
kubectl top pods -n dhakacart

# Watch resources in real-time
watch kubectl get pods -n dhakacart

# Get pod logs
kubectl logs -n dhakacart -l app=dhakacart-backend -f --tail=100

# Shell into pod
kubectl exec -it -n dhakacart <pod-name> -- /bin/sh

# Copy files to/from pod
kubectl cp local-file.txt dhakacart/<pod-name>:/path/in/container
kubectl cp dhakacart/<pod-name>:/path/in/container/file.txt ./local-file.txt

# Port forward multiple services (different terminals)
kubectl port-forward -n dhakacart svc/dhakacart-frontend-service 3000:80
kubectl port-forward -n dhakacart svc/dhakacart-backend-service 5000:5000
kubectl port-forward -n dhakacart svc/dhakacart-db-service 5432:5432

# Check resource quotas
kubectl get resourcequota -n dhakacart
kubectl describe resourcequota -n dhakacart

# View cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Get API versions
kubectl api-versions

# Explain resources
kubectl explain pod
kubectl explain deployment.spec
```

---

## 🎯 Quick Reference Card

| **Task** | **Command** |
|----------|-------------|
| Deploy everything | `kubectl apply -f k8s/ --recursive` |
| Check all pods | `kubectl get pods -n dhakacart` |
| Check all services | `kubectl get svc -n dhakacart` |
| View logs | `kubectl logs -n dhakacart -l app=dhakacart-backend -f` |
| Shell into pod | `kubectl exec -it -n dhakacart <pod> -- sh` |
| Port forward frontend | `kubectl port-forward -n dhakacart svc/dhakacart-frontend-service 3000:80` |
| Port forward backend | `kubectl port-forward -n dhakacart svc/dhakacart-backend-service 5000:5000` |
| Scale deployment | `kubectl scale deployment dhakacart-backend -n dhakacart --replicas=5` |
| Update image | `kubectl set image deployment/dhakacart-backend -n dhakacart backend=image:tag` |
| Rollback deployment | `kubectl rollout undo deployment/dhakacart-backend -n dhakacart` |
| Check HPA | `kubectl get hpa -n dhakacart` |
| Check resource usage | `kubectl top pods -n dhakacart` |
| Delete everything | `kubectl delete namespace dhakacart` |

---

## 🔗 Additional Resources

- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **kubectl Cheat Sheet**: https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **Kubernetes Best Practices**: https://kubernetes.io/docs/concepts/configuration/overview/
- **NGINX Ingress Controller**: https://kubernetes.github.io/ingress-nginx/
- **Cert-Manager**: https://cert-manager.io/docs/
- **Prometheus Operator**: https://github.com/prometheus-operator/prometheus-operator

---

## 📞 Support & Contact

For issues or questions about this deployment:
- Check the troubleshooting section above
- Review pod logs: `kubectl logs -n dhakacart <pod-name>`
- Check events: `kubectl get events -n dhakacart`
- Describe resources: `kubectl describe <resource-type> <resource-name> -n dhakacart`

---

**🎉 Congratulations! Your DhakaCart application is now running on Kubernetes!**

**Next Steps:**
1. Configure SSL/TLS with cert-manager
2. Set up monitoring with Prometheus & Grafana
3. Configure automated backups
4. Implement CI/CD pipeline
5. Load test your application
6. Set up alerting

---

*Last Updated: November 2025*  
*DhakaCart E-Commerce Platform - Kubernetes Deployment Guide*
