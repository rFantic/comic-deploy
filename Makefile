KIND_CLUSTER := comic-cluster
KIND_CONFIG := kind-config.yaml
K8S_DIR := k8s/base
REGISTRY := localhost:5000
BACKEND_IMAGE := $(REGISTRY)/comic-backend
FRONTEND_IMAGE := $(REGISTRY)/comic-frontend
BACKEND_DIR := ../comic-backend/main
FRONTEND_DIR := ../comic-frontend

.PHONY: help cluster-create cluster-delete cluster-reset build push deploy undeploy logs port-forward status

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

build: ## Build backend and frontend images
	docker build -t $(BACKEND_IMAGE):latest -f $(BACKEND_DIR)/infra/docker/Dockerfile $(BACKEND_DIR)
	@echo "Frontend image: build manually when ready"
	@echo "  docker build -t $(FRONTEND_IMAGE):latest -f $(FRONTEND_DIR)/Dockerfile $(FRONTEND_DIR)"

push: ## Push images to local registry
	docker push $(BACKEND_IMAGE):latest

# ── Deploy ───────────────────────────────────────────────

deploy: ## Apply all K8s manifests
	kubectl apply -k $(K8S_DIR)

undeploy: ## Delete all resources
	kubectl delete -k $(K8S_DIR) --ignore-not-found

# ── Debug ────────────────────────────────────────────────

logs: ## Tail logs (usage: make logs APP=backend)
	kubectl logs -f -n comic-prod -l app=$(APP)

port-forward: ## Port-forward backend (usage: make port-forward)
	kubectl port-forward -n comic-prod svc/backend 8000:8000

# ── Istio ────────────────────────────────────────────────

istio-install: ## Install Istio with default profile
	istioctl install --set profile=default -y

istio-uninstall: ## Uninstall Istio
	istioctl uninstall -y --purge
