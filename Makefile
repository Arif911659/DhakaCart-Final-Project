# Makefile for DhakaCart Release Management

# Variables
DOCKER_USERNAME ?= arifhossaincse22
APP_NAME := dhakacart
# Version to build and push. CHANGE THIS for new releases.
VERSION := latest

BACKEND_IMAGE := $(DOCKER_USERNAME)/$(APP_NAME)-backend
FRONTEND_IMAGE := $(DOCKER_USERNAME)/$(APP_NAME)-frontend

.PHONY: all build push deploy help

help:
	@echo "Usage:"
	@echo "  make build    - Build Docker images locally with tag $(VERSION)"
	@echo "  make push     - Push Docker images to Docker Hub with tag $(VERSION)"
	@echo "  make deploy   - Update Kubernetes deployments to use version $(VERSION)"
	@echo "  make release  - Full release: build, push, and deploy"
	@echo ""
	@echo "Current Version: $(VERSION)"

build:
	@echo "Building Backend Image ($(VERSION))..."
	docker build -t $(BACKEND_IMAGE):$(VERSION) -t $(BACKEND_IMAGE):latest ./backend
	@echo "Building Frontend Image ($(VERSION))..."
	docker build -t $(FRONTEND_IMAGE):$(VERSION) -t $(FRONTEND_IMAGE):latest ./frontend
	@echo "✅ Build Complete!"

push:
	@echo "Pushing Backend Image ($(VERSION))..."
	docker push $(BACKEND_IMAGE):$(VERSION)
	docker push $(BACKEND_IMAGE):latest
	@echo "Pushing Frontend Image ($(VERSION))..."
	docker push $(FRONTEND_IMAGE):$(VERSION)
	docker push $(FRONTEND_IMAGE):latest
	@echo "✅ Push Complete!"

deploy:
	@echo "Updating Kubernetes Deployments to $(VERSION)..."
	kubectl set image deployment/dhakacart-backend backend=$(BACKEND_IMAGE):$(VERSION) -n dhakacart
	kubectl set image deployment/dhakacart-frontend frontend=$(FRONTEND_IMAGE):$(VERSION) -n dhakacart
	@echo "Verifying Rollout..."
	kubectl rollout status deployment/dhakacart-backend -n dhakacart
	kubectl rollout status deployment/dhakacart-frontend -n dhakacart
	@echo "✅ Deployment Updated!"

release: build push deploy
