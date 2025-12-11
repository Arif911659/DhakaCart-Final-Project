# DhakaCart Docker Hub Deployment Guide

## 🎉 Successfully Pushed to Docker Hub!

**Date:** 2025-11-22  
**Docker Hub Username:** arifhossaincse22

---

## Published Images

### Backend
- **Repository:** `arifhossaincse22/dhakacart-backend`
- **Tags:** `v1.0.0`, `latest`
- **Size:** 134MB
- **URL:** https://hub.docker.com/r/arifhossaincse22/dhakacart-backend

### Frontend
- **Repository:** `arifhossaincse22/dhakacart-frontend`
- **Tags:** `v1.0.0`, `latest`
- **Size:** 415MB
- **URL:** https://hub.docker.com/r/arifhossaincse22/dhakacart-frontend

---

## Deployment Options

### Option 1: Deploy from Docker Hub (Recommended)

Anyone can now deploy your application using:

```bash
# Create .env file
cat > .env << 'EOF'
NODE_ENV=production
PORT=5000
DB_HOST=database
DB_PORT=5432
DB_USER=dhakacart
DB_PASSWORD=dhakacart123
DB_NAME=dhakacart_db
REDIS_HOST=redis
REDIS_PORT=6379
REACT_APP_API_URL=http://localhost:5000/api
EOF

# Pull and run
docker-compose -f docker-compose.prod.yml up -d
```

### Option 2: Pull Images Manually

```bash
# Pull backend
docker pull arifhossaincse22/dhakacart-backend:latest

# Pull frontend  
docker pull arifhossaincse22/dhakacart-frontend:latest

# Run backend
docker run -d \
  --name dhakacart-backend \
  -p 5000:5000 \
  -e DB_HOST=database \
  -e REDIS_HOST=redis \
  arifhossaincse22/dhakacart-backend:latest

# Run frontend
docker run -d \
  --name dhakacart-frontend \
  -p 3000:3000 \
  arifhossaincse22/dhakacart-frontend:latest
```

---

## Kubernetes Deployment

Now that images are on Docker Hub, you can deploy to Kubernetes:

```yaml
# backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dhakacart-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: dhakacart-backend
  template:
    metadata:
      labels:
        app: dhakacart-backend
    spec:
      containers:
      - name: backend
        image: arifhossaincse22/dhakacart-backend:v1.0.0
        ports:
        - containerPort: 5000
        env:
        - name: DB_HOST
          value: "dhakacart-db-service"
        - name: REDIS_HOST
          value: "dhakacart-redis-service"
```

---

## CI/CD Integration

Your GitHub Actions can now use these images:

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build and Push
        run: |
          docker build -t arifhossaincse22/dhakacart-backend:${{ github.sha }} ./backend
          docker push arifhossaincse22/dhakacart-backend:${{ github.sha }}
      
      - name: Deploy to Kubernetes
        run: |
          kubectl set image deployment/dhakacart-backend \
            backend=arifhossaincse22/dhakacart-backend:${{ github.sha }}
```

---

## Testing the Deployment

### Test Pulling from Docker Hub

```bash
# Stop current containers
docker-compose down

# Remove local images (to force pull from Docker Hub)
docker rmi dhakacart-backend:v1.0.0
docker rmi dhakacart-frontend:v1.0.0

# Deploy from Docker Hub
docker-compose -f docker-compose.prod.yml up -d

# Verify images were pulled
docker images | grep arifhossaincse22
```

### Health Check

```bash
# Wait 30 seconds for services to start
sleep 30

# Check health
curl http://localhost:5000/health
curl http://localhost:5000/api/products
curl http://localhost:3000
```

---

## Image Optimization (Future)

### Current Sizes
- Backend: 134MB ✅ Good (optimized with multi-stage build)
- Frontend: 415MB ⚠️ Can be optimized

### Optimization Tips

#### 1. Use nginx for production frontend
```dockerfile
# Add production stage to frontend/Dockerfile
FROM nginx:alpine AS production
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

#### 2. Enable Docker BuildKit
```bash
export DOCKER_BUILDKIT=1
docker build --target production -t dhakacart-frontend:prod ./frontend
```

This could reduce frontend image to ~50MB!

---

## Security Best Practices

### 1. Use Specific Tags (Not latest)
```bash
# Instead of:
image: arifhossaincse22/dhakacart-backend:latest

# Use:
image: arifhossaincse22/dhakacart-backend:v1.0.0
```

### 2. Scan Images for Vulnerabilities
```bash
# Install Trivy
docker run aquasec/trivy image arifhossaincse22/dhakacart-backend:v1.0.0
```

### 3. Sign Images
```bash
# Use Docker Content Trust
export DOCKER_CONTENT_TRUST=1
docker push arifhossaincse22/dhakacart-backend:v1.0.0
```

---

## Updating Images

### When you make changes:

```bash
# 1. Update version
VERSION=v1.0.1

# 2. Build new images
docker-compose build

# 3. Tag with new version
docker tag dhakacart-backend:v1.0.0 arifhossaincse22/dhakacart-backend:$VERSION
docker tag dhakacart-frontend:v1.0.0 arifhossaincse22/dhakacart-frontend:$VERSION

# 4. Push to Docker Hub
docker push arifhossaincse22/dhakacart-backend:$VERSION
docker push arifhossaincse22/dhakacart-frontend:$VERSION

# 5. Update latest tag
docker tag arifhossaincse22/dhakacart-backend:$VERSION arifhossaincse22/dhakacart-backend:latest
docker push arifhossaincse22/dhakacart-backend:latest
```

---

## Rollback Strategy

If new version has issues:

```bash
# Kubernetes rollback
kubectl rollout undo deployment/dhakacart-backend

# Docker Compose rollback
docker-compose -f docker-compose.prod.yml down
# Edit docker-compose.prod.yml to use previous version
docker-compose -f docker-compose.prod.yml up -d
```

---

## Next Steps

1. ✅ Images pushed to Docker Hub
2. ⬜ Set up Kubernetes cluster
3. ⬜ Create Kubernetes manifests
4. ⬜ Set up CI/CD pipeline
5. ⬜ Deploy to cloud (AWS/GCP)
6. ⬜ Set up monitoring
7. ⬜ Configure auto-scaling

---

## Useful Commands

```bash
# View image details
docker inspect arifhossaincse22/dhakacart-backend:v1.0.0

# Check image layers
docker history arifhossaincse22/dhakacart-backend:v1.0.0

# Pull specific version
docker pull arifhossaincse22/dhakacart-backend:v1.0.0

# List all tags (use Docker Hub API)
curl https://hub.docker.com/v2/repositories/arifhossaincse22/dhakacart-backend/tags
```

---

**Congratulations! Your application is now publicly available on Docker Hub!** 🎉

Anyone can now deploy DhakaCart with a single command:
```bash
docker-compose -f docker-compose.prod.yml up -d
```
============================================================


লোকালে পরীক্ষা করি। `docker-compose.yml` আপডেট করছি যাতে nginx proxy সঠিকভাবে কাজ করে:


[4 tools called]


লোকালে পরীক্ষার জন্য `docker-compose.yml` আপডেট করছি:


[3 tools called]


লোকালে পরীক্ষার জন্য সব ঠিক করা হয়েছে। এখন test করুন:

## যা করা হয়েছে

1. `docker-compose.yml` আপডেট — Production build (Nginx) ব্যবহার করবে
2. `nginx.conf` ঠিক করা — `backend:5000` (Docker network) ব্যবহার করবে
3. `App.js` আপডেট — Relative URL (`/api`) support

---

## লোকালে Test করার Steps

### Step 1: Existing Containers Stop করুন

```bash
cd /home/arif/DhakaCart-03
docker-compose down
```

### Step 2: Rebuild করুন (Production Frontend)

```bash
# Frontend production build করবে (Nginx সহ)
docker-compose build

# সব services start করুন
docker-compose up -d
```

### Step 3: Logs দেখুন

```bash
docker-compose logs -f
```

30-60 সেকেন্ড অপেক্ষা করুন services ready হতে।

### Step 4: Browser-এ Test করুন

```
http://localhost:3000
```

Expected: Products load হবে, no error.

---

## Verify Nginx Proxy কাজ করছে

```bash
# Direct backend test
curl http://localhost:5000/api/products

# Through Nginx proxy (এইটা কাজ করলে perfect!)
curl http://localhost:3000/api/products
```

দ্বিতীয় command কাজ করলে Nginx proxy ঠিক আছে।

---

## Quick Test Commands

```bash
# Check containers
docker-compose ps

# Check logs
docker-compose logs frontend
docker-compose logs backend

# Test API
curl http://localhost:3000/api/products
```

---

## যদি Error দেখেন

```bash
# Rebuild frontend
docker-compose build frontend
docker-compose up -d frontend

# Check logs
docker-compose logs frontend
```

---

## Summary

- `docker-compose.yml` আপডেট করা হয়েছে
- Production build (Nginx) ব্যবহার করবে
- Relative URL (`/api`) ব্যবহার করবে
- সব Docker network-এ চলবে

এখন test করুন:

```bash
docker-compose down
docker-compose build
docker-compose up -d
```

তারপর `http://localhost:3000` open করুন।

See `LOCAL_TESTING_GUIDE.md` for detailed instructions.