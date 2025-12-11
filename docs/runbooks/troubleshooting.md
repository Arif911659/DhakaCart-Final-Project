# 🔧 DhakaCart Troubleshooting Runbook

Common issues and their solutions.

## 🎯 Quick Diagnosis Checklist

```bash
# 1. Check if services are running
docker ps  # or kubectl get pods -n dhakacart

# 2. Check service health
curl http://localhost:5000/health

# 3. Check logs
docker logs dhakacart-backend --tail 50

# 4. Check resource usage
docker stats  # or kubectl top pods -n dhakacart

# 5. Check network connectivity
curl http://localhost:5000/api/products
```

---

## 🔴 Critical Issues

### Issue: Complete Service Outage

**Symptoms:**
- Website not accessible
- 502/503 errors
- All services down

**Diagnosis:**
```bash
# Check all containers
docker ps -a

# Check Kubernetes pods
kubectl get pods -n dhakacart
```

**Solution:**
```bash
# Docker Compose
docker-compose down
docker-compose up -d

# Kubernetes
kubectl rollout restart deployment -n dhakacart
```

**Prevention:**
- Enable health checks
- Set up monitoring alerts
- Use auto-restart policies

---

### Issue: Database Connection Failed

**Symptoms:**
- Backend logs show "Connection refused"
- 500 errors on API calls
- "Cannot connect to database"

**Diagnosis:**
```bash
# Check database is running
docker ps | grep postgres

# Check database logs
docker logs dhakacart-db --tail 100

# Test connection
docker exec dhakacart-db pg_isready -U dhakacart
```

**Solution:**
```bash
# Restart database
docker-compose restart database

# Check credentials
echo $DB_PASSWORD

# Verify connection string
docker exec dhakacart-backend env | grep DB_
```

**Prevention:**
- Use connection pooling
- Implement retry logic
- Monitor database health

---

## 🟡 High Priority Issues

### Issue: High Response Times

**Symptoms:**
- Pages loading slowly
- API timeouts
- p95 latency > 2s

**Diagnosis:**
```bash
# Check CPU/memory
docker stats

# Check slow queries
docker exec dhakacart-db psql -U dhakacart -d dhakacart_db -c "SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"

# Check Redis cache
docker exec dhakacart-redis redis-cli INFO stats | grep hit
```

**Solution:**
```bash
# Clear cache
docker exec dhakacart-redis redis-cli FLUSHDB

# Restart services
docker-compose restart backend

# Scale up (K8s)
kubectl scale deployment dhakacart-backend -n dhakacart --replicas=5
```

**Prevention:**
- Optimize database queries
- Add indexes
- Increase cache TTL
- Scale horizontally

---

### Issue: Memory Leak

**Symptoms:**
- Memory usage growing continuously
- OOM (Out of Memory) kills
- Pods restarting frequently

**Diagnosis:**
```bash
# Monitor memory over time
watch -n 5 'docker stats --no-stream'

# Check for memory leaks
docker exec dhakacart-backend node --expose-gc --inspect=0.0.0.0:9229 server.js

# K8s pod restarts
kubectl get pods -n dhakacart | grep Restart
```

**Solution:**
```bash
# Quick fix: Restart service
docker-compose restart backend

# Increase memory limit
# Edit docker-compose.yml
services:
  backend:
    deploy:
      resources:
        limits:
          memory: 1G
```

**Prevention:**
- Fix memory leaks in code
- Use heap snapshots
- Implement garbage collection
- Set appropriate limits

---

## 🟢 Medium Priority Issues

### Issue: High CPU Usage

**Symptoms:**
- CPU at 80%+
- Slow response times
- Throttling

**Diagnosis:**
```bash
# Check CPU usage
top -bn1 | grep dhakacart

# Profile application
docker exec dhakacart-backend node --prof server.js
```

**Solution:**
```bash
# Scale horizontally (K8s)
kubectl scale deployment dhakacart-backend -n dhakacart --replicas=6

# Optimize code
# - Reduce complex computations
# - Use caching
# - Offload to workers
```

---

### Issue: Disk Space Full

**Symptoms:**
- "No space left on device"
- Containers fail to start
- Backups failing

**Diagnosis:**
```bash
# Check disk usage
df -h

# Find large files
du -sh /* | sort -rh | head -10

# Docker disk usage
docker system df
```

**Solution:**
```bash
# Clean Docker resources
docker system prune -af --volumes

# Clean logs
sudo rm -rf /var/log/*.log

# Clean old backups
find /backups -name "*.gz" -mtime +30 -delete
```

---

### Issue: Network Connectivity

**Symptoms:**
- Cannot reach external APIs
- DNS resolution failing
- Timeout errors

**Diagnosis:**
```bash
# Test network
docker exec dhakacart-backend ping google.com

# Check DNS
docker exec dhakacart-backend nslookup google.com

# Check routes
docker exec dhakacart-backend traceroute google.com
```

**Solution:**
```bash
# Restart Docker network
docker network prune
docker-compose down
docker-compose up -d

# Check firewall
sudo ufw status
```

---

## ⚪ Low Priority Issues

### Issue: Cache Not Working

**Symptoms:**
- Slow product loading
- High database load
- Cache hit rate low

**Diagnosis:**
```bash
# Check Redis
docker exec dhakacart-redis redis-cli INFO stats

# Test cache
docker exec dhakacart-redis redis-cli GET "products:all"

# Check TTL
docker exec dhakacart-redis redis-cli TTL "products:all"
```

**Solution:**
```bash
# Flush and rebuild cache
docker exec dhakacart-redis redis-cli FLUSHDB

# Restart backend (rebuilds cache)
docker-compose restart backend
```

---

### Issue: Image Pull Errors

**Symptoms:**
- "ImagePullBackOff"
- "ErrImagePull"
- Pods not starting

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n dhakacart

# Verify image exists
docker pull arifhossaincse22/dhakacart-backend:latest
```

**Solution:**
```bash
# Pull image manually
docker pull arifhossaincse22/dhakacart-backend:latest

# Update deployment
kubectl set image deployment/dhakacart-backend -n dhakacart backend=arifhossaincse22/dhakacart-backend:latest

# Check image pull policy
kubectl edit deployment dhakacart-backend -n dhakacart
# imagePullPolicy: IfNotPresent
```

---

## 🛠️ Debugging Tools

### Log Analysis

```bash
# Real-time logs
docker-compose logs -f backend

# Filter logs
docker logs dhakacart-backend 2>&1 | grep ERROR

# Last N lines
docker logs dhakacart-backend --tail 100

# Since timestamp
docker logs dhakacart-backend --since "2024-01-01T00:00:00"
```

### Database Queries

```bash
# Connect to database
docker exec -it dhakacart-db psql -U dhakacart -d dhakacart_db

# Check active connections
SELECT * FROM pg_stat_activity;

# Check slow queries
SELECT * FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;

# Check table sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

### Redis Debugging

```bash
# Connect to Redis
docker exec -it dhakacart-redis redis-cli

# Check memory usage
INFO memory

# List keys
KEYS *

# Monitor commands
MONITOR

# Check slow log
SLOWLOG GET 10
```

---

## 📊 Health Check Endpoints

### Backend Health

```bash
# Basic health
curl http://localhost:5000/health

# Expected response
{
  "status": "healthy",
  "timestamp": "2024-11-23T12:00:00Z",
  "services": {
    "database": "connected",
    "redis": "connected"
  }
}
```

### Database Health

```bash
# Check if accepting connections
pg_isready -h localhost -p 5432 -U dhakacart

# Check replication (if configured)
SELECT * FROM pg_stat_replication;
```

### Redis Health

```bash
# Ping test
redis-cli -h localhost -p 6379 ping
# Expected: PONG

# Check info
redis-cli INFO server
```

---

## 🔍 Root Cause Analysis

### Performance Issues

1. **Identify symptom** - Slow response times
2. **Check metrics** - CPU, memory, network
3. **Analyze logs** - Look for errors
4. **Profile code** - Find bottlenecks
5. **Test fix** - Verify improvement
6. **Deploy** - Roll out solution
7. **Monitor** - Ensure issue resolved

### Crash Analysis

```bash
# Core dump analysis
docker exec dhakacart-backend ls -la /cores/

# Application logs
docker logs dhakacart-backend --since "1h" | grep -i "crash\|fatal\|panic"

# System logs
sudo journalctl -u docker --since "1 hour ago"
```

---

## 📞 Escalation Path

1. **Level 1** - Check this runbook
2. **Level 2** - DevOps engineer on-call
3. **Level 3** - Senior DevOps + DBA
4. **Level 4** - CTO + Cloud provider support

---

**Remember: Always document issues and solutions for future reference!**

