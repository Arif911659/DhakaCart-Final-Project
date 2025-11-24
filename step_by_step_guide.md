# DhakaCart Final Project: Step-by-Step Execution Guide

This guide provides a detailed, step-by-step approach to completing the DhakaCart Final Project. Follow these steps sequentially to ensure a successful deployment.

## Phase 0: Preparation & Setup

### Step 1: Initialize Git Repository
1.  Open your terminal.
2.  Navigate to your project directory or create a new one:
    ```bash
    mkdir DhakaCart-Final-Project
    cd DhakaCart-Final-Project
    ```
3.  Initialize Git:
    ```bash
    git init
    ```
4.  Create a `.gitignore` file:
    ```bash
    echo "node_modules/" >> .gitignore
    echo ".terraform/" >> .gitignore
    echo "*.tfstate" >> .gitignore
    echo "*.tfstate.backup" >> .gitignore
    echo ".env" >> .gitignore
    ```
5.  Commit the initial setup:
    ```bash
    git add .
    git commit -m "Initial commit: Project setup"
    ```

### Step 2: AWS Account Setup
1.  Log in to your AWS Console.
2.  Navigate to **Billing Dashboard** > **Budgets**.
3.  Create a "Zero Spend Budget" or a monthly budget (e.g., $10) to get alerted on costs.

## Phase 1: Infrastructure as Code (Terraform)

### Step 3: Setup Terraform Structure
1.  Create the `terraform` directory:
    ```bash
    mkdir terraform
    cd terraform
    ```
2.  Create `main.tf`, `variables.tf`, and `outputs.tf`.
    *   *Note: You will need to populate these with actual Terraform code for VPC, EKS/Fargate, and RDS.*
3.  Initialize Terraform:
    ```bash
    terraform init
    ```

### Step 4: Provision Infrastructure
1.  Check the plan:
    ```bash
    terraform plan -out=plan.tfplan
    ```
2.  Apply the infrastructure:
    ```bash
    terraform apply plan.tfplan
    ```
    *Type `yes` when prompted.*

## Phase 2: Containerization

### Step 5: Dockerize Backend
1.  Navigate to the `backend` directory (create it if it doesn't exist and add your Node.js app).
2.  Create a `Dockerfile`:
    ```dockerfile
    FROM node:18-alpine
    WORKDIR /app
    COPY package*.json ./
    RUN npm install --production
    COPY . .
    EXPOSE 5000
    CMD ["npm", "start"]
    ```
3.  Build and test locally:
    ```bash
    docker build -t dhakacart-backend:latest .
    docker run -p 5000:5000 dhakacart-backend:latest
    ```

### Step 6: Dockerize Frontend
1.  Navigate to the `frontend` directory.
2.  Create a `Dockerfile`:
    ```dockerfile
    FROM node:18-alpine as build
    WORKDIR /app
    COPY package*.json ./
    RUN npm install
    COPY . .
    RUN npm run build

    FROM nginx:alpine
    COPY --from=build /app/build /usr/share/nginx/html
    EXPOSE 80
    CMD ["nginx", "-g", "daemon off;"]
    ```
3.  Build and test locally:
    ```bash
    docker build -t dhakacart-frontend:latest .
    docker run -p 80:80 dhakacart-frontend:latest
    ```

## Phase 3: Orchestration (Kubernetes/EKS)

### Step 7: Push Images to ECR
1.  Create ECR repositories in AWS Console (one for frontend, one for backend).
2.  Authenticate Docker with ECR:
    ```bash
    aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.<region>.amazonaws.com
    ```
3.  Tag and push images:
    ```bash
    docker tag dhakacart-backend:latest <ecr_repo_url_backend>:latest
    docker push <ecr_repo_url_backend>:latest

    docker tag dhakacart-frontend:latest <ecr_repo_url_frontend>:latest
    docker push <ecr_repo_url_frontend>:latest
    ```

### Step 8: Deploy to Kubernetes
1.  Create `kubernetes/deployments` directory.
2.  Create `backend-deployment.yaml` and `frontend-deployment.yaml`.
3.  Apply manifests:
    ```bash
    kubectl apply -f kubernetes/deployments/backend-deployment.yaml
    kubectl apply -f kubernetes/deployments/frontend-deployment.yaml
    ```
4.  Create Services and Ingress (ALB) to expose the application.

## Phase 4: CI/CD (GitHub Actions)

### Step 9: Create Workflow
1.  Create `.github/workflows/deploy.yml`.
2.  Add steps for:
    *   Checkout code
    *   Login to AWS ECR
    *   Build and Push Docker images
    *   Update Kubeconfig
    *   Deploy to EKS (`kubectl apply`)
3.  Commit and push to trigger the pipeline.

## Phase 5: Monitoring & Logging

### Step 10: Setup Monitoring
1.  Install Prometheus and Grafana (using Helm is recommended):
    ```bash
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm install monitoring prometheus-community/kube-prometheus-stack
    ```
2.  Access Grafana dashboard and configure alerts.

## Phase 6: Security Hardening

### Step 11: Secure the App
1.  Request a certificate in AWS ACM.
2.  Update Ingress to use the ACM certificate for HTTPS.
3.  Migrate database credentials to AWS Secrets Manager.
4.  Update backend deployment to read secrets from Secrets Manager.

## Phase 7: Backups & DR

### Step 12: Configure Backups
1.  Enable automated backups for RDS in AWS Console.
2.  Create a script to sync S3 buckets to a DR region.
3.  Document the restore process in `docs/runbook.md`.

## Phase 8: Documentation

### Step 13: Finalize Documentation
1.  Update `README.md` with project status and instructions.
2.  Create `docs/troubleshooting.md` with common issues and fixes.
3.  Prepare your presentation slides.

---
**Note:** This guide assumes you have the AWS CLI, Docker, kubectl, and Terraform installed and configured on your local machine.
