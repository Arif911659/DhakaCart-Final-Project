kaCart — Final Project (E‑Commerce Reliability Challenge)

**Project brief (uploaded):** `/mnt/data/DevOpsBatch2.pdf`

---

## সংক্ষিপ্ত পরিচিতি
DhakaCart একটি ছোট‑মাঝারী ই‑কমার্স সাইট। পরীক্ষার সময় সাইট একক ডেস্কটপে হোস্ট ছিল, যার ফলে সেল/ট্রাফিক স্পাইক সময় সাইট ডাউন হয়ে বড় আর্থিক ক্ষতি হয়েছে। এই প্রজেক্টের লক্ষ্য — DhakaCart‑কে একক যন্ত্র থেকে ক্লাউড‑ভিত্তিক, রিলায়েবল, স্কেলেবল, নিরাপদ ও অটোমেটেড আর্কিটেকচারে রূপান্তর করা যাতে পরবর্তী Eid Sale (100k+ concurrent visitors) নিরাপদে চালানো যায়।

---

## লক্ষ্যসমূহ (Goals)
1. **Scalability:** 100,000+ concurrent visitors সামলাতে পারা।
2. **High Availability:** হার্ডওয়্যার ব্যর্থতা সাপেক্ষেও সার্ভিস চলমান থাকবে।
3. **Zero‑downtime Deployments:** CI/CD দিয়ে রোলিং বা blue/green deploys।
4. **Security & Compliance:** HTTPS, secrets management, RBAC, network segmentation।
5. **Monitoring & Logging:** Real‑time dashboards, alerts, centralized logs।
6. **Backups & DR:** Automated, tested backups এবং point‑in‑time recovery।
7. **IaC & Reproducibility:** Terraform দিয়ে পুরো ইনফ্রা কোডে প্রকাশ।

---

## উচ্চস্তরের আর্কিটেকচার (Recommended Architecture)
- **Cloud Provider:** AWS (সার্বজনীন, managed services সহজ, বিলিং ও ডকুমেন্টেশন ভালো)।
- **Networking:** VPC with public/private subnets, NAT Gateway, Security Groups
- **Load Balancing:** Application Load Balancer (ALB)
- **Compute / Orchestration:** EKS (managed Kubernetes) বা AWS Fargate (serverless containers) — non‑coder হলে Fargate সহজ। (Ensure Multi-AZ deployment for High Availability)
- **Database:** Amazon RDS (Postgres / MySQL) in private subnet with Multi‑AZ
- **Caching:** Amazon ElastiCache (Redis)
- **Storage & Backups:** S3 for static assets + backups; RDS automated snapshots
- **CI/CD:** GitHub Actions (push → tests → build → push image → deploy)
- **Monitoring:** CloudWatch + Grafana (hosted) / Prometheus+Grafana on cluster
- **Logging:** CloudWatch Logs or ELK/Grafana Loki
- **Secrets:** AWS Secrets Manager or HashiCorp Vault
- **CDN:** CloudFront for assets and TLS termination (improves global performance)

---

## Repository Structure (suggested)
```
DhakaCart-Final-Project/
├── backend/
├── frontend/
├── database/
├── kubernetes/
│   ├── deployments/
│   ├── services/
│   └── ingress/
├── terraform/
├── ansible/
├── ci-cd/
│   └── github-actions/
├── docs/
└── README.md
```

---

## Deliverables (what you must deliver in the exam)
- GitHub repo with regular commits and README
- Terraform code to provision base infra (VPC, EKS/Fargate, RDS, ALB)
- Containerized frontend/backend images + example Kubernetes manifests
- GitHub Actions workflows for CI/CD (build → test → deploy)
- Monitoring dashboards (Grafana) + alerting rules
- Centralized logging setup (CloudWatch/ELK/Loki)
- Secrets management example (Secrets Manager) + HTTPS via ACM + CloudFront
- Backup & restore runbook and automated DB snapshots
- Documentation: runbooks, architecture diagram, troubleshooting.md

---

# Smart Plan (Non‑coder friendly) — "What to do, Why, and How"
প্রতিটি ধাপ আমি সারসংক্ষেপে (কি, কেন, কিভাবে) দিয়েছি। প্রতিটি ধাপের শেষে সহজ, কপি‑পেস্ট করার মতো কমান্ড বা নির্দেশ থাকবে যেখানে প্রয়োজন। প্রতিটি ল্যাব সেশন 4‑5 ঘণ্টা ধরে ধাপে ধাপে কাজ করুন এবং প্রতিটি সেশনের শেষে commit & push করুন।

---

## Phase 0 — Preparation (Session 0, 1 session)
**কি:** প্রজেক্ট গিট রিপো তৈরি, ক্লাউড একটি অ্যাকাউন্ট তৈরি (AWS/Google Cloud), স্থানীয় উন্নয়ন পরিবেশ বোঝা।

**কেন:** সবকিছু versioned থাকতে হবে। ক্লাউড access লাগবে infra deploy করার জন্য।

**কিভাবে (steps):**
1. GitHub repo তৈরি করুন (public/private as instructed).
2. আপনার কাজের কম্পিউটারে Git সেটআপ করুন:
```bash
git init
git remote add origin git@github.com:youruser/DhakaCart-Final-Project.git
```
3. Cloud account: AWS সুপারিশ (AWS Free Tier/education credits ব্যবহার করুন যদি থাকে)।
4. **Cost Control:** AWS Billing Dashboard এ গিয়ে একটি "Zero Spend Budget" বা নির্দিষ্ট লিমিটের বাজেট সেট করুন যাতে বিল বেশি আসলে ইমেইল পান।

**Deliverable:** একটি GitHub repo এবং `docs/` ভিতরে project brief (PDF link): `/mnt/data/DevOpsBatch2.pdf`.

---

## Phase 1 — Foundation (Session 1–2)
**কি:** VPC, networking, subnets, security groups, IAM roles প্রভৃতি Terraform দিয়ে তৈরি করা।

**কেন:** ম্যানুয়াল কনফিগারেশন ঝুঁকিপূর্ণ; IaC দিয়ে দ্রুত পুনরুদ্ধার ও রেপ্লিকেট করা যায়।

**কিভাবে:**
- Terraform ব্যবহার করুন। (Non‑coder হলে আমি আপনাকে prebuilt Terraform module দেব, শুধু variables এ মান বসাতে হবে)

**Quick commands (Ubuntu/WSL):**
```bash
cd terraform
terraform init
terraform plan -out=plan.tfplan
terraform apply plan.tfplan
```

**Deliverable:** `terraform/` এ IaC কোড + README explaining variables.

---

## Phase 2 — Containerize Application (Session 2–3)
**কি:** Frontend (React) এবং Backend (Node/Express) Docker image বানানো।

**কেন:** কনটেইনার হলো reproducible unit; orchestration সহজ হয়।

**কিভাবে (non‑coder friendly):**
- আমি আপনাকে `Dockerfile` templates দেব — শুধু কপি করে আপনার কোড ফোল্ডারে রাখুন।
- Local build test:
```bash
docker build -t dhakacart-frontend:latest ./frontend
docker build -t dhakacart-backend:latest ./backend
```

**Deliverable:** `frontend/Dockerfile`, `backend/Dockerfile` এবং tested images locally.

---

## Phase 3 — Orchestration & Deploy (Session 3–5)
**কি:** EKS (managed Kubernetes) or AWS Fargate deploy. For non‑coder, choose Fargate for simplicity; for full control choose EKS.

**কেন:** Orchestration needed for multiple replicas, health checks, auto healing and rolling updates.

**কিভাবে:**
- If you choose Fargate (easier): use ECS Fargate task definitions + ALB.
- If you choose EKS: use `kubernetes/` manifests (Deployment, Service, Ingress) and `kubectl apply -f ...`.

**Example (EKS):**
```bash
# create cluster using eksctl (simple)
eksctl create cluster --name dhakacart-cluster --region ap-southeast-1 --nodes 2
kubectl apply -f kubernetes/deployments/backend-deploy.yaml
kubectl apply -f kubernetes/deployments/frontend-deploy.yaml
```

**Deliverable:** Running app behind ALB with >2 replicas and liveness/readiness probes.

---

## Phase 4 — CI/CD (Session 5–7)
**কি:** GitHub Actions workflow: on push → run tests → build Docker images → push to ECR (or DockerHub) → deploy (kubectl / ecs deploy).

**কেন:** Manual FileZilla upload must stop. Automated deployment reduces human error and downtime.

**কিভাবে (example):**
- Provide GitHub Action sample file `ci-cd/github-actions/deploy.yml` (I will provide template in repo).

**Key steps in pipeline:**
1. Checkout
2. Run unit tests
3. **Security Scan:** Run SAST tools (e.g., SonarQube) or container scan (Trivy) before build.
3. Build images and push to registry
4. Deploy to cluster (kubectl set image or use helm)
5. Notify on Slack/Email on success or failure

**Deliverable:** Working pipeline that reduces deploy time to ~10 minutes and supports automatic rollback.

---

## Phase 5 — Monitoring, Logging & Alerts (Session 7–9)
**কি:** Deploy monitoring stack, logging, and **Load Testing**.

**কেন:** Early detection reduces MTTD/MTTR; centralized logs speed debugging.

**কিভাবে (options):**
- **Managed (easy):** CloudWatch + Grafana Cloud (create dashboards) + SNS for alerts.
- **Self‑hosted:** Prometheus + Grafana + Loki (K8s manifests provided).
- **Load Testing:** Use k6 or JMeter to simulate traffic (10k-100k users) and observe Grafana dashboards.

**Basic Alert Examples:**
- CPU > 80% for 5 minutes → send SMS/Slack
- 5xx error rate > 1% → send alert

**Deliverable:** Dashboard screenshots + alert policies in docs.

---

## Phase 6 — Security Hardening (Session 9–10)
**কি:** HTTPS, Secrets manager, DB in private subnet, IAM Roles, vulnerability scanning.

**কেন:** Customer data নিরাপত্তা, আইনগত বাধ্যবাধকতা এবং বিশ্বাস রক্ষা করতে।

**কিভাবে (practical steps):**
1. Enable HTTPS: Use AWS ACM certificate + CloudFront/ALB TLS termination.
2. Secrets: store DB credentials in AWS Secrets Manager; mount into pods via Secrets store CSI or use environment variables from secrets in ECS Task.
3. Database: put RDS in private subnet, security group only allows app nodes.
4. Scanning: Integrate Snyk or Trivy in CI to scan container images.

**Deliverable:** Security checklist + proof (ACM certificate, secrets configured, scan reports).

---

## Phase 7 — Backups & DR (Session 10–11)
**কি:** RDS automated snapshots, S3 backups for media, cross‑region replication for critical data.

**কেন:** Data loss prevention and quicker recovery.

**কিভাবে:**
- Enable RDS automated backups + daily snapshot + retention (7–30 days)
- Create lifecycle policy for S3 backups and replicate to another region
- Test restore once (document steps)

**Deliverable:** Backup policy doc + tested restore steps.

---

## Phase 8 — Runbooks, Documentation & Presentation (Session 11–12)
**কি:** Runbooks, architecture diagrams, troubleshooting steps, emergency rollback procedure and final demo prep.

**কেন:** Examiner will inspect operational readiness and documentation.

**কিভাবে:**
- `docs/runbook.md` with step‑by‑step for common incidents
- `docs/troubleshooting.md` for frequent failures
- Prepare a 10‑15 minute demo: show deployment, simulate failure, show auto‑recover

**Deliverable:** Final README, runbooks, slides, and working demo scripts.

---

# Simple timeline (12 sessions ≈ 12 × 4–5 hours)
1. Session 0 — Setup & Repo (4h)
2. Session 1 — Terraform foundation (4h)
3. Session 2 — Containerize (4h)
4. Session 3 — Basic cluster & deploy (4h)
5. Session 4 — CI/CD initial pipeline (4h)
6. Session 5 — Blue–green / rollout & rollback (4h)
7. Session 6 — Monitoring + logs (4h)
8. Session 7 — Secrets & HTTPS (4h)
9. Session 8 — Backups & DR (4h)
10. Session 9 — Security scans & hardening (4h)
11. Session 10 — Runbooks & docs (4h)
12. Session 11 — Final polish & demo prep (4h)

---

# Tips for a Non‑Coder (keep it simple & smart)
- **Prefer managed services (Fargate, RDS, ALB)** — less infra maintenance.
- **Use templates** — use provided Terraform modules and Dockerfile templates; you only fill values.
- **One‑click deploy** — GitHub Actions templates will automate build & deploy; you won’t need to SCP files.
- **Runbook first** — write short, explicit steps for each incident. You can follow those without deep coding knowledge.
- **Use UI for monitoring** — Grafana / CloudWatch is graphical and helpful.
- **Ask for small code snippets** — I’ll provide copy/paste code for Terraform, manifests, CI workflows.

---

# Minimal commands cheat‑sheet (copy/paste friendly)
**Initialize Git**
```bash
git clone git@github.com:youruser/DhakaCart-Final-Project.git
cd DhakaCart-Final-Project
```
**Terraform (init → plan → apply)**
```bash
cd terraform
terraform init
terraform plan -out plan.tfplan
terraform apply plan.tfplan
```
**Build & push Docker image (example with ECR)**
```bash
# login (AWS CLI must be configured)
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.ap-southeast-1.amazonaws.com
# build
docker build -t dhakacart-frontend:latest ./frontend
# tag & push
docker tag dhakacart-frontend:latest <account>.dkr.ecr.ap-southeast-1.amazonaws.com/dhakacart-frontend:latest
docker push <account>.dkr.ecr.ap-southeast-1.amazonaws.com/dhakacart-frontend:latest
```

---

# Risk register (short)
- **Credential leak** — Use Secrets Manager + remove hardcoded secrets. Rotate keys.
- **Cost overrun** — Use budgets & alerts. Start small (t2.medium / 2 nodes) and autoscale.
- **Deployment failure** — Use blue/green or canary + automated rollback.
- **Data loss** — Automated daily backups + cross‑region replication.

---

# Grading checklist (for exam review)
- [ ] GitHub repo with commits every session
- [ ] Terraform code to provision base infra
- [ ] Containerized frontend & backend images
- [ ] CI/CD pipeline that deploys to cloud
- [ ] Monitoring dashboards + alerts
- [ ] Centralized logging searchable by time/user
- [ ] Secrets management in place
- [ ] Automated backups & tested restore
- [ ] Documentation & runbooks

---

## Notes & Next steps
- আমি প্রতিটি ধাপের জন্য ready‑to‑use templates (Terraform modules, Dockerfiles, Kubernetes manifests, GitHub Actions workflows) তৈরি করে দিতে পারি।
- আপনি বললেই আমি `terraform/` এর জন্য একটি minimal starter, `ci-cd/github-actions/deploy.yml`, এবং `kubernetes/` এর জন্য basic manifests তৈরি করে দেব যা আপনি কপি‑পেস্ট করে ব্যবহার করবেন।


---

*Prepared by: Arif (Student) — DhakaCart Final Project README & Plan*


