# 🔧 Load Balancer Path-Based Routing Setup

**Issue**: API calls (`/api/*`) returning HTML instead of JSON  
**Cause**: Load Balancer not routing `/api/*` to backend  
**Solution**: Configure ALB listener rules for path-based routing

---

## Current Problem

- Frontend URL: `http://LB_URL/` → Works ✅
- Backend API URL: `http://LB_URL/api/*` → Returns HTML (frontend) ❌
- Need: `/api/*` should route to backend service

---

## Solution: ALB Listener Rules (Path-Based Routing)

### Step 1: Create Backend Target Group

**AWS Console → EC2 → Target Groups:**

1. **Click "Create target group"**

2. **Basic configuration:**
   - Target type: **Instances**
   - Name: `dhakacart-k8s-backend-tg`
   - Protocol: **HTTP**
   - Port: **30081** (Backend NodePort)
   - VPC: Select your VPC

3. **Health checks:**
   - Protocol: HTTP
   - Path: `/health` or `/api/health` (check your backend health endpoint)
   - Port: `30081`
   - Healthy threshold: 2
   - Unhealthy threshold: 2
   - Timeout: 5 seconds
   - Interval: 30 seconds

4. **Click "Next" → "Create target group"**

---

### Step 2: Register Backend Targets

1. **Target group → "Targets" tab**

2. **Click "Register targets"**

3. **Select worker nodes:**
   - ✅ worker-1 (10.0.10.170) Port: `30081`
   - ✅ worker-2 (10.0.10.12) Port: `30081`
   - ✅ worker-3 (10.0.10.84) Port: `30081`

4. **Click "Register targets"**

5. **Wait 1-2 minutes** for health checks

---

### Step 3: Configure ALB Listener Rules

**AWS Console → EC2 → Load Balancers:**

1. **Select `dhakacart-k8s-alb-...`**

2. **"Listeners" tab → Listener (Port 80) → "View/edit rules"**

3. **Current rule structure:**
   ```
   Default action:
   └── Forward to: dhakacart-k8s-frontend-tg
   ```

4. **Add new rule (Move to top):**
   - Click "Insert rule" or "Add rule"
   - **IF (Conditions):**
     - Click "Add condition" → "Path"
     - Path is: `/api*` (matches `/api`, `/api/products`, etc.)
   - **THEN (Actions):**
     - Click "Add action" → "Forward to"
     - Select: `dhakacart-k8s-backend-tg`
     - Weight: 100

5. **Final rule order should be:**
   ```
   Rule 1 (Priority 1):
   ├── IF: Path is /api*
   └── THEN: Forward to dhakacart-k8s-backend-tg
   
   Default (Last):
   └── Forward to: dhakacart-k8s-frontend-tg
   ```

6. **Click "Save"**

---

### Step 4: Update Security Group

**AWS Console → EC2 → Security Groups:**

1. **Worker nodes security group → Inbound Rules**

2. **Add rule (if not exists):**
   - Type: Custom TCP
   - Port: `30081` (Backend NodePort)
   - Source: Load Balancer security group (or 0.0.0.0/0 for testing)
   - Description: "Allow backend NodePort from Load Balancer"

3. **Save rules**

---

## Verify Backend NodePort

**Master-1 এ:**

```bash
# Check backend service NodePort
kubectl get svc -n dhakacart dhakacart-backend-service

# Get NodePort number
BACKEND_NODEPORT=$(kubectl get svc -n dhakacart dhakacart-backend-service -o jsonpath='{.spec.ports[0].nodePort}')
echo "Backend NodePort: $BACKEND_NODEPORT"

# Test backend API directly
curl http://10.0.10.170:$BACKEND_NODEPORT/api/products | head -20
curl http://10.0.10.170:$BACKEND_NODEPORT/api/categories | head -20
```

**Expected:** JSON response (not HTML)

---

## Test Load Balancer Routing

### Test Frontend:
```bash
curl http://dhakacart-k8s-alb-1098869932.ap-southeast-1.elb.amazonaws.com/ | head -10
```
**Expected:** HTML (frontend page)

### Test Backend API:
```bash
curl http://dhakacart-k8s-alb-1098869932.ap-southeast-1.elb.amazonaws.com/api/products | head -20
curl http://dhakacart-k8s-alb-1098869932.ap-southeast-1.elb.amazonaws.com/api/categories | head -20
```
**Expected:** JSON response (API data)

---

## Troubleshooting

### Issue 1: Backend Returns 502

**Check:**
- Backend target group health checks passing?
- Worker nodes registered with correct port (30081)?
- Security group allows port 30081?

### Issue 2: Backend Returns HTML

**Check:**
- Listener rule path condition: `/api*` (with asterisk)
- Rule priority: Backend rule should be BEFORE default rule
- Backend target group points to correct NodePort (30081)

### Issue 3: Frontend Can't Load

**Check:**
- Default action still forwards to frontend target group
- Frontend target group is healthy

---

## Alternative: Simple Solution (If Path Routing Doesn't Work)

If ALB path routing is not available or too complex:

### Option A: Use Relative URLs

Update ConfigMap to use relative URL:
```yaml
REACT_APP_API_URL: "/api"
```

Then frontend will call: `http://LB_URL/api/*` (same domain)

But this still requires ALB path routing to work.

### Option B: Use Separate Subdomain

Configure DNS:
- Frontend: `app.dhakacart.com` → Frontend target group
- Backend: `api.dhakacart.com` → Backend target group

Update ConfigMap:
```yaml
REACT_APP_API_URL: "http://api.dhakacart.com"
```

---

## Complete Configuration Summary

### Frontend Service
- NodePort: `30080`
- Target Group: `dhakacart-k8s-frontend-tg`
- Listener Rule: Default (all other paths)

### Backend Service
- NodePort: `30081`
- Target Group: `dhakacart-k8s-backend-tg`
- Listener Rule: IF Path is `/api*` → Forward to backend

### ALB Listener Rules (Port 80)
```
Priority 1:
├── IF: Path is /api*
└── THEN: Forward to backend-tg (Port 30081)

Default (Last):
└── Forward to frontend-tg (Port 30080)
```

---

**Last Updated**: 2024-11-30  
**Status**: Configuration Guide ✅

