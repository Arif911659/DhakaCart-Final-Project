# 🏗️ DhakaCart System Architecture

Complete architectural overview of DhakaCart e-commerce platform.

## 📊 High-Level Architecture

```
                          ┌─────────────────┐
                          │   End Users     │
                          │  (Customers)    │
                          └────────┬────────┘
                                   │
                          ┌────────▼────────┐
                          │   Internet      │
                          └────────┬────────┘
                                   │
                          ┌────────▼────────┐
                          │  Load Balancer  │
                          │   (Nginx/ALB)   │
                          └────────┬────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │                             │
          ┌─────────▼────────┐         ┌─────────▼────────┐
          │    Frontend      │         │    Backend       │
          │   (React App)    │────────▶│  (Node.js API)   │
          │   Port: 3000     │         │   Port: 5000     │
          └──────────────────┘         └─────────┬────────┘
                                                  │
                                   ┌──────────────┼──────────────┐
                                   │                             │
                         ┌─────────▼────────┐         ┌─────────▼────────┐
                         │   PostgreSQL     │         │      Redis       │
                         │   (Database)     │         │     (Cache)      │
                         │   Port: 5432     │         │   Port: 6379     │
                         └──────────────────┘         └──────────────────┘
```

---

## 🎯 Component Architecture

### 1. Frontend Layer

**Technology:** React 18 + Nginx

**Responsibilities:**
- User interface rendering
- Client-side routing
- Form validation
- State management
- API communication

**Features:**
- Responsive design
- Product browsing
- Shopping cart
- Checkout flow
- Order confirmation

**Deployment:**
- Multi-stage Docker build
- Nginx web server
- Optimized static assets
- CDN-ready

---

### 2. Backend API Layer

**Technology:** Node.js 18 + Express

**Responsibilities:**
- Business logic
- API endpoints
- Authentication/Authorization
- Data validation
- Cache management

**API Endpoints:**
```
GET    /health             # Health check
GET    /api/products       # List products
GET    /api/products/:id   # Get product
GET    /api/categories     # List categories
POST   /api/orders         # Create order
GET    /api/orders/:id     # Get order
```

**Features:**
- RESTful API design
- Input validation
- Error handling
- Logging
- Metrics exposure

---

### 3. Database Layer

**Technology:** PostgreSQL 15

**Schema:**

```sql
┌─────────────┐
│  products   │
├─────────────┤
│ id          │ PK
│ name        │
│ description │
│ price       │
│ category    │
│ stock       │
│ image_url   │
│ created_at  │
│ updated_at  │
└─────────────┘

┌─────────────┐
│   orders    │
├─────────────┤
│ id          │ PK
│ customer_*  │
│ delivery_*  │
│ total_amount│
│ status      │
│ created_at  │
└─────────────┘

┌─────────────┐
│ order_items │
├─────────────┤
│ id          │ PK
│ order_id    │ FK
│ product_id  │ FK
│ quantity    │
│ price       │
└─────────────┘
```

**Features:**
- ACID compliance
- Referential integrity
- Indexes for performance
- Backup and recovery

---

### 4. Cache Layer

**Technology:** Redis 7

**Usage:**
- Product catalog caching
- Session storage
- Rate limiting
- Real-time analytics

**Data Structures:**
```
products:all          -> List of all products (TTL: 5min)
products:{id}         -> Individual product (TTL: 10min)
categories            -> Product categories (TTL: 15min)
session:{token}       -> User sessions (TTL: 24h)
```

---

## 🔄 Request Flow

### Typical User Journey

```
1. User visits website
   └─> Frontend loads from CDN/Nginx
   
2. Browse products
   └─> Frontend → Backend API
       └─> Backend checks Redis cache
           ├─> Cache HIT: Return from Redis
           └─> Cache MISS: Query PostgreSQL → Update Redis → Return

3. Add to cart
   └─> Frontend updates local state
   └─> Backend updates Redis session

4. Checkout
   └─> Frontend → Backend API (POST /api/orders)
       └─> Backend validates data
           └─> PostgreSQL transaction
               ├─> Create order
               ├─> Create order_items
               ├─> Update product stock
               └─> Commit transaction
           └─> Clear related caches
           └─> Return order confirmation
```

---

## 🐳 Container Architecture

### Docker Compose Stack

```yaml
services:
  frontend:
    image: arifhossaincse22/dhakacart-frontend:latest
    ports: ["3000:80"]
    depends_on: [backend]
    
  backend:
    image: arifhossaincse22/dhakacart-backend:latest
    ports: ["5000:5000"]
    depends_on: [database, redis]
    environment:
      - DB_HOST=database
      - REDIS_HOST=redis
    
  database:
    image: postgres:15-alpine
    ports: ["5432:5432"]
    volumes: [postgres-data:/var/lib/postgresql/data]
    
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    volumes: [redis-data:/data]
```

---

## ☸️ Kubernetes Architecture

### Deployment Structure

```
dhakacart namespace
│
├── Deployments
│   ├── frontend (2 replicas)
│   ├── backend (3 replicas)
│   ├── database (1 replica)
│   └── redis (1 replica)
│
├── Services
│   ├── frontend-service (ClusterIP)
│   ├── backend-service (ClusterIP)
│   ├── db-service (ClusterIP)
│   └── redis-service (ClusterIP)
│
├── Ingress
│   └── dhakacart-ingress
│       ├── / → frontend-service
│       └── /api → backend-service
│
├── ConfigMaps
│   ├── app-config
│   └── postgres-init
│
├── Secrets
│   └── dhakacart-secrets
│
├── PersistentVolumeClaims
│   ├── postgres-pvc (10Gi)
│   └── redis-pvc (5Gi)
│
└── HorizontalPodAutoscalers
    ├── backend-hpa (3-10 pods)
    └── frontend-hpa (2-8 pods)
```

### Auto-Scaling Configuration

**Backend HPA:**
- Min Replicas: 3
- Max Replicas: 10
- Triggers: CPU > 70%, Memory > 80%
- Scale up: Immediate
- Scale down: 5 minute stabilization

**Frontend HPA:**
- Min Replicas: 2
- Max Replicas: 8
- Triggers: CPU > 70%, Memory > 80%

---

## 🔒 Security Architecture

### Network Security

```
Internet
   │
   └─> HTTPS (443) → Load Balancer
                          │
                  ┌───────┴───────┐
                  │               │
            Frontend          Backend
            (Public)         (Private)
                                 │
                     ┌───────────┴───────────┐
                     │                       │
                Database                  Redis
               (Private)                (Private)
```

**Security Layers:**
1. **Edge:** SSL/TLS, DDoS protection, WAF
2. **Application:** Input validation, authentication
3. **Network:** Firewall rules, network policies
4. **Data:** Encryption at rest, encrypted backups

### Authentication Flow

```
User Login
   │
   ├─> Frontend validates input
   │
   └─> POST /api/auth/login
       │
       ├─> Backend validates credentials
       │
       ├─> Query database (hashed password)
       │
       ├─> Generate JWT token
       │
       └─> Return token + user data

Authenticated Request
   │
   ├─> Frontend adds Authorization header
   │
   └─> Backend verifies JWT
       │
       ├─> Valid → Process request
       └─> Invalid → 401 Unauthorized
```

---

## 🛡️ Enterprise Security & Compliance (Phase 2)

### 1. Secrets Management
**Technology:** HashiCorp Vault

**Architecture:**
- **Vault Server:** Running in `vault` namespace
- **Agent Injector:** Automatically injects secrets into pods
- **Storage:** Encrypted at rest

**Workflow:**
1. Developer stores secret in Vault (e.g., `db_password`)
2. Pod starts with `@vault-inject` annotation
3. Vault Agent creates `/vault/secrets/config` file in pod
4. Application reads secret from file (No environment variables)

### 2. Backup & Disaster Recovery
**Technology:** Velero + MinIO

**Strategy:**
- **Schedule:** Daily at 2:00 AM
- **Storage:** Self-hosted MinIO (S3-compatible)
- **Scope:** All `dhakacart` namespace resources + PV snapshots
- **Retention:** 30 days

### 3. Traffic Encryption (HTTPS)
**Technology:** Cert-Manager + Let's Encrypt

**Features:**
- Automatic TLS certificate provisioning
- Ingress integration for SSL termination at ALB/Nginx
- Automatic renewal (30 days before expiry)

---


## 📊 Monitoring & Observability

### Monitoring Stack

```
                    ┌─────────────┐
                    │   Grafana   │
                    │ (Dashboard) │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │                         │
       ┌──────▼──────┐          ┌──────▼──────┐
       │ Prometheus  │          │    Loki     │
       │  (Metrics)  │          │   (Logs)    │
       └──────┬──────┘          └──────┬──────┘
              │                        │
       ┌──────┴──────┐          ┌──────┴──────┐
       │             │          │             │
   Exporters    Application  Promtail    Application
   (System)      (Metrics)   (Collector)   (Logs)
```

**Collected Metrics:**
- System: CPU, memory, disk, network
- Application: Requests/sec, latency, errors
- Business: Orders/min, revenue, conversions
- Database: Connections, query time, cache hit rate

---

## 🔄 Deployment Pipeline

### CI/CD Flow

```
Developer Push
      │
      └─> GitHub
          │
          └─> GitHub Actions
              │
              ├─> Run Tests
              │   ├─> Unit Tests
              │   ├─> Integration Tests
              │   └─> Linting
              │
              ├─> Build Docker Images
              │   ├─> Frontend (React build)
              │   └─> Backend (Node.js)
              │
              ├─> Push to Docker Hub
              │   ├─> Tag: latest
              │   └─> Tag: {version}
              │
              └─> Deploy
                  ├─> Staging (automatic)
                  └─> Production (manual approval)
                      ├─> Rolling Update
                      ├─> Health Check
                      └─> Rollback if failed
```

---

## 💾 Data Flow

### Write Path (Create Order)

```
1. Client submits order
   │
2. Backend validates data
   │
3. Start database transaction
   │
   ├─> INSERT INTO orders
   ├─> INSERT INTO order_items
   ├─> UPDATE products (stock)
   └─> COMMIT
   │
4. Clear cache (products)
   │
5. Send confirmation
```

### Read Path (Get Products)

```
1. Client requests products
   │
2. Backend checks Redis
   │
   ├─> Cache HIT (90% of requests)
   │   └─> Return from Redis
   │
   └─> Cache MISS (10% of requests)
       │
       ├─> Query PostgreSQL
       ├─> Store in Redis (TTL: 5min)
       └─> Return to client
```

---

## 🚀 Scalability Design

### Horizontal Scaling

**Stateless Components** (can scale infinitely):
- Frontend: 2-8 replicas (HPA)
- Backend: 3-10 replicas (HPA)

**Stateful Components** (vertical or replication):
- Database: Single master + read replicas
- Redis: Single instance or cluster mode

### Load Distribution

```
Load Balancer (Round Robin)
        │
    ┌───┴───┬───────┬───────┐
    │       │       │       │
Backend-1 Backend-2 Backend-3 Backend-N
    │       │       │       │
    └───────┴───┬───┴───────┘
                │
           Shared State
                │
         ┌──────┴──────┐
         │             │
    PostgreSQL      Redis
```

---

## 📈 Performance Optimization

### Caching Strategy

1. **Application Level** (Redis)
   - Product catalog
   - Categories
   - Session data

2. **HTTP Level** (Nginx)
   - Static assets
   - CDN integration

3. **Database Level** (PostgreSQL)
   - Query result caching
   - Connection pooling

### Database Optimization

- Indexes on frequently queried columns
- Connection pooling (max 20)
- Read replicas for analytics
- Partitioning for large tables

---

## 🔧 Technology Stack Summary

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| Frontend | React | 18 | UI Framework |
| Frontend Server | Nginx | 1.25 | Web Server |
| Backend | Node.js | 18 | Runtime |
| Backend Framework | Express | 4.x | API Framework |
| Database | PostgreSQL | 15 | Primary Database |
| Cache | Redis | 7 | Caching Layer |
| Container | Docker | 24.x | Containerization |
| Orchestration | Kubernetes | 1.28 | Container Orchestration |
| IaC | Terraform | 1.6 | Infrastructure Provisioning |
| CI/CD | GitHub Actions | - | Automation |
| Monitoring | Prometheus | 2.x | Metrics Collection |
| Visualization | Grafana | 10.x | Dashboards |
| Logging | Loki | 2.x | Log Aggregation |
| Config Mgmt | Ansible | 2.x | Automation |
| Secrets | Vault | 1.14 | Secrets Management |
| Backup | Velero | 1.11 | Cluster Backup |
| Storage | MinIO | RELEASE | S3-Compatible Storage |
| Security | Cert-Manager | 1.12 | Certificate Management |

---

## 📊 System Capacity

### Current Capacity

| Metric | Capacity |
|--------|----------|
| Concurrent Users | 1,000+ |
| Requests/Second | 100+ |
| Database Connections | 20 (pooled) |
| Redis Memory | 256 MB |
| Storage | 100 GB |

### Scaling Limits

| Component | Current | Max (Single) | Scaled |
|-----------|---------|--------------|--------|
| Frontend | 2 pods | N/A | 8 pods |
| Backend | 3 pods | N/A | 10 pods |
| Database | 1 instance | Limited | Replicas |
| Redis | 1 instance | 256 GB RAM | Cluster |

---

**Architecture evolves with requirements. Regular reviews and updates are essential.**

