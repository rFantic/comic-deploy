KIND_CLUSTER := comic-cluster
K8S_DIR := k8s/base
BACKEND_IMAGE := docker.io/library/docker-backend:latest
FRONTEND_IMAGE := docker.io/library/docker-frontend:latest
BACKEND_DIR := ../comic-backend/main
FRONTEND_DIR := ../comic-frontend/main
API_URL ?= https://comic-api.apl.io.vn

.PHONY: help status build-frontend build-backend load-frontend load-backend deploy undeploy logs istio-install istio-uninstall smoke-test

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ── Status ──────────────────────────────────────────────

status: ## Show cluster and pod status
	kubectl get pods -n comic-prod -o wide

# ── Images ───────────────────────────────────────────────

build-frontend: ## Build frontend image (API_URL=https://... make build-frontend)
	docker build --build-arg VITE_API_URL=$(API_URL) -t $(FRONTEND_IMAGE) $(FRONTEND_DIR)

build-backend: ## Build backend image
	docker build -t $(BACKEND_IMAGE) -f $(BACKEND_DIR)/infra/docker/Dockerfile $(BACKEND_DIR)

load-frontend: ## Load frontend image into Kind
	kind load docker-image $(FRONTEND_IMAGE) --name $(KIND_CLUSTER)

load-backend: ## Load backend image into Kind
	kind load docker-image $(BACKEND_IMAGE) --name $(KIND_CLUSTER)

# ── Deploy ───────────────────────────────────────────────

deploy: ## Apply all K8s manifests via kustomize
	kubectl apply -k $(K8S_DIR)

undeploy: ## Delete all resources
	kubectl delete -k $(K8S_DIR) --ignore-not-found

# ── Debug ────────────────────────────────────────────────

logs: ## Tail logs (usage: make logs APP=backend)
	kubectl logs -f -n comic-prod -l app=$(APP)

# ── Istio ────────────────────────────────────────────────

istio-install: ## Install Istio with default profile
	istioctl install --set profile=default -y

istio-uninstall: ## Uninstall Istio
	istioctl uninstall -y --purge

# ── Smoke test ───────────────────────────────────────────

smoke-test: ## Run frontend smoke test (BT_DIR=<path> make smoke-test)
	BT_DIR=$${BT_DIR:-$$PWD/../comic-frontend/main/scripts/../../.agents/skills/browser-tools} \
	bash $(FRONTEND_DIR)/scripts/smoke-test.sh https://comic.apl.io.vn
