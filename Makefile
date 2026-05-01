KIND_CLUSTER := comic-cluster
KIND_CONFIG := kind-config.yaml
K8S_DIR := k8s/base
BACKEND_DIR := ../comic-backend/main
FRONTEND_DIR := ../comic-frontend/develop

BACKEND_IMAGE := docker-backend:latest
FRONTEND_IMAGE := docker-frontend:latest

.PHONY: help cluster-create cluster-delete cluster-reset build build-backend build-frontend push load deploy undeploy logs port-forward status restart

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Cluster ──────────────────────────────────────────────

cluster-create: ## Create Kind cluster
	kind create cluster --name $(KIND_CLUSTER) --config $(KIND_CONFIG)

cluster-delete: ## Delete Kind cluster
	kind delete cluster --name $(KIND_CLUSTER)

cluster-reset: cluster-delete cluster-create ## Reset cluster (delete + create)

status: ## Show cluster and pod status
	kubectl get nodes
	@echo "---"
	kubectl get pods -n comic-prod -o wide

# ── Images ───────────────────────────────────────────────

build: build-backend build-frontend ## Build backend and frontend images

build-backend: ## Build backend Docker image
	docker build -t $(BACKEND_IMAGE):latest -f $(BACKEND_DIR)/infra/docker/Dockerfile $(BACKEND_DIR)

build-frontend: ## Build frontend Docker image
	docker build -t $(FRONTEND_IMAGE):latest $(FRONTEND_DIR)

load: ## Load images into Kind cluster
	kind load docker-image $(BACKEND_IMAGE):latest --name $(KIND_CLUSTER)
	kind load docker-image $(FRONTEND_IMAGE):latest --name $(KIND_CLUSTER)

push: load ## Alias for load (Kind uses local images)

# ── Deploy ───────────────────────────────────────────────

deploy: ## Apply all K8s manifests
	kubectl apply -k $(K8S_DIR)

undeploy: ## Delete all resources
	kubectl delete -k $(K8S_DIR) --ignore-not-found

restart-backend: ## Restart backend deployment
	kubectl rollout restart deployment/backend -n comic-prod

restart-frontend: ## Restart frontend deployment
	kubectl rollout restart deployment/frontend -n comic-prod

restart: restart-backend restart-frontend ## Restart all deployments

restart-worker: ## Restart worker deployment
	kubectl rollout restart deployment/worker -n comic-prod

# ── Debug ────────────────────────────────────────────────

logs: ## Tail logs (usage: make logs APP=backend)
	kubectl logs -f -n comic-prod -l app=$(APP)

port-forward-backend: ## Port-forward backend API to localhost:8000
	kubectl port-forward -n comic-prod svc/backend 8000:8000

# ── Istio ────────────────────────────────────────────────

istio-install: ## Install Istio with default profile
	istioctl install --set profile=default -y

istio-uninstall: ## Uninstall Istio
	istioctl uninstall -y --purge

# ── Quick workflow ───────────────────────────────────────

full-deploy: build load deploy ## Build, load, and deploy everything
