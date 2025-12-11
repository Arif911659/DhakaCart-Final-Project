# 🧪 লোকাল মেশিনে Testing Guide
**Date:** 2025-01-27  
**Purpose:** EC2-তে deploy করার আগে লোকালে test করুন

---

## ✅ যা করা হয়েছে

1. ✅ `docker-compose.yml` আপডেট - Production build (Nginx) ব্যবহার করবে
2. ✅ `nginx.conf` আপডেট - `backend:5000` (Docker network) ব্যবহার করবে
3. ✅ `App.js` আপডেট - Relative URL (`/api`) support

---

## 🚀 লোকালে Test করার Steps

### Step 1: Environment Variables Setup

`.env` file তৈরি করুন (যদি না থাকে):

```bash
cd /home/arif/DhakaCart-03
cat > .env <<EOF
NODE_ENV=development
PORT=5000
DB_HOST=database
DB_PORT=5432
DB_USER=dhakacart
DB_PASSWORD=dhakacart123
DB_NAME=dhakacart_db
REDIS_HOST=redis
REDIS_PORT=6379
EOF
```

### Step 2: Stop Existing Containers (যদি running থাকে)

```bash
docker-compose down
```

### Step 3: Build and Start Containers

```bash
# Build সব services (প্রথমবার)
docker-compose build

# Start সব services
docker-compose up -d

# Logs দেখুন
docker-compose logs -f
```

**Wait 30-60 seconds** services ready হতে।

### Step 4: Test করুন

**Browser-এ open করুন:**
```
http://localhost:3000
```

**Expected Result:**
- ✅ Frontend load হবে
- ✅ Products load হবে (no error!)
- ✅ Cart কাজ করবে

---

## 🔍 Verify Everything is Working

### Check Containers:
```bash
docker-compose ps
```

**Should show:**
- ✅ dhakacart-db (running)
- ✅ dhakacart-redis (running)
- ✅ dhakacart-backend (running)
- ✅ dhakacart-frontend (running)

### Check Backend:
```bash
# Health check
curl http://localhost:5000/health

# Products API
curl http://localhost:5000/api/products
```

### Check Frontend Nginx:
```bash
# Frontend directly
curl http://localhost:3000

# API through Nginx proxy
curl http://localhost:3000/api/products
```

**এই last command কাজ করলে** → Nginx proxy সঠিকভাবে কাজ করছে! ✅

---

## 🐛 Troubleshooting

### Issue 1: Frontend shows error

**Check:**
```bash
docker-compose logs frontend
```

**Fix:**
```bash
# Rebuild frontend
docker-compose build frontend
docker-compose up -d frontend
```

### Issue 2: Backend not responding

**Check:**
```bash
docker-compose logs backend
docker-compose logs database
```

**Fix:**
```bash
# Restart backend
docker-compose restart backend

# Check database
docker-compose exec database psql -U dhakacart -d dhakacart_db -c "SELECT COUNT(*) FROM products;"
```

### Issue 3: Port already in use

**Fix:**
```bash
# Find what's using the port
sudo lsof -i :3000
sudo lsof -i :5000

# Kill the process or change port in docker-compose.yml
```

---

## 📊 How It Works Locally

```
Your Browser
    │
    ▼
http://localhost:3000
    │
    ▼
Frontend Container (Nginx on port 80)
    │
    ├─ / → Serve React app (static files)
    │
    └─ /api/products → Proxy to backend:5000/api/products
                          │
                          ▼
                    Backend Container
                          │
                          ├─→ Database Container
                          └─→ Redis Container
```

**সব কিছু Docker network-এ!** ✅

---

## ✅ Success Criteria

লোকালে test successful হবে যদি:

1. ✅ `http://localhost:3000` open হলে frontend দেখাবে
2. ✅ Products load হবে (no error message)
3. ✅ `curl http://localhost:3000/api/products` JSON return করবে
4. ✅ Cart add/remove কাজ করবে
5. ✅ Checkout কাজ করবে

---

## 🚀 After Local Testing

লোকালে সব কাজ করলে:

1. ✅ Frontend image rebuild করুন (production):
   ```bash
   cd frontend
   docker build --target production -t arifhossaincse22/dhakacart-frontend:latest .
   docker push arifhossaincse22/dhakacart-frontend:latest
   ```

2. ✅ EC2-তে deploy করুন:
   ```bash
   cd terraform
   terraform apply
   ```

---

## 📝 Quick Commands

```bash
# Start everything
docker-compose up -d

# View logs
docker-compose logs -f

# Stop everything
docker-compose down

# Rebuild specific service
docker-compose build frontend
docker-compose up -d frontend

# Check status
docker-compose ps

# Test API
curl http://localhost:5000/api/products
curl http://localhost:3000/api/products  # Through Nginx
```

---

## ✅ Summary

**Steps:**
1. ✅ `.env` file check করুন
2. ✅ `docker-compose down` (existing containers stop)
3. ✅ `docker-compose build` (rebuild with production frontend)
4. ✅ `docker-compose up -d` (start all services)
5. ✅ `http://localhost:3000` open করুন
6. ✅ Test করুন!

**Expected:** সব কাজ করবে, no errors! ✅

---

**Created:** 2025-01-27  
**Last Updated:** 2025-01-27

